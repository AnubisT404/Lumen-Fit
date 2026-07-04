"""
Local hybrid retrieval utilities for the AI Coach evidence system.
"""

from __future__ import annotations

import hashlib
import logging
import re
import threading
from collections import defaultdict
from pathlib import Path
from typing import Any

import faiss
import fitz
import numpy as np
from sentence_transformers import SentenceTransformer
from sqlalchemy import text
from sqlalchemy.orm import Session

from models import KnowledgeDocument, KnowledgePassage

logger = logging.getLogger("fitness.knowledge")

EMBEDDING_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
CURATED_SCOPE = "global-curated"
USER_UPLOAD_SCOPE = "user-upload:local"
TARGET_TOKENS = 200
OVERLAP_TOKENS = 35
INDEX_DIR = Path(__file__).resolve().parent / ".knowledge_indexes"


def _normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _sha256(value: bytes | str) -> str:
    payload = value.encode("utf-8") if isinstance(value, str) else value
    return hashlib.sha256(payload).hexdigest()


def _prepare_embeddings(embeddings: np.ndarray) -> np.ndarray:
    normalized = np.asarray(embeddings, dtype="float32")
    if normalized.ndim == 1:
        normalized = normalized.reshape(1, -1)
    if normalized.size:
        faiss.normalize_L2(normalized)
    return normalized


class EmbeddingService:
    """Singleton wrapper around MiniLM embeddings."""

    _instance: "EmbeddingService | None" = None
    _lock = threading.Lock()

    def __init__(self):
        self.model = SentenceTransformer(EMBEDDING_MODEL_NAME)
        self.dimensions = int(self.model.get_embedding_dimension())

    @classmethod
    def instance(cls) -> "EmbeddingService":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    logger.info("Loading embedding model: %s", EMBEDDING_MODEL_NAME)
                    cls._instance = cls()
        return cls._instance

    def encode(self, texts: list[str]) -> np.ndarray:
        if not texts:
            return np.empty((0, self.dimensions), dtype="float32")
        vectors = self.model.encode(
            texts,
            batch_size=16,
            convert_to_numpy=True,
            normalize_embeddings=False,
            show_progress_bar=False,
        )
        return _prepare_embeddings(vectors)

    def encode_query(self, text: str) -> np.ndarray:
        return self.encode([text])

    @classmethod
    def preload(cls) -> None:
        """Pre-load the embedding model in a background thread to avoid blocking first request."""
        def _load():
            try:
                cls.instance()
                logger.info("Embedding model pre-loaded successfully")
            except Exception:
                logger.warning("Failed to pre-load embedding model", exc_info=True)
        threading.Thread(target=_load, daemon=True).start()


class FaissVectorStore:
    """Namespace-aware FAISS index wrapper."""

    def __init__(self, scope: str, dimensions: int):
        self.scope = scope
        self.dimensions = dimensions
        INDEX_DIR.mkdir(parents=True, exist_ok=True)

    @property
    def path(self) -> Path:
        safe_scope = re.sub(r"[^a-zA-Z0-9_.-]+", "_", self.scope)
        return INDEX_DIR / f"{safe_scope}.faiss"

    def _empty_index(self):
        return faiss.IndexIDMap2(faiss.IndexFlatIP(self.dimensions))

    def _load(self):
        if self.path.exists():
            return faiss.read_index(str(self.path))
        return self._empty_index()

    def _save(self, index) -> None:
        faiss.write_index(index, str(self.path))

    def add_embeddings(self, ids: list[int], embeddings: np.ndarray) -> None:
        if not ids or embeddings.size == 0:
            return
        index = self._load()
        id_array = np.asarray(ids, dtype="int64")
        index.add_with_ids(_prepare_embeddings(embeddings), id_array)
        self._save(index)

    def rebuild(self, ids: list[int], embeddings: np.ndarray) -> None:
        index = self._empty_index()
        if ids and embeddings.size:
            id_array = np.asarray(ids, dtype="int64")
            index.add_with_ids(_prepare_embeddings(embeddings), id_array)
        self._save(index)

    def search(self, query_embedding: np.ndarray, top_k: int) -> list[tuple[int, float]]:
        index = self._load()
        if index.ntotal == 0:
            return []
        distances, ids = index.search(_prepare_embeddings(query_embedding), top_k)
        results: list[tuple[int, float]] = []
        for passage_id, score in zip(ids[0].tolist(), distances[0].tolist()):
            if passage_id == -1:
                continue
            results.append((int(passage_id), float(score)))
        return results


