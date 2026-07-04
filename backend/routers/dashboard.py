from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session, joinedload
from database import get_db
from models import Meal, MealItem, WaterLog, Workout, BodyMeasurement, Goals
from datetime import date, timedelta
from sqlalchemy import func
from pydantic import BaseModel
from typing import Optional

router = APIRouter()


class MacroValues(BaseModel):
    calories: float
    protein_g: float
    carbs_g: float
    fats_g: float


class NutritionBlock(BaseModel):
    consumed: MacroValues
    goals: MacroValues
    remaining: MacroValues
    percentage: MacroValues


class WaterBlock(BaseModel):
    consumed_ml: int
    goal_ml: int
    remaining_ml: int
    percentage: float


class WorkoutSummary(BaseModel):
    type: Optional[str] = None
    duration: Optional[int] = None
    calories: Optional[float] = None


class ExerciseBlock(BaseModel):
    total_workouts: int
    total_minutes: int
    calories_burned: float
    workouts: list[WorkoutSummary] = []


class WeightBlock(BaseModel):
    current_kg: Optional[float] = None
    last_measured: Optional[date] = None


class StreakDay(BaseModel):
    day: str
    date: str
    logged: bool
    future: bool


class DashboardSummary(BaseModel):
    net_calories: float
    meals_logged: int
    water_glasses: float
    active_minutes: int


class DashboardResponse(BaseModel):
    date: date
    nutrition: NutritionBlock
    water: WaterBlock
    exercise: ExerciseBlock
    weight: WeightBlock
    meals_logged: int
    goals_configured: bool
    week_streak: list[StreakDay]
    summary: DashboardSummary


@router.get("/today", response_model=DashboardResponse)
def get_dashboard_today(db: Session = Depends(get_db)):
    """Get complete overview of today's tracking data"""
    return _get_dashboard_for_date(date.today(), db)


@router.get("/{target_date}", response_model=DashboardResponse)
def get_dashboard_by_date(target_date: str, db: Session = Depends(get_db)):
    """Get complete overview of tracking data for a given date"""
    try:
        d = date.fromisoformat(target_date)
    except ValueError:
        d = date.today()
    return _get_dashboard_for_date(d, db)


def _get_dashboard_for_date(today: date, db: Session):
    """Shared logic for building dashboard response for any date"""
    
    # Get goals
    goals = db.query(Goals).first()
    
    # Get meals and calculate nutrition
    meals = db.query(Meal).options(
        joinedload(Meal.items).joinedload(MealItem.food)
    ).filter(Meal.date == today).all()
    
    total_calories = 0
    total_protein = 0
    total_carbs = 0
    total_fats = 0
    
    for meal in meals:
        for item in meal.items:
            total_calories += item.effective_calories * item.servings
            total_protein += item.effective_protein_g * item.servings
            total_carbs += item.effective_carbs_g * item.servings
            total_fats += item.effective_fats_g * item.servings
    
    # Get water intake
    water_logs = db.query(WaterLog).filter(WaterLog.date == today).all()
    total_water = sum(log.amount_ml for log in water_logs)
    
    # Get workouts
    workouts = db.query(Workout).filter(Workout.date == today).all()
    total_workout_minutes = sum(w.duration_minutes or 0 for w in workouts)
    total_calories_burned = sum(w.calories_burned or 0 for w in workouts)
    
    # Get latest weight
    latest_measurement = db.query(BodyMeasurement).order_by(
        BodyMeasurement.date.desc()
    ).first()
    
    # Week streak: which days this week (Mon-Sun) have logged food
    # Find Monday of current week
    today_weekday = today.weekday()  # 0=Mon, 6=Sun
    monday = today - timedelta(days=today_weekday)
    sunday = monday + timedelta(days=6)
    
    logged_dates = db.query(func.distinct(Meal.date)).filter(
        Meal.date >= monday,
        Meal.date <= sunday
    ).all()
    logged_set = {str(d[0]) for d in logged_dates}
    
    week_streak = []
    for i in range(7):
        d = monday + timedelta(days=i)
        week_streak.append({
            "day": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i],
            "date": str(d),
            "logged": str(d) in logged_set,
            "future": d > today
        })
    
    # Calculate remaining macros
    goal_calories = goals.daily_calories if goals else 2000
    goal_protein = goals.protein_g if goals else 150
    goal_carbs = goals.carbs_g if goals else 250
    goal_fats = goals.fats_g if goals else 65
    goal_water = goals.water_ml if goals else 2000
    goals_configured = goals is not None
    
    return {
        "date": today,
        "nutrition": {
            "consumed": {
                "calories": round(total_calories, 1),
                "protein_g": round(total_protein, 1),
                "carbs_g": round(total_carbs, 1),
                "fats_g": round(total_fats, 1)
            },
            "goals": {
                "calories": goal_calories,
                "protein_g": goal_protein,
                "carbs_g": goal_carbs,
                "fats_g": goal_fats
            },
            "remaining": {
                "calories": round(goal_calories - total_calories, 1),
                "protein_g": round(goal_protein - total_protein, 1),
                "carbs_g": round(goal_carbs - total_carbs, 1),
                "fats_g": round(goal_fats - total_fats, 1)
            },
            "percentage": {
                "calories": round((total_calories / goal_calories) * 100, 1) if goal_calories else 0,
                "protein_g": round((total_protein / goal_protein) * 100, 1) if goal_protein else 0,
                "carbs_g": round((total_carbs / goal_carbs) * 100, 1) if goal_carbs else 0,
                "fats_g": round((total_fats / goal_fats) * 100, 1) if goal_fats else 0
            }
        },
        "water": {
            "consumed_ml": total_water,
            "goal_ml": goal_water,
            "remaining_ml": max(0, goal_water - total_water),
            "percentage": round((total_water / goal_water) * 100, 1) if goal_water else 0
        },
        "exercise": {
            "total_workouts": len(workouts),
            "total_minutes": total_workout_minutes,
            "calories_burned": round(total_calories_burned, 1),
            "workouts": [
                {
                    "type": w.workout_type,
                    "duration": w.duration_minutes,
                    "calories": w.calories_burned
                } for w in workouts
            ]
        },
        "weight": {
            "current_kg": latest_measurement.weight_kg if latest_measurement else None,
            "last_measured": latest_measurement.date if latest_measurement else None
        },
        "meals_logged": len(meals),
        "goals_configured": goals_configured,
        "week_streak": week_streak,
        "summary": {
            "net_calories": round(total_calories - total_calories_burned, 1),
            "meals_logged": len(meals),
            "water_glasses": round(total_water / 250, 1),  # Assuming 250ml per glass
            "active_minutes": total_workout_minutes
        }
    }
