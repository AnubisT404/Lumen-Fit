"""
Auth router — register, login, refresh, me.
All endpoints work regardless of AUTH_ENABLED flag.
The flag only controls whether other routes *require* a token.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from database import get_db
from models import User, UserProfile
from auth import (
    AUTH_ENABLED,
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    get_current_user_id,
)

router = APIRouter(prefix="/auth", tags=["auth"])


# ─── Schemas ──────────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str | None = None

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: int
    email: str

class RefreshRequest(BaseModel):
    refresh_token: str

class AuthStatusResponse(BaseModel):
    auth_enabled: bool
    authenticated: bool
    user_id: int | None = None
    email: str | None = None


# ─── Endpoints ────────────────────────────────────────────────────────
@router.post("/register", response_model=TokenResponse, status_code=201)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    """Create a new user account."""
    existing = db.query(User).filter(User.email == req.email.lower().strip()).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        email=req.email.lower().strip(),
        hashed_password=hash_password(req.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Link existing profile (id=1) to this user if it's the first user
    profile = db.query(UserProfile).filter(UserProfile.user_id == None).first()  # noqa: E711
    if profile:
        profile.user_id = user.id
        if req.name:
            profile.name = req.name
        db.commit()

    return TokenResponse(
        access_token=create_access_token(user.id, user.email),
        refresh_token=create_refresh_token(user.id),
        user_id=user.id,
        email=user.email,
    )


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    """Authenticate and return tokens."""
    user = db.query(User).filter(User.email == req.email.lower().strip()).first()
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    return TokenResponse(
        access_token=create_access_token(user.id, user.email),
        refresh_token=create_refresh_token(user.id),
        user_id=user.id,
        email=user.email,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(req: RefreshRequest, db: Session = Depends(get_db)):
    """Get new access token using refresh token."""
    user_id = decode_refresh_token(req.refresh_token)
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or disabled")

    return TokenResponse(
        access_token=create_access_token(user.id, user.email),
        refresh_token=create_refresh_token(user.id),
        user_id=user.id,
        email=user.email,
    )


@router.get("/status", response_model=AuthStatusResponse)
def auth_status(user_id: int = Depends(get_current_user_id), db: Session = Depends(get_db)):
    """Check auth status and whether auth is enabled."""
    if not AUTH_ENABLED:
        return AuthStatusResponse(auth_enabled=False, authenticated=False)

    user = db.query(User).filter(User.id == user_id).first()
    return AuthStatusResponse(
        auth_enabled=True,
        authenticated=True,
        user_id=user.id if user else None,
        email=user.email if user else None,
    )