def build_segments_from_text(text: str, section_title: str | None = None) -> list[dict[str, Any]]:
    content = text.replace("\r\n", "\n").strip()
    if not content:
        return []

    segments: list[dict[str, Any]] = []
    current_title = section_title
    current_lines: list[str] = []

    for line in content.split("\n"):
        stripped = line.strip()
        if stripped.startswith("#"):
            block = _normalize_whitespace("\n".join(current_lines))
            if block:
                segments.append(
                    {
                        "text": block,
                        "section_title": current_title,
                        "page_number": None,
                    }
                )
            current_title = stripped.lstrip("#").strip() or current_title
            current_lines = []
            continue
        current_lines.append(line)

    final_block = _normalize_whitespace("\n".join(current_lines))
    if final_block:
        segments.append(
            {
                "text": final_block,
                "section_title": current_title,
                "page_number": None,
            }
        )

    return segments or [{"text": _normalize_whitespace(content), "section_title": section_title, "page_number": None}]


def extract_file_segments(filename: str, content: bytes) -> list[dict[str, Any]]:
    suffix = Path(filename).suffix.lower()

    if suffix == ".pdf":
        document = fitz.open(stream=content, filetype="pdf")
        try:
            segments: list[dict[str, Any]] = []
            for page_index in range(document.page_count):
                page_text = _normalize_whitespace(document.load_page(page_index).get_text("text"))
                if page_text:
                    segments.append(
                        {
                            "text": page_text,
                            "section_title": None,
                            "page_number": page_index + 1,
                        }
                    )
        finally:
            document.close()

        if not segments:
            raise ValueError("Could not extract readable text from this PDF. Scanned or image-only PDFs are not supported yet.")
        return segments

    if suffix in {".txt", ".md"}:
        decoded = content.decode("utf-8", errors="ignore")
        if not decoded.strip():
            raise ValueError("Uploaded document is empty.")
        return build_segments_from_text(decoded)

    raise ValueError("Unsupported document type. Upload PDF, TXT, or MD files.")


def chunk_segments(
    segments: list[dict[str, Any]],
    target_tokens: int = TARGET_TOKENS,
    overlap_tokens: int = OVERLAP_TOKENS,
) -> list[dict[str, Any]]:
    chunks: list[dict[str, Any]] = []

    for segment in segments:
        words = _normalize_whitespace(segment.get("text", "")).split()
        if not words:
            continue

        if len(words) <= target_tokens:
            chunks.append(
                {
                    "text": " ".join(words),
                    "section_title": segment.get("section_title"),
                    "page_number": segment.get("page_number"),
                    "token_count": len(words),
                }
            )
            continue

        start = 0
        while start < len(words):
            end = min(len(words), start + target_tokens)
            chunk_words = words[start:end]
            chunk_text = " ".join(chunk_words).strip()
            if chunk_text:
                chunks.append(
                    {
                        "text": chunk_text,
                        "section_title": segment.get("section_title"),
                        "page_number": segment.get("page_number"),
                        "token_count": len(chunk_words),
                    }
                )
            if end >= len(words):
                break
            start = max(end - overlap_tokens, start + 1)

    return chunks


