"""
Scholarly evidence connectors for PubMed, Europe PMC, OpenAlex, and Crossref.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import quote
from xml.etree import ElementTree as ET

import httpx
from sqlalchemy.orm import Session

from models import EvidenceCache

logger = logging.getLogger("fitness.scholar")

COMMON_HEADERS = {"User-Agent": "FitnessTrackerAI/1.0 (+local evidence retrieval)"}
CACHE_TTL = timedelta(hours=12)


def _cache_key(provider: str, query: str) -> str:
    return hashlib.sha256(f"{provider}:{query.strip().lower()}".encode("utf-8")).hexdigest()


def _cache_get(db: Session, provider: str, query: str) -> list[dict[str, Any]] | dict[str, Any] | None:
    cache = (
        db.query(EvidenceCache)
        .filter(
            EvidenceCache.provider == provider,
            EvidenceCache.query_hash == _cache_key(provider, query),
        )
        .first()
    )
    if not cache:
        return None

    now = datetime.now(timezone.utc)
    if cache.expires_at.replace(tzinfo=timezone.utc) < now:
        db.delete(cache)
        db.commit()
        return None

    try:
        return json.loads(cache.payload_json)
    except json.JSONDecodeError:
        logger.warning("Ignoring invalid evidence cache payload for %s", provider)
        return None


def _cache_set(db: Session, provider: str, query: str, payload: list[dict[str, Any]] | dict[str, Any]) -> None:
    query_hash = _cache_key(provider, query)
    cache = (
        db.query(EvidenceCache)
        .filter(
            EvidenceCache.provider == provider,
            EvidenceCache.query_hash == query_hash,
        )
        .first()
    )
    if not cache:
        cache = EvidenceCache(provider=provider, query_hash=query_hash, payload_json="[]", expires_at=datetime.now(timezone.utc))
        db.add(cache)

    cache.payload_json = json.dumps(payload)
    cache.expires_at = datetime.now(timezone.utc) + CACHE_TTL
    db.commit()


def _node_text(node) -> str | None:
    if node is None:
        return None
    text = "".join(node.itertext()).strip()
    return text or None


def _first_year(*values: str | None) -> int | None:
    for value in values:
        if not value:
            continue
        match = re.search(r"(19|20)\d{2}", value)
        if match:
            return int(match.group(0))
    return None


def _trim_snippet(text: str | None, limit: int = 520) -> str | None:
    if not text:
        return None
    normalized = re.sub(r"\s+", " ", text).strip()
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 1].rstrip() + "…"


def _normalize_doi(doi: str | None) -> str | None:
    if not doi:
        return None
    cleaned = doi.strip()
    for prefix in ("https://doi.org/", "http://doi.org/", "doi:"):
        if cleaned.lower().startswith(prefix):
            cleaned = cleaned[len(prefix):]
    return cleaned or None


async def search_pubmed(
    query: str,
    *,
    db: Session,
    client: httpx.AsyncClient,
    limit: int = 2,
) -> list[dict[str, Any]]:
    cached = _cache_get(db, "pubmed", query)
    if isinstance(cached, list):
        return cached

    search_response = await client.get(
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi",
        params={"db": "pubmed", "retmode": "json", "retmax": limit, "sort": "relevance", "term": query},
        headers=COMMON_HEADERS,
    )
    search_response.raise_for_status()
    article_ids = search_response.json().get("esearchresult", {}).get("idlist", [])[:limit]
    if not article_ids:
        _cache_set(db, "pubmed", query, [])
        return []

    fetch_response = await client.get(
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi",
        params={"db": "pubmed", "retmode": "xml", "id": ",".join(article_ids)},
        headers=COMMON_HEADERS,
    )
    fetch_response.raise_for_status()

    root = ET.fromstring(fetch_response.text)
    results: list[dict[str, Any]] = []
    for article in root.findall(".//PubmedArticle"):
        pmid = _node_text(article.find(".//PMID"))
        title = _node_text(article.find(".//ArticleTitle"))
        abstract_parts = [_node_text(node) for node in article.findall(".//Abstract/AbstractText")]
        abstract = " ".join(part for part in abstract_parts if part)
        year = _first_year(
            _node_text(article.find(".//ArticleDate/Year")),
            _node_text(article.find(".//PubDate/Year")),
            _node_text(article.find(".//PubDate/MedlineDate")),
        )
        doi = _normalize_doi(_node_text(article.find(".//ELocationID[@EIdType='doi']")))

        if not title:
            continue

        results.append(
            {
                "title": title,
                "snippet": _trim_snippet(abstract) or "PubMed result available, but abstract text was not returned.",
                "url": f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/" if pmid else None,
                "year": year,
                "doi": doi,
                "kind": "paper",
                "provider": "PubMed",
                "trust_tier": "scholar-abstract",
            }
        )

    _cache_set(db, "pubmed", query, results)
    return results


async def search_europe_pmc(
    query: str,
    *,
    db: Session,
    client: httpx.AsyncClient,
    limit: int = 2,
) -> list[dict[str, Any]]:
    cached = _cache_get(db, "europepmc", query)
    if isinstance(cached, list):
        return cached

    response = await client.get(
        "https://www.ebi.ac.uk/europepmc/webservices/rest/search",
        params={"query": query, "format": "json", "pageSize": limit, "resultType": "core"},
        headers=COMMON_HEADERS,
    )
    response.raise_for_status()
    items = response.json().get("resultList", {}).get("result", [])

    results: list[dict[str, Any]] = []
    for item in items:
        title = item.get("title")
        if not title:
            continue

        pmcid = item.get("pmcid")
        pmid = item.get("pmid")
        url = (
            f"https://europepmc.org/articles/{pmcid}"
            if pmcid
            else f"https://europepmc.org/article/MED/{pmid}"
            if pmid
            else None
        )

        open_access = any(str(item.get(flag, "")).upper() == "Y" for flag in ("isOpenAccess", "hasPDF", "hasBook"))
        results.append(
            {
                "title": title,
                "snippet": _trim_snippet(item.get("abstractText")) or "Europe PMC returned metadata without an abstract snippet.",
                "url": url,
                "year": _first_year(str(item.get("pubYear") or "")),
                "doi": _normalize_doi(item.get("doi")),
                "kind": "paper",
                "provider": "Europe PMC",
                "trust_tier": "scholar-oa" if open_access else "scholar-abstract",
            }
        )

    _cache_set(db, "europepmc", query, results)
    return results


def _openalex_abstract_text(abstract_index: dict[str, list[int]] | None) -> str | None:
    if not abstract_index:
        return None
    ordered_terms: list[tuple[int, str]] = []
    for word, positions in abstract_index.items():
        for position in positions:
            ordered_terms.append((position, word))
    if not ordered_terms:
        return None
    return " ".join(word for _, word in sorted(ordered_terms, key=lambda item: item[0]))


async def search_openalex(
    query: str,
    *,
    db: Session,
    client: httpx.AsyncClient,
    limit: int = 2,
) -> list[dict[str, Any]]:
    cached = _cache_get(db, "openalex", query)
    if isinstance(cached, list):
        return cached

    response = await client.get(
        "https://api.openalex.org/works",
        params={"search": query, "per-page": limit},
        headers=COMMON_HEADERS,
    )
    response.raise_for_status()
    items = response.json().get("results", [])

    results: list[dict[str, Any]] = []
    for item in items:
        title = item.get("title") or item.get("display_name")
        if not title:
            continue

        abstract = _openalex_abstract_text(item.get("abstract_inverted_index"))
        ids = item.get("ids", {})
        primary_location = item.get("primary_location") or {}
        url = primary_location.get("landing_page_url") or primary_location.get("pdf_url") or ids.get("openalex")
        doi = _normalize_doi(item.get("doi") or ids.get("doi"))

        results.append(
            {
                "title": title,
                "snippet": _trim_snippet(abstract) or "OpenAlex returned metadata without an abstract snippet.",
                "url": url,
                "year": item.get("publication_year"),
                "doi": doi,
                "kind": "paper",
                "provider": "OpenAlex",
                "trust_tier": "scholar-abstract" if abstract else "scholar-metadata",
            }
        )

    _cache_set(db, "openalex", query, results)
    return results


async def enrich_crossref(
    doi: str,
    *,
    db: Session,
    client: httpx.AsyncClient,
) -> dict[str, Any]:
    normalized_doi = _normalize_doi(doi)
    if not normalized_doi:
        return {}

    cached = _cache_get(db, "crossref", normalized_doi)
    if isinstance(cached, dict):
        return cached

    response = await client.get(
        f"https://api.crossref.org/works/{quote(normalized_doi, safe='')}",
        headers=COMMON_HEADERS,
    )
    if response.status_code == 404:
        _cache_set(db, "crossref", normalized_doi, {})
        return {}
    response.raise_for_status()

    message = response.json().get("message", {})
    published = message.get("published-print") or message.get("published-online") or message.get("issued") or {}
    date_parts = published.get("date-parts") or []
    year = None
    if date_parts and date_parts[0]:
        try:
            year = int(date_parts[0][0])
        except (TypeError, ValueError):
            year = None

    payload = {
        "title": (message.get("title") or [None])[0],
        "url": message.get("URL"),
        "year": year,
        "doi": normalized_doi,
    }
    _cache_set(db, "crossref", normalized_doi, payload)
    return payload


async def search_scholar_sources(
    query: str,
    *,
    db: Session,
    limit: int = 4,
) -> list[dict[str, Any]]:
    async with httpx.AsyncClient(timeout=25.0) as client:

        async def _safe_pubmed():
            try:
                return await search_pubmed(query, db=db, client=client, limit=2)
            except Exception:
                logger.warning("PubMed search failed for query: %s", query[:80])
                return []

        async def _safe_europe_pmc():
            try:
                return await search_europe_pmc(query, db=db, client=client, limit=2)
            except Exception:
                logger.warning("Europe PMC search failed for query: %s", query[:80])
                return []

        async def _safe_openalex():
            try:
                return await search_openalex(query, db=db, client=client, limit=2)
            except Exception:
                logger.warning("OpenAlex search failed for query: %s", query[:80])
                return []

        pubmed_results, epmc_results, openalex_results = await asyncio.gather(
            _safe_pubmed(), _safe_europe_pmc(), _safe_openalex()
        )
        results: list[dict[str, Any]] = [*pubmed_results, *epmc_results, *openalex_results]

        deduped: list[dict[str, Any]] = []
        seen: set[str] = set()
        latest_requested = any(token in query.lower() for token in ("latest", "recent", "new", "current"))

        for item in results:
            if item.get("doi") and (not item.get("url") or not item.get("year")):
                try:
                    enrichment = await enrich_crossref(item["doi"], db=db, client=client)
                except Exception:
                    logger.warning("Crossref enrichment failed for DOI %s", item["doi"])
                    enrichment = {}
                for key, value in enrichment.items():
                    if value and not item.get(key):
                        item[key] = value

            dedupe_key = (item.get("doi") or item.get("url") or item.get("title") or "").strip().lower()
            if not dedupe_key or dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            deduped.append(item)

        if latest_requested:
            deduped.sort(key=lambda item: (item.get("year") or 0), reverse=True)

        return deduped[:limit]
