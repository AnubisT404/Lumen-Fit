from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import UserProfile, Goals
from datetime import datetime, timezone
from typing import Optional
from pydantic import BaseModel, Field
from enum import Enum

router = APIRouter()

# ============ Enums ============

class SexEnum(str, Enum):
    male = "male"
    female = "female"

class ActivityLevelEnum(str, Enum):
    sedentary = "sedentary"
    lightly_active = "lightly_active"
    moderately_active = "moderately_active"
    very_active = "very_active"
    extremely_active = "extremely_active"

class GoalEnum(str, Enum):
    lose = "lose"
    maintain = "maintain"
    gain = "gain"

# ============ Pydantic Schemas ============

class UserProfileCreate(BaseModel):
    name: Optional[str] = None
    age: int = Field(..., ge=1, le=120, description="Age in years (1-120)")
    sex: SexEnum
    height_cm: float = Field(..., gt=30, lt=300, description="Height in cm (30-300)")
    current_weight_kg: float = Field(..., gt=1, lt=500, description="Weight in kg (1-500)")
    activity_level: ActivityLevelEnum = ActivityLevelEnum.moderately_active
    goal: GoalEnum = GoalEnum.maintain
    target_weight_kg: Optional[float] = Field(None, gt=1, lt=500)

class GoalsResponse(BaseModel):
    daily_calories: float
    protein_g: float
    carbs_g: float
    fats_g: float
    water_ml: int

    class Config:
        from_attributes = True

class GoalsUpdate(BaseModel):
    daily_calories: Optional[float] = Field(None, gt=0, lt=10000)
    protein_g: Optional[float] = Field(None, ge=0, lt=1000)
    carbs_g: Optional[float] = Field(None, ge=0, lt=2000)
    fats_g: Optional[float] = Field(None, ge=0, lt=1000)
    water_ml: Optional[int] = Field(None, gt=0, lt=10000)

# Activity level multipliers for TDEE
ACTIVITY_MULTIPLIERS = {
    "sedentary": 1.2,
    "lightly_active": 1.375,
    "moderately_active": 1.55,
    "very_active": 1.725,
    "extremely_active": 1.9
}

def calculate_tdee(profile: UserProfile) -> float:
    """Calculate Total Daily Energy Expenditure using Mifflin-St Jeor"""
    # BMR calculation
    if profile.sex.lower() == 'male':
        bmr = (10 * profile.current_weight_kg) + (6.25 * profile.height_cm) - (5 * profile.age) + 5
    else:
        bmr = (10 * profile.current_weight_kg) + (6.25 * profile.height_cm) - (5 * profile.age) - 161
    
    # Apply activity multiplier
    multiplier = ACTIVITY_MULTIPLIERS.get(profile.activity_level, 1.55)
    tdee = bmr * multiplier
    
    return tdee

def calculate_macro_targets(tdee: float, goal: str, weight_kg: float) -> dict:
    """Calculate macro targets based on TDEE and goal"""
    # Adjust calories based on goal
    if goal == "lose":
        daily_calories = tdee - 500  # 500 cal deficit for 1lb/week loss
    elif goal == "gain":
        daily_calories = tdee + 300  # 300 cal surplus for lean gain
    else:
        daily_calories = tdee
    
    # Protein: 2g per kg of body weight (prioritize muscle preservation)
    protein_g = weight_kg * 2.0
    protein_cal = protein_g * 4
    
    # Fats: 25-30% of calories
    fat_cal = daily_calories * 0.28
    fats_g = fat_cal / 9
    
    # Carbs: remaining calories — if protein+fat exceed budget, scale them down
    remaining_cal = daily_calories - protein_cal - fat_cal
    if remaining_cal < 0:
        # Scale protein and fat proportionally to fit within calorie budget
        total_fixed = protein_cal + fat_cal
        scale = daily_calories / total_fixed if total_fixed > 0 else 1
        protein_g *= scale
        fats_g *= scale
        carbs_g = 0.0
    else:
        carbs_g = remaining_cal / 4
    
    return {
        "daily_calories": round(daily_calories, 0),
        "protein_g": round(protein_g, 1),
        "carbs_g": round(carbs_g, 1),
        "fats_g": round(fats_g, 1)
    }