def ingest_segments_document(
    db: Session,
    *,
    title: str,
    segments: list[dict[str, Any]],
    source_type: str,
    scope: str,
    trust_tier: str,
    file_hash: str | None = None,
    origin_url: str | None = None,
    doi: str | None = None,
    year: int | None = None,
) -> KnowledgeDocument:
    if not segments:
        raise ValueError("No readable text was found in this document.")

    if file_hash:
        existing = (
            db.query(KnowledgeDocument)
            .filter(
                KnowledgeDocument.scope == scope,
                KnowledgeDocument.file_hash == file_hash,
                KnowledgeDocument.status == "ready",
            )
            .first()
        )
        if existing:
            return existing

    chunks = chunk_segments(segments)
    if not chunks:
        raise ValueError("The document did not produce any indexable chunks.")

    document = KnowledgeDocument(
        scope=scope,
        title=title.strip() or "Untitled document",
        source_type=source_type,
        origin_url=origin_url,
        doi=doi,
        year=year,
        trust_tier=trust_tier,
        file_hash=file_hash,
        status="indexing",
    )
    db.add(document)
    db.flush()

    passage_rows: list[KnowledgePassage] = []
    for chunk_index, chunk in enumerate(chunks):
        passage = KnowledgePassage(
            document_id=document.id,
            chunk_index=chunk_index,
            section_title=chunk.get("section_title"),
            page_number=chunk.get("page_number"),
            token_count=int(chunk.get("token_count") or 0),
            text=chunk["text"],
            text_hash=_sha256(chunk["text"]),
        )
        db.add(passage)
        passage_rows.append(passage)

    db.flush()

    passage_ids: list[int] = []
    passage_texts: list[str] = []
    for passage in passage_rows:
        passage.embedding_id = passage.id
        passage_ids.append(int(passage.id))
        passage_texts.append(passage.text)

    db.commit()

    try:
        service = EmbeddingService.instance()
        store = FaissVectorStore(scope=scope, dimensions=service.dimensions)
        store.add_embeddings(passage_ids, service.encode(passage_texts))

        persisted = db.get(KnowledgeDocument, document.id)
        if persisted:
            persisted.status = "ready"
            db.commit()
            db.refresh(persisted)
            return persisted
        raise ValueError("Document was not persisted.")
    except Exception:
        logger.exception("Failed to index knowledge document: %s", title)
        persisted = db.get(KnowledgeDocument, document.id)
        if persisted:
            persisted.status = "error"
            db.commit()
        raise


def ingest_text_document(
    db: Session,
    *,
    title: str,
    text: str,
    source_type: str,
    scope: str,
    trust_tier: str,
    file_hash: str | None = None,
    origin_url: str | None = None,
    doi: str | None = None,
    year: int | None = None,
    section_title: str | None = None,
) -> KnowledgeDocument:
    segments = build_segments_from_text(text, section_title=section_title)
    return ingest_segments_document(
        db,
        title=title,
        segments=segments,
        source_type=source_type,
        scope=scope,
        trust_tier=trust_tier,
        file_hash=file_hash,
        origin_url=origin_url,
        doi=doi,
        year=year,
    )


def rebuild_scope_index(db: Session, scope: str) -> None:
    rows = (
        db.query(KnowledgePassage.embedding_id, KnowledgePassage.text)
        .join(KnowledgeDocument, KnowledgeDocument.id == KnowledgePassage.document_id)
        .filter(
            KnowledgeDocument.scope == scope,
            KnowledgeDocument.status == "ready",
            KnowledgePassage.embedding_id.isnot(None),
        )
        .order_by(KnowledgePassage.id.asc())
        .all()
    )

    service = EmbeddingService.instance()
    store = FaissVectorStore(scope=scope, dimensions=service.dimensions)
    if not rows:
        store.rebuild([], np.empty((0, service.dimensions), dtype="float32"))
        return

    ids = [int(row[0]) for row in rows]
    texts = [row[1] for row in rows]
    store.rebuild(ids, service.encode(texts))


def serialize_document(document: KnowledgeDocument) -> dict[str, Any]:
    return {
        "id": document.id,
        "title": document.title,
        "source_type": document.source_type,
        "scope": document.scope,
        "origin_url": document.origin_url,
        "doi": document.doi,
        "year": document.year,
        "trust_tier": document.trust_tier,
        "status": document.status,
        "chunk_count": len(document.passages),
        "created_at": document.created_at.isoformat() if document.created_at else None,
    }


