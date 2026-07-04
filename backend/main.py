from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from database import engine, Base, SessionLocal
import models
import logging
import time

# ============ Logging ============

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("fitness")

# Create all database tables
Base.metadata.create_all(bind=engine)

# Lightweight schema migration for SQLite (add missing columns)
from sqlalchemy import text, inspect as sa_inspect
with engine.connect() as _conn:
    # Add user_id to user_profile if missing
    _cols = [c["name"] for c in sa_inspect(engine).get_columns("user_profile")]
    if "user_id" not in _cols:
        _conn.execute(text("ALTER TABLE user_profile ADD COLUMN user_id INTEGER REFERENCES users(id)"))
        _conn.commit()
    if "name" not in _cols:
        _conn.execute(text("ALTER TABLE user_profile ADD COLUMN name VARCHAR"))
        _conn.commit()
    # Add cardio quality fields to exercise_sets
    _es_cols = [c["name"] for c in sa_inspect(engine).get_columns("exercise_sets")]
    for _col, _typ in [("avg_heart_rate", "INTEGER"), ("max_heart_rate", "INTEGER"), ("elevation_m", "REAL"), ("intensity", "TEXT")]:
        if _col not in _es_cols:
            _conn.execute(text(f"ALTER TABLE exercise_sets ADD COLUMN {_col} {_typ}"))
    _conn.commit()
    # Add MealItem override columns (per-item macros that don't mutate shared FoodItem)
    _mi_cols = [c["name"] for c in sa_inspect(engine).get_columns("meal_items")]
    for _col, _typ in [
        ("override_calories", "REAL"), ("override_protein_g", "REAL"),
        ("override_carbs_g", "REAL"), ("override_fats_g", "REAL"),
        ("override_serving_size", "REAL"), ("override_serving_unit", "TEXT"),
    ]:
        if _col not in _mi_cols:
            _conn.execute(text(f"ALTER TABLE meal_items ADD COLUMN {_col} {_typ}"))
    _conn.commit()
    # Add micronutrient columns to food_items
    _fi_cols = [c["name"] for c in sa_inspect(engine).get_columns("food_items")]
    for _col, _typ in [
        ("saturated_fat_g", "REAL"), ("polyunsaturated_fat_g", "REAL"), ("monounsaturated_fat_g", "REAL"),
        ("trans_fat_g", "REAL"), ("cholesterol_mg", "REAL"), ("potassium_mg", "REAL"),
        ("calcium_mg", "REAL"), ("iron_mg", "REAL"), ("vitamin_a_pct", "REAL"), ("vitamin_c_pct", "REAL"),
    ]:
        if _col not in _fi_cols:
            _conn.execute(text(f"ALTER TABLE food_items ADD COLUMN {_col} REAL"))
    _conn.commit()
    # Add target_weight_kg to user_profile
    _up_cols = [c["name"] for c in sa_inspect(engine).get_columns("user_profile")]
    if "target_weight_kg" not in _up_cols:
        _conn.execute(text("ALTER TABLE user_profile ADD COLUMN target_weight_kg REAL"))
        _conn.commit()
    # Add AI settings columns to user_settings
    _us_cols = [c["name"] for c in sa_inspect(engine).get_columns("user_settings")]
    for _col, _typ in [
        ("ai_provider", "TEXT"),
        ("ai_model", "TEXT"),
        ("ai_api_key_enc", "TEXT"),
        ("ai_endpoint", "TEXT"),
        ("scholar_search_enabled", "BOOLEAN DEFAULT 1"),
    ]:
        if _col not in _us_cols:
            _conn.execute(text(f"ALTER TABLE user_settings ADD COLUMN {_col} {_typ}"))
    _conn.commit()
    _cm_cols = [c["name"] for c in sa_inspect(engine).get_columns("coach_messages")]
    if "sources_json" not in _cm_cols:
        _conn.execute(text("ALTER TABLE coach_messages ADD COLUMN sources_json TEXT"))
        _conn.commit()
    for _idx in [
        "CREATE INDEX IF NOT EXISTS ix_body_measurements_date ON body_measurements (date)",
        "CREATE INDEX IF NOT EXISTS ix_meals_date ON meals (date)",
        "CREATE INDEX IF NOT EXISTS ix_water_logs_date ON water_logs (date)",
        "CREATE INDEX IF NOT EXISTS ix_workouts_date ON workouts (date)",
        ]:
        _conn.execute(text(_idx))
    _conn.commit()
    _conn.execute(
        text(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_passages_fts
            USING fts5(text, content='knowledge_passages', content_rowid='id', tokenize='unicode61')
            """
        )
    )
    _conn.execute(
        text(
            """
            CREATE TRIGGER IF NOT EXISTS knowledge_passages_ai
            AFTER INSERT ON knowledge_passages
            BEGIN
                INSERT INTO knowledge_passages_fts(rowid, text) VALUES (new.id, new.text);
            END
            """
        )
    )
    _conn.execute(
        text(
            """
            CREATE TRIGGER IF NOT EXISTS knowledge_passages_ad
            AFTER DELETE ON knowledge_passages
            BEGIN
                INSERT INTO knowledge_passages_fts(knowledge_passages_fts, rowid, text)
                VALUES ('delete', old.id, old.text);
            END
            """
        )
    )
    _conn.execute(
        text(
            """
            CREATE TRIGGER IF NOT EXISTS knowledge_passages_au
            AFTER UPDATE ON knowledge_passages
            BEGIN
                INSERT INTO knowledge_passages_fts(knowledge_passages_fts, rowid, text)
                VALUES ('delete', old.id, old.text);
                INSERT INTO knowledge_passages_fts(rowid, text) VALUES (new.id, new.text);
            END
            """
        )
    )
    _conn.execute(
        text(
            """
            INSERT INTO knowledge_passages_fts(rowid, text)
            SELECT kp.id, kp.text
            FROM knowledge_passages kp
            WHERE NOT EXISTS (
                SELECT 1
                FROM knowledge_passages_fts fts
                WHERE fts.rowid = kp.id
            )
            """
        )
    )
    _conn.commit()

# Seed workout presets
from routers.workout_plans import seed_presets
seed_presets()

# Seed curated coach evidence corpus
from seed_knowledge import seed_curated_knowledge
with SessionLocal() as _seed_db:
    try:
        seed_curated_knowledge(_seed_db)
    except Exception:
        logger.exception("Failed to seed curated coach knowledge corpus")

# Pre-load embedding model in background thread (avoids 5-10s delay on first coach request)
try:
    from vector_store import EmbeddingService
    EmbeddingService.preload()
except Exception as e:
    logger.warning(f"Preload failed: {e}")

app = FastAPI(
    title="Fitness Tracker API",
    description="Backend API for tracking meals, workouts, water intake, and body measurements",
    version="1.0.0"
)

# ============ Global Exception Handler ============

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.method} {request.url.path}: {type(exc).__name__}: {exc}")
    return JSONResponse(
        status_code=500,
        content={"status": "error", "message": "Internal server error", "data": None}
    )

# ============ Request Logging Middleware ============

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000, 1)
    logger.info(f"{request.method} {request.url.path} -> {response.status_code} ({duration_ms}ms)")
    return response

# Enable CORS for frontend
import os as _os
ALLOWED_ORIGINS = _os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000,http://localhost:8888,http://127.0.0.1:8888").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

@app.get("/")
def read_root():
    return {
        "message": "Fitness Tracker API is running!",
        "docs": "Visit /docs for API documentation"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Import and include routers
from routers import measurements, meals, water, workouts, profile, dashboard, settings, workout_plans, coach, auth

app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(profile.router, prefix="/api/v1/profile", tags=["Profile & Goals"])
app.include_router(measurements.router, prefix="/api/v1/measurements", tags=["Body Measurements"])
app.include_router(meals.router, prefix="/api/v1/meals", tags=["Meals & Nutrition"])
app.include_router(water.router, prefix="/api/v1/water", tags=["Water Tracking"])
app.include_router(workout_plans.router, prefix="/api/v1/workouts", tags=["Workout Plans"])
app.include_router(workouts.router, prefix="/api/v1/workouts", tags=["Workouts"])
app.include_router(dashboard.router, prefix="/api/v1/dashboard", tags=["Dashboard"])
app.include_router(settings.router, prefix="/api/v1/settings", tags=["Settings"])
app.include_router(coach.router, prefix="/api/v1/coach", tags=["AI Coach"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
