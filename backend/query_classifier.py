"""
Deterministic query planning for the coach evidence pipeline.
"""

from __future__ import annotations

import re
from typing import Literal

from pydantic import BaseModel


class QueryPlan(BaseModel):
    category: Literal[
        "personal_review",
        "evergreen_science",
        "latest_research",
        "upload_specific",
        "medical_risk",
    ]
    use_local_rag: bool
    use_scholar_search: bool
    use_user_uploads: bool
    search_query: str | None = None
    evidence_note: str | None = None


MEDICAL_RISK_PATTERNS = (
    "chest pain",
    "fainted",
    "fainting",
    "dizzy",
    "dizziness",
    "shortness of breath",
    "blackout",
    "palpitations",
    "severe pain",
    "numbness",
    "tingling",
    "blood pressure",
)

LATEST_RESEARCH_PATTERNS = (
    "latest",
    "recent",
    "new research",
    "new study",
    "recent study",
    "what does research say now",
    "current evidence",
)

UPLOAD_PATTERNS = (
    "uploaded",
    "upload",
    "pdf",
    "document",
    "paper i added",
    "note i added",
    "my note",
    "my document",
)

SCIENCE_PATTERNS = (
    # Nutrition & body composition
    "protein",
    "creatine",
    "deficit",
    "surplus",
    "carb",
    "fat loss",
    "calorie",
    "macro",
    "supplement",
    "hydration",
    "electrolyte",
    "vitamin",
    "mineral",
    "fiber",
    "omega",
    "caffeine",
    "pre-workout",
    "whey",
    "casein",
    # Training science
    "hypertrophy",
    "strength",
    "volume",
    "rep range",
    "progressive overload",
    "periodization",
    "deload",
    "frequency",
    "intensity",
    "failure",
    "rpe",
    "rir",
    "tempo",
    "time under tension",
    "concentric",
    "eccentric",
    "isometric",
    # Cardiovascular / endurance
    "vo2",
    "cardio",
    "hiit",
    "liss",
    "endurance",
    "aerobic",
    "anaerobic",
    "heart rate zone",
    "lactate threshold",
    # Recovery & sleep
    "recovery",
    "sleep",
    "overtraining",
    "hrv",
    "rest day",
    "muscle soreness",
    "doms",
    # Physiotherapy & injury
    "injury",
    "rehab",
    "prehab",
    "mobility",
    "flexibility",
    "tendinopathy",
    "impingement",
    "pain",
    "hurts",
    "sore",
    "tight",
    "stiff",
    "posture",
    "corrective",
    "foam roll",
    "stretching",
    # Psychology & behavior
    "motivation",
    "adherence",
    "habit",
    "plateau",
    "mindset",
    "body image",
    "discipline",
    # Research references
    "study",
    "research",
    "evidence",
    "paper",
    "meta-analysis",
    "systematic review",
)

PERSONAL_PATTERNS = (
    "how am i doing",
    "analyze my",
    "review my",
    "rate my",
    "today",
    "this week",
    "my calories",
    "my protein",
    "my macros",
    "my workout",
    "my meals",
    "my progress",
    "my weight",
    "my hydration",
)


def _contains_any(text: str, patterns: tuple[str, ...]) -> bool:
    return any(pattern in text for pattern in patterns)


def _normalize_query(message: str) -> str:
    return re.sub(r"\s+", " ", message).strip()


def build_query_plan(message: str, *, scholar_enabled: bool, has_user_uploads: bool) -> QueryPlan:
    text = _normalize_query(message).lower()

    if _contains_any(text, MEDICAL_RISK_PATTERNS):
        return QueryPlan(
            category="medical_risk",
            use_local_rag=True,
            use_scholar_search=scholar_enabled,
            use_user_uploads=False,
            search_query=message,
            evidence_note="Respond conservatively. Encourage professional medical care for diagnosis or urgent symptoms.",
        )

    if has_user_uploads and _contains_any(text, UPLOAD_PATTERNS):
        return QueryPlan(
            category="upload_specific",
            use_local_rag=True,
            use_scholar_search=False,
            use_user_uploads=True,
            search_query=message,
            evidence_note="Prioritize the user's uploaded documents and notes before broader coaching context.",
        )

    if _contains_any(text, LATEST_RESEARCH_PATTERNS):
        return QueryPlan(
            category="latest_research",
            use_local_rag=True,
            use_scholar_search=scholar_enabled,
            use_user_uploads=has_user_uploads and _contains_any(text, ("my", "upload", "document", "note")),
            search_query=message,
            evidence_note="Prefer recent scholarly sources and say clearly when evidence is abstract-only or mixed.",
        )

    personal_review = _contains_any(text, PERSONAL_PATTERNS) or (" my " in f" {text} " and any(
        token in text for token in ("calorie", "protein", "macro", "workout", "meal", "progress", "weight", "water", "sleep")
    ))
    science_question = _contains_any(text, SCIENCE_PATTERNS)

    if personal_review and not science_question:
        return QueryPlan(
            category="personal_review",
            use_local_rag=False,
            use_scholar_search=False,
            use_user_uploads=False,
            search_query=None,
            evidence_note="Lead with the user's own logged data and coach context.",
        )

    if personal_review and science_question:
        return QueryPlan(
            category="personal_review",
            use_local_rag=True,
            use_scholar_search=False,
            use_user_uploads=False,
            search_query=message,
            evidence_note="Blend user data review with local curated evidence when it helps explain the recommendation.",
        )

    if science_question:
        return QueryPlan(
            category="evergreen_science",
            use_local_rag=True,
            use_scholar_search=scholar_enabled,
            use_user_uploads=False,
            search_query=message,
            evidence_note="Use the local curated evidence base and online scholarly sources to ground recommendations with specific citations.",
        )

    return QueryPlan(
        category="personal_review",
        use_local_rag=False,
        use_scholar_search=False,
        use_user_uploads=False,
        search_query=None,
        evidence_note="No explicit retrieval needed; answer from user context and coach memory.",
    )