def delete_document_and_rebuild(db: Session, document_id: int, *, scope: str | None = None) -> dict[str, Any] | None:
    query = db.query(KnowledgeDocument).filter(KnowledgeDocument.id == document_id)
    if scope:
        query = query.filter(KnowledgeDocument.scope == scope)
    document = query.first()
    if not document:
        return None

    target_scope = document.scope
    deleted = serialize_document(document)
    db.delete(document)
    db.commit()
    rebuild_scope_index(db, target_scope)
    return deleted


def reciprocal_rank_fusion(rankings: list[list[int]], k: int = 60) -> list[int]:
    scores: dict[int, float] = defaultdict(float)
    for ranking in rankings:
        for rank, item_id in enumerate(ranking, start=1):
            scores[item_id] += 1.0 / (k + rank)
    return [item_id for item_id, _ in sorted(scores.items(), key=lambda item: item[1], reverse=True)]


def _build_fts_query(query: str) -> str | None:
    terms = re.findall(r"[a-zA-Z0-9][a-zA-Z0-9.+_-]*", query.lower())
    seen: set[str] = set()
    filtered: list[str] = []
    for term in terms:
        if len(term) < 3 or term in seen:
            continue
        seen.add(term)
        filtered.append(term)
    if not filtered:
        return None
    return " OR ".join(f'"{term}"' for term in filtered[:8])


def _fts_search_ids(db: Session, query: str, limit: int) -> list[int]:
    match_query = _build_fts_query(query)
    if not match_query:
        return []

    try:
        rows = db.execute(
            text(
                """
                SELECT rowid, bm25(knowledge_passages_fts) AS rank
                FROM knowledge_passages_fts
                WHERE knowledge_passages_fts MATCH :match_query
                ORDER BY rank
                LIMIT :limit
                """
            ),
            {"match_query": match_query, "limit": limit},
        ).fetchall()
    except Exception:
        logger.exception("FTS query failed for %s", query)
        return []

    return [int(row[0]) for row in rows]


def hybrid_search(
    db: Session,
    query: str,
    *,
    scopes: list[str] | None = None,
    top_k: int = 6,
    vector_k: int = 8,
    fts_k: int = 8,
) -> list[dict[str, Any]]:
    normalized_query = _normalize_whitespace(query)
    target_scopes = scopes or [CURATED_SCOPE]
    if not normalized_query or not target_scopes:
        return []

    fts_ranking = _fts_search_ids(db, normalized_query, limit=max(fts_k, top_k * 2))

    service = EmbeddingService.instance()
    query_embedding = service.encode_query(normalized_query)
    vector_ranking: list[int] = []
    for scope in target_scopes:
        store = FaissVectorStore(scope=scope, dimensions=service.dimensions)
        vector_ranking.extend([passage_id for passage_id, _ in store.search(query_embedding, top_k=max(vector_k, top_k * 2))])

    fused_ids = reciprocal_rank_fusion([fts_ranking, vector_ranking])[: max(top_k * 3, top_k)]
    if not fused_ids:
        return []

    rows = (
        db.query(KnowledgePassage, KnowledgeDocument)
        .join(KnowledgeDocument, KnowledgeDocument.id == KnowledgePassage.document_id)
        .filter(
            KnowledgePassage.id.in_(fused_ids),
            KnowledgeDocument.scope.in_(target_scopes),
            KnowledgeDocument.status == "ready",
        )
        .all()
    )
    row_map = {int(passage.id): (passage, document) for passage, document in rows}

    hits: list[dict[str, Any]] = []
    for passage_id in fused_ids:
        pair = row_map.get(int(passage_id))
        if not pair:
            continue
        passage, document = pair
        hits.append(
            {
                "passage_id": passage.id,
                "document_id": document.id,
                "title": document.title,
                "text": passage.text,
                "section_title": passage.section_title,
                "page_number": passage.page_number,
                "year": document.year,
                "url": document.origin_url,
                "doi": document.doi,
                "scope": document.scope,
                "source_type": document.source_type,
                "trust_tier": document.trust_tier,
            }
        )
        if len(hits) >= top_k:
            break

    return hits
