"""
Seed the curated coach evidence corpus into the local knowledge store.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path

from sqlalchemy.orm import Session

from models import KnowledgeDocument
from vector_store import CURATED_SCOPE, ingest_text_document, rebuild_scope_index

logger = logging.getLogger("fitness.knowledge.seed")

CORPUS_DIR = Path(__file__).resolve().parent / "knowledge_corpus"


def _load_entries() -> list[dict]:
    entries: list[dict] = []
    for path in sorted(CORPUS_DIR.glob("*.json")):
        with path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if isinstance(payload, list):
            entries.extend(payload)
        elif isinstance(payload, dict):
            entries.append(payload)
    return entries


def seed_curated_knowledge(db: Session) -> int:
    existing = (
        db.query(KnowledgeDocument)
        .filter(
            KnowledgeDocument.scope == CURATED_SCOPE,
            KnowledgeDocument.source_type == "curated",
            KnowledgeDocument.status == "ready",
        )
        .count()
    )
    if existing:
        return existing

    entries = _load_entries()
    if not entries:
        logger.warning("No curated knowledge corpus files were found in %s", CORPUS_DIR)
        return 0

    inserted = 0
    for entry in entries:
        signature = json.dumps(entry, sort_keys=True)
        ingest_text_document(
            db,
            title=entry["title"],
            text=entry["text"],
            source_type="curated",
            scope=CURATED_SCOPE,
            trust_tier="curated",
            file_hash=signature,
            origin_url=entry.get("origin_url"),
            doi=entry.get("doi"),
            year=entry.get("year"),
            section_title=entry.get("topic"),
        )
        inserted += 1

    rebuild_scope_index(db, CURATED_SCOPE)
    logger.info("Seeded curated knowledge corpus (%s documents)", inserted)
    return inserted
