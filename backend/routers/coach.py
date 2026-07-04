"""
Coach router: AI chat (streaming SSE with evidence), daily insight,
chat history, and knowledge management (upload / notes / list / delete).
"""

import json
import logging
import time
from datetime import datetime, timezone, date
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
from models import (
    UserSettings,
    CoachMessage,
    CoachMemory,
    KnowledgeDocument,
)
from ai_providers import get_provider, PROVIDERS, DEFAULT_MODELS
from coach_knowledge import SYSTEM_PROMPT, build_user_context
from routers.settings import decrypt_key
from query_classifier import build_query_plan
from vector_store import (
    CURATED_SCOPE,
    USER_UPLOAD_SCOPE,
    hybrid_search,
    ingest_text_document,
    extract_file_segments,
    ingest_segments_document,
    serialize_document,
    delete_document_and_rebuild,
    _sha256,
)

logger = logging.getLogger("fitness.coach")
router = APIRouter()


# ============ Rate Limiting ============

class _RateLimiter:
    """Simple in-memory rate limiter for AI endpoints."""
    
    def __init__(self, max_requests: int = 20, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window = window_seconds
        self._timestamps: list[float] = []
    
    def check(self):
        """Raises HTTPException(429) if rate limit exceeded."""
        now = time.time()
        cutoff = now - self.window
        self._timestamps = [t for t in self._timestamps if t > cutoff]
        if len(self._timestamps) >= self.max_requests:
            raise HTTPException(
                status_code=429,
                detail=f"Rate limit exceeded. Max {self.max_requests} requests per {self.window}s."
            )
        self._timestamps.append(now)

_chat_limiter = _RateLimiter(max_requests=20, window_seconds=60)
_insight_limiter = _RateLimiter(max_requests=5, window_seconds=60)


# ============ Schemas ============

class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None


class ValidateKeyRequest(BaseModel):
    provider: str
    api_key: Optional[str] = None
    model: Optional[str] = None
    endpoint: Optional[str] = None


class TextNoteRequest(BaseModel):
    title: str
    text: str


# ============ Helpers ============

# Simple in-memory cache for AI settings (avoid DB query every chat message)
_settings_cache: dict = {"settings": None, "expires": 0}
_SETTINGS_TTL = 30  # 30 seconds — short enough to catch updates quickly

def _get_ai_settings(db: Session) -> UserSettings:
    now = time.time()
    if _settings_cache["settings"] and now < _settings_cache["expires"]:
        return _settings_cache["settings"]
    settings = db.query(UserSettings).first()
    if not settings or not settings.ai_provider:
        raise HTTPException(status_code=400, detail="AI provider not configured. Go to Settings to set up your AI Coach.")
    _settings_cache["settings"] = settings
    _settings_cache["expires"] = now + _SETTINGS_TTL
    return settings


def invalidate_settings_cache():
    """Call when settings are updated to clear the cache."""
    _settings_cache["settings"] = None
    _settings_cache["expires"] = 0


def _make_provider(settings: UserSettings):
    api_key = None
    if settings.ai_api_key_enc:
        try:
            api_key = decrypt_key(settings.ai_api_key_enc)
        except Exception:
            raise HTTPException(status_code=400, detail="Failed to decrypt API key. Please re-enter it in Settings.")
    return get_provider(
        provider_name=settings.ai_provider,
        api_key=api_key,
        model=settings.ai_model,
        endpoint=settings.ai_endpoint,
    )


def _get_recent_messages(db: Session, limit: int = 10) -> list[dict]:
    """Get the most recent chat messages for context window."""
    messages = (
        db.query(CoachMessage)
        .order_by(CoachMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    messages.reverse()
    return [{"role": m.role, "content": m.content} for m in messages]


def _has_user_uploads(db: Session) -> bool:
    return (
        db.query(KnowledgeDocument)
        .filter(
            KnowledgeDocument.scope == USER_UPLOAD_SCOPE,
            KnowledgeDocument.status == "ready",
        )
        .count()
        > 0
    )


def _build_evidence_block(hits: list[dict], scholar_results: list[dict]) -> tuple[str, list[dict]]:
    """Assemble evidence text + structured source list for the LLM and frontend."""
    lines: list[str] = []
    sources: list[dict] = []
    seen: set[str] = set()

    tag_counter = {"L": 0, "P": 0}

    for hit in hits:
        kind = "upload" if hit.get("source_type") in ("upload", "note") else "curated"
        tag_counter["L"] += 1
        tag = f"L{tag_counter['L']}"
        dedupe = (hit.get("title") or "").strip().lower()
        if dedupe in seen:
            continue
        seen.add(dedupe)
        lines.append(f"[{tag}] {hit['title']}")
        lines.append(hit["text"][:600])
        lines.append("")
        sources.append({
            "id": tag,
            "title": hit["title"],
            "kind": kind,
            "url": hit.get("url"),
            "year": hit.get("year"),
        })

    for item in scholar_results:
        tag_counter["P"] += 1
        tag = f"P{tag_counter['P']}"
        dedupe = (item.get("doi") or item.get("title") or "").strip().lower()
        if dedupe in seen:
            continue
        seen.add(dedupe)
        lines.append(f"[{tag}] {item['title']}")
        if item.get("snippet"):
            lines.append(item["snippet"][:600])
        lines.append("")
        sources.append({
            "id": tag,
            "title": item["title"],
            "kind": "paper",
            "url": item.get("url"),
            "year": item.get("year"),
        })

    evidence_text = "\n".join(lines).strip()
    return evidence_text, sources[:8]


async def _gather_evidence(db: Session, message: str, settings: UserSettings) -> tuple[str, list[dict], str | None]:
    """Run query classifier → retrieve local + scholar evidence → return block."""
    scholar_enabled = bool(settings.scholar_search_enabled)
    has_uploads = _has_user_uploads(db)

    plan = build_query_plan(message, scholar_enabled=scholar_enabled, has_user_uploads=has_uploads)

    local_hits: list[dict] = []
    scholar_results: list[dict] = []

    if plan.use_local_rag and plan.search_query:
        scopes = [CURATED_SCOPE]
        if plan.use_user_uploads:
            scopes.append(USER_UPLOAD_SCOPE)
        try:
            local_hits = hybrid_search(db, plan.search_query, scopes=scopes, top_k=4)
        except Exception:
            logger.warning("Local RAG search failed", exc_info=True)

    if plan.use_scholar_search and plan.search_query:
        try:
            from scholar_search import search_scholar_sources
            scholar_results = await search_scholar_sources(plan.search_query, db=db, limit=4)
        except Exception:
            logger.warning("Scholar search failed", exc_info=True)

    evidence_text, sources = _build_evidence_block(local_hits, scholar_results)
    return evidence_text, sources, plan.evidence_note


# ============ Chat ============

@router.post("/chat")
async def chat(req: ChatRequest, db: Session = Depends(get_db)):
    """Stream a chat response from the AI coach via SSE with evidence."""
    _chat_limiter.check()
    settings = _get_ai_settings(db)
    provider = _make_provider(settings)

    # Resolve or create session
    import uuid as _uuid
    session_id = req.session_id or str(_uuid.uuid4())[:8]

    user_msg = CoachMessage(
        role="user",
        content=req.message,
        session_id=session_id,
        provider=settings.ai_provider,
        model=settings.ai_model,
    )
    db.add(user_msg)
    db.commit()

    # Gather evidence in parallel with context building
    evidence_text, sources, evidence_note = await _gather_evidence(db, req.message, settings)

    user_context = build_user_context(db)
    system_parts = [SYSTEM_PROMPT, user_context]

    if evidence_text:
        system_parts.append(
            "═══ RETRIEVED EVIDENCE (cite tags like [L1], [P2] when using) ═══\n"
            + evidence_text
        )
    if evidence_note:
        system_parts.append(f"EVIDENCE NOTE: {evidence_note}")

    full_system = "\n\n".join(system_parts)
    history = _get_recent_messages(db, limit=10)

    async def event_stream():
        full_response = []
        try:
            async for chunk in provider.chat_stream(history, full_system):
                full_response.append(chunk)
                yield f"data: {json.dumps({'type': 'chunk', 'content': chunk})}\n\n"

            response_text = "".join(full_response)
            assistant_msg = CoachMessage(
                role="assistant",
                content=response_text,
                session_id=session_id,
                provider=settings.ai_provider,
                model=settings.ai_model,
                sources_json=json.dumps(sources) if sources else None,
            )
            db.add(assistant_msg)
            db.commit()

            done_payload = {"type": "done", "message_id": assistant_msg.id, "session_id": session_id}
            if sources:
                done_payload["sources"] = sources
            yield f"data: {json.dumps(done_payload)}\n\n"

            msg_count = db.query(CoachMessage).count()
            memory = db.query(CoachMemory).first()
            last_summarized = memory.message_count if memory else 0
            if msg_count - last_summarized >= 10:
                try:
                    await _summarize_memory(db, settings)
                except Exception as e:
                    logger.warning(f"Memory summarization failed: {e}")

        except Exception as e:
            logger.error(f"Chat stream error: {e}")
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# ============ History (now includes sources) ============

@router.get("/history")
def get_history(
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Get paginated chat history (newest first)."""
    total = db.query(CoachMessage).count()
    messages = (
        db.query(CoachMessage)
        .order_by(CoachMessage.created_at.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    messages.reverse()

    def _parse_sources(m):
        if m.sources_json:
            try:
                return json.loads(m.sources_json)
            except json.JSONDecodeError:
                pass
        return None

    return {
        "messages": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "provider": m.provider,
                "model": m.model,
                "sources": _parse_sources(m),
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ],
        "total": total,
        "page": page,
        "per_page": per_page,
        "has_more": total > page * per_page,
    }


@router.delete("/history")
def clear_history(db: Session = Depends(get_db)):
    """Clear all chat history and memory."""
    db.query(CoachMessage).delete()
    db.query(CoachMemory).delete()
    db.commit()
    return {"status": "ok", "message": "Chat history cleared"}


@router.get("/sessions")
def get_sessions(db: Session = Depends(get_db)):
    """List chat sessions (conversations) with title = first user message."""
    from sqlalchemy import func, distinct
    sessions_raw = (
        db.query(
            CoachMessage.session_id,
            func.min(CoachMessage.created_at).label("started_at"),
            func.max(CoachMessage.created_at).label("last_at"),
            func.count(CoachMessage.id).label("message_count"),
        )
        .filter(CoachMessage.session_id.isnot(None))
        .group_by(CoachMessage.session_id)
        .order_by(func.max(CoachMessage.created_at).desc())
        .all()
    )
    result = []
    for s in sessions_raw:
        first_msg = (
            db.query(CoachMessage)
            .filter(CoachMessage.session_id == s.session_id, CoachMessage.role == "user")
            .order_by(CoachMessage.created_at.asc())
            .first()
        )
        title = first_msg.content[:80] if first_msg else "Chat"
        result.append({
            "session_id": s.session_id,
            "title": title,
            "started_at": s.started_at.isoformat() if s.started_at else None,
            "last_at": s.last_at.isoformat() if s.last_at else None,
            "message_count": s.message_count,
        })
    return {"sessions": result}


@router.get("/sessions/{session_id}")
def get_session_messages(session_id: str, db: Session = Depends(get_db)):
    """Get all messages for a specific session."""
    messages = (
        db.query(CoachMessage)
        .filter(CoachMessage.session_id == session_id)
        .order_by(CoachMessage.created_at.asc())
        .all()
    )
    if not messages:
        raise HTTPException(status_code=404, detail="Session not found")
    return {
        "session_id": session_id,
        "messages": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "provider": m.provider,
                "model": m.model,
                "sources": json.loads(m.sources_json) if m.sources_json else None,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ],
    }


# ============ Knowledge Management ============

@router.get("/knowledge")
def list_knowledge(db: Session = Depends(get_db)):
    """List all user-uploaded documents and notes."""
    docs = (
        db.query(KnowledgeDocument)
        .filter(KnowledgeDocument.scope == USER_UPLOAD_SCOPE)
        .order_by(KnowledgeDocument.created_at.desc())
        .all()
    )
    return {"documents": [serialize_document(d) for d in docs]}


ALLOWED_EXTENSIONS = {".pdf", ".txt", ".md", ".csv", ".json", ".docx"}
ALLOWED_MIMES = {"application/pdf", "text/plain", "text/markdown", "text/csv", "application/json",
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}
MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10MB


@router.post("/knowledge/upload")
async def upload_document(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Upload a PDF, TXT, or MD file to the user's knowledge base."""
    import os as _os
    ext = _os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"File type '{ext}' not allowed. Allowed: {', '.join(ALLOWED_EXTENSIONS)}")

    content = await file.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=400, detail=f"File too large. Max size: {MAX_UPLOAD_SIZE // (1024*1024)}MB")
    await file.seek(0)

    try:
        segments = extract_file_segments(file.filename or "upload.txt", content)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    file_hash = _sha256(content)
    doc = ingest_segments_document(
        db,
        title=(file.filename or "Upload").rsplit(".", 1)[0],
        segments=segments,
        source_type="upload",
        scope=USER_UPLOAD_SCOPE,
        trust_tier="user-provided",
        file_hash=file_hash,
    )
    return {"status": "ok", "document": serialize_document(doc)}


@router.post("/knowledge/text")
def add_text_note(req: TextNoteRequest, db: Session = Depends(get_db)):
    """Add a plain-text note to the user's knowledge base."""
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Note text cannot be empty.")

    doc = ingest_text_document(
        db,
        title=req.title.strip() or "Untitled note",
        text=req.text,
        source_type="note",
        scope=USER_UPLOAD_SCOPE,
        trust_tier="user-provided",
        file_hash=_sha256(req.text),
    )
    return {"status": "ok", "document": serialize_document(doc)}


@router.delete("/knowledge/{doc_id}")
def delete_knowledge(doc_id: int, db: Session = Depends(get_db)):
    """Delete a user-uploaded document or note."""
    deleted = delete_document_and_rebuild(db, doc_id, scope=USER_UPLOAD_SCOPE)
    if not deleted:
        raise HTTPException(status_code=404, detail="Document not found.")
    return {"status": "ok", "deleted": deleted}


# ============ Daily Insight ============

@router.get("/daily-insight")
async def daily_insight(db: Session = Depends(get_db)):
    """Generate a daily insight based on user's data."""
    _insight_limiter.check()
    settings = db.query(UserSettings).first()

    if not settings or not settings.ai_provider or not settings.ai_api_key_enc:
        return _rule_based_insight(db)

    try:
        provider = _make_provider(settings)
        user_context = build_user_context(db)

        prompt = f"""{SYSTEM_PROMPT}

{user_context}

Generate a single, short daily insight (2-3 sentences max) for the user based on their data. Be specific — reference their actual numbers. Focus on one topic: nutrition, training, weight progress, hydration, or a motivational observation. Don't use greetings or sign-offs. Just the insight."""

        chunks = []
        async for chunk in provider.chat_stream(
            [{"role": "user", "content": "Give me my daily insight."}],
            system_prompt=prompt,
        ):
            chunks.append(chunk)

        return {
            "insight": "".join(chunks),
            "source": "ai",
            "provider": settings.ai_provider,
            "model": settings.ai_model,
        }
    except Exception as e:
        logger.warning(f"AI daily insight failed, falling back to rule-based: {e}")
        return _rule_based_insight(db)


# ============ Provider Management ============

@router.post("/validate-key")
async def validate_key(req: ValidateKeyRequest):
    """Test that a provider connection works."""
    if req.provider not in PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Unknown provider: {req.provider}")

    provider = get_provider(
        provider_name=req.provider,
        api_key=req.api_key,
        model=req.model,
        endpoint=req.endpoint,
    )
    success, message = await provider.validate()
    return {"valid": success, "message": message}


@router.get("/providers")
def list_providers():
    """List available AI providers and their default models."""
    return {
        "providers": [
            {
                "id": pid,
                "name": {
                    "openai": "OpenAI",
                    "claude": "Anthropic Claude",
                    "gemini": "Google Gemini",
                    "ollama": "Ollama (Local)",
                    "huggingface": "HuggingFace",
                    "custom": "Custom Endpoint",
                }.get(pid, pid),
                "models": DEFAULT_MODELS.get(pid, []),
                "requires_key": pid not in ("ollama",),
                "requires_endpoint": pid in ("ollama", "custom"),
            }
            for pid in PROVIDERS
        ]
    }


# ============ Rule-based fallback ============

def _rule_based_insight(db: Session) -> dict:
    """Generate a data-driven insight without AI."""
    from models import UserProfile, Goals, BodyMeasurement, Meal, MealItem, FoodItem, WaterLog

    profile = db.query(UserProfile).first()
    goals = db.query(Goals).first()
    today = date.today()

    insights = []

    today_items = (
        db.query(MealItem)
        .join(Meal)
        .join(FoodItem, MealItem.food_id == FoodItem.id)
        .filter(Meal.date == today)
        .all()
    )
    if today_items and goals:
        total_pro = sum((mi.food.protein_g or 0) * mi.servings for mi in today_items)
        total_cal = sum((mi.food.calories or 0) * mi.servings for mi in today_items)
        if total_pro < goals.protein_g * 0.5:
            remaining = round(goals.protein_g - total_pro)
            insights.append(f"You're at {round(total_pro)}g protein so far — {remaining}g to go. A chicken breast (~35g) or protein shake (~25g) would help close the gap.")
        if total_cal > goals.daily_calories * 1.1:
            over = round(total_cal - goals.daily_calories)
            insights.append(f"You're at {round(total_cal)} calories — {over} over your {round(goals.daily_calories)} goal. Consider lighter choices for the rest of the day.")
        elif total_cal > goals.daily_calories * 0.9:
            insights.append(f"You're at {round(total_cal)} calories — close to your {round(goals.daily_calories)} goal. Nice pacing today!")

    water = db.query(WaterLog).filter(WaterLog.date == today).all()
    total_water = sum(w.amount_ml for w in water)
    if goals and total_water < goals.water_ml * 0.3:
        insights.append(f"Hydration check: only {total_water}ml logged today. Try to hit {goals.water_ml}ml — your muscles and recovery depend on it.")

    from datetime import timedelta
    week_ago = today - timedelta(days=7)
    weights = db.query(BodyMeasurement).filter(BodyMeasurement.date >= week_ago).order_by(BodyMeasurement.date.desc()).all()
    if len(weights) >= 2:
        diff = weights[0].weight_kg - weights[-1].weight_kg
        if diff < -0.3 and profile and profile.goal == "lose":
            insights.append(f"Great progress! You're down {abs(diff):.1f}kg this week. That's a healthy, sustainable rate.")
        elif diff > 0.5 and profile and profile.goal == "lose":
            insights.append(f"Weight is up {diff:.1f}kg this week. Could be water retention — check sodium intake and hydration. Stay consistent.")

    if not insights:
        insights.append("Log your meals and workouts to get personalized insights from your coach!")

    return {
        "insight": insights[0],
        "source": "rule_based",
        "provider": None,
        "model": None,
    }


# ============ Memory Summarization ============

async def _summarize_memory(db: Session, settings: UserSettings):
    """Summarize recent conversation into memory to manage token window."""
    provider = _make_provider(settings)

    memory = db.query(CoachMemory).first()
    messages = (
        db.query(CoachMessage)
        .order_by(CoachMessage.created_at.asc())
        .all()
    )
    if not messages:
        return

    convo_text = "\n".join([f"{m.role}: {m.content[:500]}" for m in messages[-20:]])

    existing_summary = memory.summary_text if memory else ""
    summary_prompt = f"""Summarize this fitness coaching conversation into a concise paragraph (150 words max).
Capture: key topics discussed, advice given, user's concerns/goals mentioned, any commitments made.
This summary will be used as context for future conversations.

{"Previous summary: " + existing_summary if existing_summary else ""}

Recent conversation:
{convo_text}"""

    chunks = []
    async for chunk in provider.chat_stream(
        [{"role": "user", "content": summary_prompt}],
        system_prompt="You are a conversation summarizer. Be concise and factual.",
    ):
        chunks.append(chunk)

    summary = "".join(chunks)

    if memory:
        memory.summary_text = summary
        memory.message_count = len(messages)
        memory.updated_at = datetime.now(timezone.utc)
    else:
        memory = CoachMemory(summary_text=summary, message_count=len(messages))
        db.add(memory)

    db.commit()