def _upsert_goals(db: Session, macros: dict) -> Goals:
    """Create or update goals from calculated macros."""
    goals = db.query(Goals).first()
    if goals:
        goals.daily_calories = macros["daily_calories"]
        goals.protein_g = macros["protein_g"]
        goals.carbs_g = macros["carbs_g"]
        goals.fats_g = macros["fats_g"]
        goals.updated_at = datetime.now(timezone.utc)
    else:
        goals = Goals(
            daily_calories=macros["daily_calories"],
            protein_g=macros["protein_g"],
            carbs_g=macros["carbs_g"],
            fats_g=macros["fats_g"],
            water_ml=2000
        )
        db.add(goals)
    db.commit()
    db.refresh(goals)
    return goals

@router.post("/setup", response_model=GoalsResponse)
def setup_profile(profile_data: UserProfileCreate, db: Session = Depends(get_db)):
    """Initial profile setup - calculates TDEE and sets macro goals"""
    
    existing_profile = db.query(UserProfile).first()
    
    if existing_profile:
        for key, value in profile_data.model_dump(exclude_unset=True).items():
            setattr(existing_profile, key, value)
        existing_profile.updated_at = datetime.now(timezone.utc)
        profile = existing_profile
    else:
        profile = UserProfile(**profile_data.model_dump())
        db.add(profile)
    
    db.commit()
    db.refresh(profile)
    
    tdee = calculate_tdee(profile)
    macros = calculate_macro_targets(tdee, profile.goal, profile.current_weight_kg)
    goals = _upsert_goals(db, macros)
    
    return goals

@router.get("/", response_model=dict)
def get_profile(db: Session = Depends(get_db)):
    """Get current profile and goals"""
    profile = db.query(UserProfile).first()
    goals = db.query(Goals).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found. Please setup your profile first.")
    
    return {
        "profile": {
            "name": profile.name,
            "age": profile.age,
            "sex": profile.sex,
            "height_cm": profile.height_cm,
            "current_weight_kg": profile.current_weight_kg,
            "activity_level": profile.activity_level,
            "goal": profile.goal,
            "target_weight_kg": profile.target_weight_kg
        },
        "goals": {
            "daily_calories": goals.daily_calories,
            "protein_g": goals.protein_g,
            "carbs_g": goals.carbs_g,
            "fats_g": goals.fats_g,
            "water_ml": goals.water_ml
        } if goals else None
    }

@router.put("/", response_model=dict)
def update_profile(profile_data: UserProfileCreate, db: Session = Depends(get_db)):
    """Update profile and recalculate TDEE/goals automatically"""
    profile = db.query(UserProfile).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found. Please setup your profile first.")
    
    for key, value in profile_data.model_dump(exclude_unset=True).items():
        setattr(profile, key, value)
    profile.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(profile)
    
    tdee = calculate_tdee(profile)
    macros = calculate_macro_targets(tdee, profile.goal, profile.current_weight_kg)
    goals = _upsert_goals(db, macros)
    
    return {
        "profile": {
            "name": profile.name, "age": profile.age, "sex": profile.sex,
            "height_cm": profile.height_cm, "current_weight_kg": profile.current_weight_kg,
            "activity_level": profile.activity_level, "goal": profile.goal,
            "target_weight_kg": profile.target_weight_kg
        },
        "goals": {
            "daily_calories": goals.daily_calories, "protein_g": goals.protein_g,
            "carbs_g": goals.carbs_g, "fats_g": goals.fats_g, "water_ml": goals.water_ml
        }
    }

@router.get("/goals", response_model=GoalsResponse)
def get_goals(db: Session = Depends(get_db)):
    """Get current macro and calorie goals"""
    goals = db.query(Goals).first()
    
    if not goals:
        raise HTTPException(status_code=404, detail="Goals not set. Please setup your profile first.")
    
    return goals

@router.put("/goals", response_model=GoalsResponse)
def update_goals(
    goals_data: GoalsUpdate,
    db: Session = Depends(get_db)
):
    """Manually adjust goals"""
    goals = db.query(Goals).first()
    
    if not goals:
        raise HTTPException(status_code=404, detail="Goals not found. Please setup your profile first.")
    
    update_data = goals_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None:
            setattr(goals, field, value)
    
    goals.updated_at = datetime.now(timezone.utc)
    db.commit()
    
    return goals
