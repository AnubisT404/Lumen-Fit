from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import UserSettings
from pydantic import BaseModel
from typing import Optional
from enum import Enum
from cryptography.fernet import Fernet
import logging
import os

router = APIRouter()
logger = logging.getLogger(__name__)

# Fernet key for encrypting AI API keys (prefer env var, fall back to file)
_FERNET_KEY_PATH = os.path.join(os.path.dirname(__file__), "..", ".fernet_key")
_FILE_KEY_WARNING_LOGGED = False

def _get_fernet() -> Fernet:
    global _FILE_KEY_WARNING_LOGGED

    env_key = os.getenv("FERNET_KEY")
    if env_key:
        return Fernet(env_key.encode() if isinstance(env_key, str) else env_key)

    if not _FILE_KEY_WARNING_LOGGED:
        logger.warning(
            "WARNING: Using file-based Fernet key. Set FERNET_KEY env var in production."
        )
        _FILE_KEY_WARNING_LOGGED = True

    if os.path.exists(_FERNET_KEY_PATH):
        with open(_FERNET_KEY_PATH, "rb") as f:
            key = f.read().strip()
    else:
        key = Fernet.generate_key()
        with open(_FERNET_KEY_PATH, "wb") as f:
            f.write(key)
    return Fernet(key)

def encrypt_key(plain: str) -> str:
    return _get_fernet().encrypt(plain.encode()).decode()

def decrypt_key(enc: str) -> str:
    return _get_fernet().decrypt(enc.encode()).decode()


class WeightUnitEnum(str, Enum):
    kg = "kg"
    lb = "lb"

class AIProviderEnum(str, Enum):
    openai = "openai"
    claude = "claude"
    gemini = "gemini"
    ollama = "ollama"
    huggingface = "huggingface"
    custom = "custom"


class SettingsUpdate(BaseModel):
    weight_unit: Optional[WeightUnitEnum] = None
    ai_provider: Optional[AIProviderEnum] = None
    ai_model: Optional[str] = None
    ai_api_key: Optional[str] = None  # plain-text in request, encrypted in DB
    ai_endpoint: Optional[str] = None
    scholar_search_enabled: Optional[bool] = None


def get_or_create_settings(db: Session) -> UserSettings:
    settings = db.query(UserSettings).first()
    if not settings:
        settings = UserSettings(weight_unit="kg", scholar_search_enabled=True)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


@router.get("/")
def get_settings(db: Session = Depends(get_db)):
    settings = get_or_create_settings(db)
    return {
        "weight_unit": settings.weight_unit,
        "ai_provider": settings.ai_provider,
        "ai_model": settings.ai_model,
        "ai_api_key_set": bool(settings.ai_api_key_enc),
        "ai_endpoint": settings.ai_endpoint,
        "scholar_search_enabled": bool(settings.scholar_search_enabled),
    }


@router.put("/")
def update_settings(data: SettingsUpdate, db: Session = Depends(get_db)):
    settings = get_or_create_settings(db)
    if data.weight_unit is not None:
        settings.weight_unit = data.weight_unit.value
    if data.ai_provider is not None:
        settings.ai_provider = data.ai_provider.value
    if data.ai_model is not None:
        settings.ai_model = data.ai_model
    if data.ai_api_key is not None:
        settings.ai_api_key_enc = encrypt_key(data.ai_api_key) if data.ai_api_key else None
    if data.ai_endpoint is not None:
        settings.ai_endpoint = data.ai_endpoint or None
    if data.scholar_search_enabled is not None:
        settings.scholar_search_enabled = data.scholar_search_enabled
    db.commit()
    db.refresh(settings)
    # Invalidate the coach settings cache
    try:
        from routers.coach import invalidate_settings_cache
        invalidate_settings_cache()
    except ImportError:
        pass
    return {
        "weight_unit": settings.weight_unit,
        "ai_provider": settings.ai_provider,
        "ai_model": settings.ai_model,
        "ai_api_key_set": bool(settings.ai_api_key_enc),
        "ai_endpoint": settings.ai_endpoint,
        "scholar_search_enabled": bool(settings.scholar_search_enabled),
    }
