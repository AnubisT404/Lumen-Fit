from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime, timezone
import enum


def _utcnow():
    return datetime.now(timezone.utc)


class User(Base):
    """Authentication user account"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    profile = relationship("UserProfile", back_populates="user", uselist=False)


class GoalType(str, enum.Enum):
    LOSE = "lose"
    MAINTAIN = "maintain"
    GAIN = "gain"

class ActivityLevel(str, enum.Enum):
    SEDENTARY = "sedentary"          # 1.2
    LIGHTLY_ACTIVE = "lightly_active"  # 1.375
    MODERATELY_ACTIVE = "moderately_active"  # 1.55
    VERY_ACTIVE = "very_active"      # 1.725
    EXTREMELY_ACTIVE = "extremely_active"  # 1.9

class UserProfile(Base):
    """User profile linked to auth account"""
    __tablename__ = "user_profile"
    __table_args__ = (
        CheckConstraint("age >= 1 AND age <= 120", name="ck_profile_age"),
        CheckConstraint("height_cm > 30 AND height_cm < 300", name="ck_profile_height"),
        CheckConstraint("current_weight_kg > 1 AND current_weight_kg < 500", name="ck_profile_weight"),
        CheckConstraint("sex IN ('male', 'female')", name="ck_profile_sex"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    name = Column(String, nullable=True)
    age = Column(Integer, nullable=False)
    sex = Column(String, nullable=False)
    height_cm = Column(Float, nullable=False)
    current_weight_kg = Column(Float, nullable=False)
    activity_level = Column(String, nullable=False, default="moderately_active")
    goal = Column(String, nullable=False, default="maintain")
    target_weight_kg = Column(Float, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    user = relationship("User", back_populates="profile")

class Goals(Base):
    """Daily calorie and macro targets"""
    __tablename__ = "goals"
    __table_args__ = (
        CheckConstraint("daily_calories > 0", name="ck_goals_calories"),
        CheckConstraint("protein_g >= 0", name="ck_goals_protein"),
        CheckConstraint("carbs_g >= 0", name="ck_goals_carbs"),
        CheckConstraint("fats_g >= 0", name="ck_goals_fats"),
        CheckConstraint("water_ml > 0", name="ck_goals_water"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    daily_calories = Column(Float, nullable=False)
    protein_g = Column(Float, nullable=False)
    carbs_g = Column(Float, nullable=False)
    fats_g = Column(Float, nullable=False)
    water_ml = Column(Integer, nullable=False, default=2000)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

class BodyMeasurement(Base):
    """Track weight and body measurements over time"""
    __tablename__ = "body_measurements"
    __table_args__ = (
        Index("ix_body_measurements_date", "date"),
        CheckConstraint("weight_kg > 1 AND weight_kg < 500", name="ck_measurement_weight"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, nullable=False)
    weight_kg = Column(Float, nullable=False)
    body_fat_percentage = Column(Float, nullable=True)
    chest_cm = Column(Float, nullable=True)
    waist_cm = Column(Float, nullable=True)
    hips_cm = Column(Float, nullable=True)
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

class FoodItem(Base):
    """Food database - nutritional information per serving"""
    __tablename__ = "food_items"
    __table_args__ = (
        Index("ix_food_items_name", "name"),
        CheckConstraint("serving_size > 0", name="ck_food_serving_size"),
        CheckConstraint("calories >= 0", name="ck_food_calories"),
        CheckConstraint("protein_g >= 0", name="ck_food_protein"),
        CheckConstraint("carbs_g >= 0", name="ck_food_carbs"),
        CheckConstraint("fats_g >= 0", name="ck_food_fats"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    brand = Column(String, nullable=True)
    barcode = Column(String, unique=True, nullable=True)
    
    serving_size = Column(Float, nullable=False, default=100.0)
    serving_unit = Column(String, nullable=False, default="g")
    serving_description = Column(String, nullable=True)
    
    calories = Column(Float, nullable=False)
    protein_g = Column(Float, nullable=False)
    carbs_g = Column(Float, nullable=False)
    fats_g = Column(Float, nullable=False)
    fiber_g = Column(Float, nullable=True)
    sugar_g = Column(Float, nullable=True)
    sodium_mg = Column(Float, nullable=True)
    saturated_fat_g = Column(Float, nullable=True)
    polyunsaturated_fat_g = Column(Float, nullable=True)
    monounsaturated_fat_g = Column(Float, nullable=True)
    trans_fat_g = Column(Float, nullable=True)
    cholesterol_mg = Column(Float, nullable=True)
    potassium_mg = Column(Float, nullable=True)
    calcium_mg = Column(Float, nullable=True)
    iron_mg = Column(Float, nullable=True)
    vitamin_a_pct = Column(Float, nullable=True)
    vitamin_c_pct = Column(Float, nullable=True)
    vitamin_d_mcg = Column(Float, nullable=True)
    
    source = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

class Meal(Base):
    """Meal entry (breakfast, lunch, dinner, snack)"""
    __tablename__ = "meals"
    __table_args__ = (
        Index("ix_meals_date", "date"),
        Index("ix_meals_date_type", "date", "meal_type"),
        CheckConstraint("meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')", name="ck_meal_type"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, nullable=False)
    meal_type = Column(String, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
    
    items = relationship("MealItem", back_populates="meal", cascade="all, delete-orphan")

class MealItem(Base):
    """Individual food items in a meal"""
    __tablename__ = "meal_items"
    __table_args__ = (
        Index("ix_meal_items_meal_id", "meal_id"),
        Index("ix_meal_items_food_id", "food_id"),
        CheckConstraint("servings > 0", name="ck_mealitem_servings"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    meal_id = Column(Integer, ForeignKey("meals.id", ondelete="CASCADE"))
    food_id = Column(Integer, ForeignKey("food_items.id", ondelete="CASCADE"))
    servings = Column(Float, nullable=False)
    # Per-item overrides that don't mutate the shared FoodItem
    override_calories = Column(Float, nullable=True)
    override_protein_g = Column(Float, nullable=True)
    override_carbs_g = Column(Float, nullable=True)
    override_fats_g = Column(Float, nullable=True)
    override_serving_size = Column(Float, nullable=True)
    override_serving_unit = Column(String, nullable=True)
    
    meal = relationship("Meal", back_populates="items")
    food = relationship("FoodItem")

    @property
    def effective_calories(self):
        return self.override_calories if self.override_calories is not None else (self.food.calories if self.food else 0)

    @property
    def effective_protein_g(self):
        return self.override_protein_g if self.override_protein_g is not None else (self.food.protein_g if self.food else 0)

    @property
    def effective_carbs_g(self):
        return self.override_carbs_g if self.override_carbs_g is not None else (self.food.carbs_g if self.food else 0)

    @property
    def effective_fats_g(self):
        return self.override_fats_g if self.override_fats_g is not None else (self.food.fats_g if self.food else 0)

    @property
    def effective_serving_size(self):
        return self.override_serving_size if self.override_serving_size is not None else (self.food.serving_size if self.food else 100)

    @property
    def effective_serving_unit(self):
        return self.override_serving_unit if self.override_serving_unit is not None else (self.food.serving_unit if self.food else "g")

class MealTemplate(Base):
    """Saved meal template (e.g. 'My Morning Oats', 'Chicken Pot')"""
    __tablename__ = "meal_templates"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    items = relationship("MealTemplateItem", back_populates="template", cascade="all, delete-orphan")

class MealTemplateItem(Base):
    """Individual food in a meal template"""
    __tablename__ = "meal_template_items"

    id = Column(Integer, primary_key=True, index=True)
    template_id = Column(Integer, ForeignKey("meal_templates.id", ondelete="CASCADE"))
    food_id = Column(Integer, ForeignKey("food_items.id", ondelete="SET NULL"), nullable=True)
    servings = Column(Float, nullable=False, default=1.0)
    serving_size = Column(Float, nullable=True)
    serving_unit = Column(String, nullable=True)

    template = relationship("MealTemplate", back_populates="items")
    food = relationship("FoodItem")

class WaterLog(Base):
    """Daily water intake tracking"""
    __tablename__ = "water_logs"
    __table_args__ = (
        Index("ix_water_logs_date", "date"),
        CheckConstraint("amount_ml > 0", name="ck_water_amount"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, nullable=False)
    amount_ml = Column(Integer, nullable=False)
    logged_at = Column(DateTime, default=_utcnow)

class Workout(Base):
    """Workout session tracking"""
    __tablename__ = "workouts"
    __table_args__ = (
        Index("ix_workouts_date", "date"),
        CheckConstraint("workout_type IN ('strength', 'cardio', 'flexibility', 'sports', 'other')", name="ck_workout_type"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date, nullable=False)
    workout_type = Column(String, nullable=False)
    name = Column(String, nullable=True)
    duration_minutes = Column(Integer, nullable=True)
    calories_burned = Column(Float, nullable=True)
    notes = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    
    exercises = relationship("Exercise", back_populates="workout", cascade="all, delete-orphan")


class Exercise(Base):
    """Individual exercises within a workout"""
    __tablename__ = "exercises"
    __table_args__ = (
        Index("ix_exercises_workout_id", "workout_id"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    workout_id = Column(Integer, ForeignKey("workouts.id", ondelete="CASCADE"))
    exercise_name = Column(String, nullable=False)
    exercise_category = Column(String, nullable=True)
    
    workout = relationship("Workout", back_populates="exercises")
    sets = relationship("ExerciseSet", back_populates="exercise", cascade="all, delete-orphan")


class ExerciseSet(Base):
    """Individual sets for an exercise"""
    __tablename__ = "exercise_sets"
    __table_args__ = (
        Index("ix_exercise_sets_exercise_id", "exercise_id"),
        CheckConstraint("set_number >= 0", name="ck_set_number"),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    exercise_id = Column(Integer, ForeignKey("exercises.id", ondelete="CASCADE"))
    set_number = Column(Integer, nullable=False)
    reps = Column(Integer, nullable=True)
    weight_kg = Column(Float, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    distance_km = Column(Float, nullable=True)
    avg_heart_rate = Column(Integer, nullable=True)
    max_heart_rate = Column(Integer, nullable=True)
    elevation_m = Column(Float, nullable=True)
    intensity = Column(String, nullable=True)  # easy, moderate, hard, interval
    notes = Column(String, nullable=True)
    
    exercise = relationship("Exercise", back_populates="sets")


# ============ Workout Plans & Routines ============

class WorkoutRoutine(Base):
    """Reusable workout template (e.g., 'Push Day', 'Leg Day')"""
    __tablename__ = "workout_routines"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    is_preset = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=_utcnow)

    exercises = relationship("WorkoutRoutineExercise", back_populates="routine", cascade="all, delete-orphan", order_by="WorkoutRoutineExercise.sort_order")


class WorkoutRoutineExercise(Base):
    """An exercise slot in a routine with target sets/reps"""
    __tablename__ = "workout_routine_exercises"

    id = Column(Integer, primary_key=True, index=True)
    routine_id = Column(Integer, ForeignKey("workout_routines.id", ondelete="CASCADE"), nullable=False)
    sort_order = Column(Integer, nullable=False, default=0)
    target_sets = Column(Integer, nullable=False, default=3)
    target_reps = Column(Integer, nullable=True)
    exercise_category = Column(String, nullable=True)

    routine = relationship("WorkoutRoutine", back_populates="exercises")
    options = relationship("WorkoutRoutineExerciseOption", back_populates="routine_exercise", cascade="all, delete-orphan", order_by="WorkoutRoutineExerciseOption.sort_order")


class WorkoutRoutineExerciseOption(Base):
    """An exercise choice within a slot (alternatives the user can pick from)"""
    __tablename__ = "workout_routine_exercise_options"

    id = Column(Integer, primary_key=True, index=True)
    routine_exercise_id = Column(Integer, ForeignKey("workout_routine_exercises.id", ondelete="CASCADE"), nullable=False)
    exercise_name = Column(String, nullable=False)
    is_default = Column(Integer, nullable=False, default=0)
    sort_order = Column(Integer, nullable=False, default=0)

    routine_exercise = relationship("WorkoutRoutineExercise", back_populates="options")


class WorkoutPlan(Base):
    """Weekly workout schedule (maps routines to days)"""
    __tablename__ = "workout_plans"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    duration_type = Column(String, nullable=False, default="repeating")  # 'repeating' or 'fixed'
    duration_weeks = Column(Integer, nullable=True)
    start_date = Column(Date, nullable=True)
    is_active = Column(Integer, nullable=False, default=0)
    is_preset = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=_utcnow)

    days = relationship("WorkoutPlanDay", back_populates="plan", cascade="all, delete-orphan", order_by="WorkoutPlanDay.day_of_week")


class WorkoutPlanDay(Base):
    """Maps a routine to a day of the week within a plan"""
    __tablename__ = "workout_plan_days"

    id = Column(Integer, primary_key=True, index=True)
    plan_id = Column(Integer, ForeignKey("workout_plans.id", ondelete="CASCADE"), nullable=False)
    day_of_week = Column(Integer, nullable=False)  # 0=Monday .. 6=Sunday
    routine_id = Column(Integer, ForeignKey("workout_routines.id", ondelete="SET NULL"), nullable=True)

    plan = relationship("WorkoutPlan", back_populates="days")
    routine = relationship("WorkoutRoutine")


class UserSettings(Base):
    """App-wide user preferences (single row, no auth)"""
    __tablename__ = "user_settings"

    id = Column(Integer, primary_key=True, index=True)
    weight_unit = Column(String, nullable=False, default="kg")  # "kg" or "lb"
    ai_provider = Column(String, nullable=True)   # "openai", "claude", "gemini", "ollama", "huggingface", "custom"
    ai_model = Column(String, nullable=True)      # "gpt-4o", "claude-sonnet-4-20250514", "llama3.1:8b", etc.
    ai_api_key_enc = Column(String, nullable=True) # Fernet-encrypted API key
    ai_endpoint = Column(String, nullable=True)    # Custom endpoint URL (Ollama, OpenRouter, vLLM, etc.)
    scholar_search_enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class CoachMessage(Base):
    """Chat message in coach conversation"""
    __tablename__ = "coach_messages"
    __table_args__ = (
        Index("ix_coach_messages_created", "created_at"),
        Index("ix_coach_messages_session", "session_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String, nullable=True)  # groups messages into conversations
    role = Column(String, nullable=False)     # "user" or "assistant"
    content = Column(String, nullable=False)
    provider = Column(String, nullable=True)  # which AI provider generated this
    model = Column(String, nullable=True)     # which model was used
    sources_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class CoachMemory(Base):
    """Rolling conversation summary for token management"""
    __tablename__ = "coach_memory"

    id = Column(Integer, primary_key=True, index=True)
    summary_text = Column(String, nullable=False)
    message_count = Column(Integer, nullable=False, default=0)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class KnowledgeDocument(Base):
    """Metadata for curated evidence, uploads, and user notes."""
    __tablename__ = "knowledge_documents"
    __table_args__ = (
        Index("ix_knowledge_documents_scope_created", "scope", "created_at"),
        Index("ix_knowledge_documents_file_hash", "file_hash"),
    )

    id = Column(Integer, primary_key=True, index=True)
    scope = Column(String, nullable=False, default="global-curated")
    title = Column(String, nullable=False)
    source_type = Column(String, nullable=False)  # curated, upload, note, scholar-cache
    origin_url = Column(String, nullable=True)
    doi = Column(String, nullable=True)
    year = Column(Integer, nullable=True)
    trust_tier = Column(String, nullable=False, default="trusted")
    file_hash = Column(String, nullable=True)
    status = Column(String, nullable=False, default="ready")
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    passages = relationship(
        "KnowledgePassage",
        back_populates="document",
        cascade="all, delete-orphan",
        order_by="KnowledgePassage.chunk_index",
    )


class KnowledgePassage(Base):
    """Chunked passage stored for sparse and dense retrieval."""
    __tablename__ = "knowledge_passages"
    __table_args__ = (
        Index("ix_knowledge_passages_document_chunk", "document_id", "chunk_index"),
        Index("ix_knowledge_passages_embedding_id", "embedding_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    document_id = Column(Integer, ForeignKey("knowledge_documents.id", ondelete="CASCADE"), nullable=False)
    chunk_index = Column(Integer, nullable=False)
    section_title = Column(String, nullable=True)
    page_number = Column(Integer, nullable=True)
    token_count = Column(Integer, nullable=False, default=0)
    text = Column(Text, nullable=False)
    text_hash = Column(String, nullable=False)
    embedding_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

    document = relationship("KnowledgeDocument", back_populates="passages")


class EvidenceCache(Base):
    """TTL cache for scholarly provider responses."""
    __tablename__ = "evidence_cache"
    __table_args__ = (
        UniqueConstraint("provider", "query_hash", name="uq_evidence_cache_provider_query"),
        Index("ix_evidence_cache_expires", "expires_at"),
    )

    id = Column(Integer, primary_key=True, index=True)
    query_hash = Column(String, nullable=False)
    provider = Column(String, nullable=False)
    payload_json = Column(Text, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
