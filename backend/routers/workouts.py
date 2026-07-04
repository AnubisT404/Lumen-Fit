from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload, subqueryload
from database import get_db
from models import Workout, Exercise, ExerciseSet
from datetime import date, datetime, timedelta
from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum
from collections import Counter
from sqlalchemy import func, desc
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

# ============ Enums ============

class WorkoutTypeEnum(str, Enum):
    strength = "strength"
    cardio = "cardio"
    flexibility = "flexibility"
    sports = "sports"
    other = "other"

class ExerciseCategoryEnum(str, Enum):
    chest = "chest"
    back = "back"
    shoulders = "shoulders"
    legs = "legs"
    arms = "arms"
    core = "core"
    cardio = "cardio"

# ============ Pydantic Schemas ============

class SetCreate(BaseModel):
    set_number: int = Field(1, ge=0)
    reps: Optional[int] = Field(None, ge=0, le=1000)
    weight_kg: Optional[float] = Field(None, ge=0, le=1000)
    duration_seconds: Optional[int] = Field(None, ge=0)
    distance_km: Optional[float] = Field(None, ge=0)
    notes: Optional[str] = Field(None, max_length=500)

class ExerciseCreate(BaseModel):
    exercise_name: str = Field(..., min_length=1, max_length=100)
    exercise_category: Optional[ExerciseCategoryEnum] = None
    sets: List[SetCreate] = []

class WorkoutCreate(BaseModel):
    workout_type: WorkoutTypeEnum
    name: Optional[str] = Field(None, max_length=100)
    duration_minutes: Optional[int] = Field(None, ge=0, le=1440)
    calories_burned: Optional[float] = Field(None, ge=0)
    notes: Optional[str] = Field(None, max_length=1000)
    exercises: List[ExerciseCreate] = []

class QuickCardioCreate(BaseModel):
    """Quick add for cardio workouts"""
    exercise_type: str = Field(..., min_length=1, max_length=100)
    duration_minutes: int = Field(..., gt=0, le=1440)
    calories_burned: Optional[float] = Field(None, ge=0)
    distance_km: Optional[float] = Field(None, ge=0)
    avg_heart_rate: Optional[int] = Field(None, ge=30, le=250)
    max_heart_rate: Optional[int] = Field(None, ge=30, le=250)
    elevation_m: Optional[float] = Field(None, ge=0)
    intensity: Optional[str] = Field(None, pattern="^(easy|moderate|hard|interval)$")
    notes: Optional[str] = Field(None, max_length=1000)

class SetResponse(BaseModel):
    id: int
    set_number: int
    reps: Optional[int]
    weight_kg: Optional[float]
    duration_seconds: Optional[int]
    distance_km: Optional[float]
    avg_heart_rate: Optional[int]
    max_heart_rate: Optional[int]
    elevation_m: Optional[float]
    intensity: Optional[str]
    notes: Optional[str]

    class Config:
        from_attributes = True

class ExerciseResponse(BaseModel):
    id: int
    exercise_name: str
    exercise_category: Optional[str]
    sets: List[SetResponse]

    class Config:
        from_attributes = True

class WorkoutResponse(BaseModel):
    id: int
    date: date
    workout_type: str
    name: Optional[str]
    duration_minutes: Optional[int]
    calories_burned: Optional[float]
    notes: Optional[str]
    exercises: List[ExerciseResponse]
    created_at: datetime

    class Config:
        from_attributes = True

# ============ Common Exercises Database ============

EXERCISE_DATABASE = {
    "chest": [
        "Bench Press", "Incline Bench Press", "Decline Bench Press",
        "Dumbbell Fly", "Cable Fly", "Push-ups", "Chest Press Machine",
        "Incline Dumbbell Press", "Dips (Chest)"
    ],
    "back": [
        "Pull-ups", "Lat Pulldown", "Bent Over Row", "Seated Cable Row",
        "T-Bar Row", "Deadlift", "Face Pulls", "Single Arm Dumbbell Row",
        "Chin-ups", "Hyperextensions"
    ],
    "shoulders": [
        "Overhead Press", "Military Press", "Lateral Raise", "Front Raise",
        "Rear Delt Fly", "Arnold Press", "Upright Row", "Shrugs",
        "Face Pulls", "Cable Lateral Raise"
    ],
    "legs": [
        "Squat", "Leg Press", "Lunges", "Romanian Deadlift", "Leg Curl",
        "Leg Extension", "Calf Raise", "Hip Thrust", "Bulgarian Split Squat",
        "Hack Squat", "Goblet Squat", "Front Squat"
    ],
    "arms": [
        "Bicep Curl", "Hammer Curl", "Tricep Pushdown", "Skull Crushers",
        "Preacher Curl", "Concentration Curl", "Overhead Tricep Extension",
        "Cable Curl", "Dips (Triceps)", "Close Grip Bench Press"
    ],
    "core": [
        "Plank", "Crunches", "Russian Twist", "Leg Raise", "Ab Wheel",
        "Cable Crunch", "Hanging Leg Raise", "Mountain Climbers",
        "Dead Bug", "Pallof Press", "Side Plank"
    ],
    "cardio": [
        "Running", "Cycling", "Swimming", "Rowing", "Elliptical",
        "Jump Rope", "Stair Climber", "Walking", "HIIT", "Sprints"
    ]
}

# ============ API Endpoints ============

@router.get("/exercises")
def get_exercise_database():
    """Get list of common exercises by category"""
    return EXERCISE_DATABASE

@router.get("/exercises/search")
def search_exercises(q: str = "", db: Session = Depends(get_db)):
    """Search exercises: user's past exercises first, then built-in library"""
    q_lower = q.lower().strip()
    results = []
    seen = set()
    
    if len(q_lower) >= 1:
        # 1. User's past exercises (highest priority — what they actually do)
        past = db.query(
            Exercise.exercise_name,
            Exercise.exercise_category,
            func.count(Exercise.id).label('usage_count'),
            func.max(Workout.date).label('last_used')
        ).join(Workout).filter(
            Exercise.exercise_name.ilike(f"%{q}%")
        ).group_by(
            Exercise.exercise_name, Exercise.exercise_category
        ).order_by(desc('usage_count')).limit(10).all()
        
        for row in past:
            key = row.exercise_name.lower()
            if key not in seen:
                seen.add(key)
                results.append({
                    "name": row.exercise_name,
                    "category": row.exercise_category or "",
                    "source": "history",
                    "usage_count": row.usage_count,
                    "last_used": row.last_used.isoformat() if row.last_used else None,
                })
        
        # 2. Built-in library (fill remaining slots)
        for category, exercises in EXERCISE_DATABASE.items():
            for name in exercises:
                if q_lower in name.lower() and name.lower() not in seen:
                    seen.add(name.lower())
                    results.append({
                        "name": name,
                        "category": category,
                        "source": "library",
                        "usage_count": 0,
                        "last_used": None,
                    })
    else:
        # No query — return most used exercises, then library
        past = db.query(
            Exercise.exercise_name,
            Exercise.exercise_category,
            func.count(Exercise.id).label('usage_count')
        ).join(Workout).group_by(
            Exercise.exercise_name, Exercise.exercise_category
        ).order_by(desc('usage_count')).limit(10).all()
        
        for row in past:
            key = row.exercise_name.lower()
            if key not in seen:
                seen.add(key)
                results.append({
                    "name": row.exercise_name,
                    "category": row.exercise_category or "",
                    "source": "history",
                    "usage_count": row.usage_count,
                    "last_used": None,
                })
        
        # Fill with library
        for category, exercises in EXERCISE_DATABASE.items():
            for name in exercises:
                if name.lower() not in seen:
                    seen.add(name.lower())
                    results.append({
                        "name": name,
                        "category": category,
                        "source": "library",
                        "usage_count": 0,
                        "last_used": None,
                    })
    
    return {"exercises": results[:20]}

@router.get("/exercises/previous")
def get_previous_session(exercise_name: str, db: Session = Depends(get_db)):
    """Get the most recent session for a given exercise (for 'last time' hints)"""
    # Find the most recent exercise entry with this name
    last_exercise = db.query(Exercise).join(Workout).filter(
        Exercise.exercise_name.ilike(exercise_name)
    ).order_by(Workout.date.desc(), Workout.created_at.desc()).first()
    
    if not last_exercise:
        return {"found": False, "exercise_name": exercise_name}
    
    workout = last_exercise.workout
    sets = sorted(last_exercise.sets, key=lambda s: s.set_number)
    
    return {
        "found": True,
        "exercise_name": last_exercise.exercise_name,
        "date": workout.date.isoformat(),
        "workout_name": workout.name,
        "sets": [
            {
                "set_number": s.set_number,
                "reps": s.reps,
                "weight_kg": s.weight_kg,
                "duration_seconds": s.duration_seconds,
                "distance_km": s.distance_km,
                "avg_heart_rate": s.avg_heart_rate,
                "max_heart_rate": s.max_heart_rate,
                "elevation_m": s.elevation_m,
                "intensity": s.intensity,
            }
            for s in sets
        ],
        "total_volume": sum(
            (s.reps or 0) * (s.weight_kg or 0) for s in sets
        ),
    }

@router.get("/by-date")
def get_workouts_by_date(target_date: str, db: Session = Depends(get_db)):
    """Get workouts for a specific date (YYYY-MM-DD)"""
    try:
        d = date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    workouts = db.query(Workout).options(
        joinedload(Workout.exercises).joinedload(Exercise.sets)
    ).filter(Workout.date == d).all()
    
    total_duration = sum(w.duration_minutes or 0 for w in workouts)
    total_calories = sum(w.calories_burned or 0 for w in workouts)
    total_volume = sum(
        (s.reps or 0) * (s.weight_kg or 0)
        for w in workouts for e in w.exercises for s in e.sets
    )
    
    return {
        "date": d.isoformat(),
        "workouts": [
            {
                "id": w.id,
                "workout_type": w.workout_type,
                "name": w.name,
                "duration_minutes": w.duration_minutes,
                "calories_burned": w.calories_burned,
                "notes": w.notes,
                "created_at": w.created_at.isoformat() if w.created_at else None,
                "exercises": [
                    {
                        "id": e.id,
                        "exercise_name": e.exercise_name,
                        "exercise_category": e.exercise_category,
                        "sets": [
                            {
                                "id": s.id,
                                "set_number": s.set_number,
                                "reps": s.reps,
                                "weight_kg": s.weight_kg,
                                "duration_seconds": s.duration_seconds,
                                "distance_km": s.distance_km,
                                "avg_heart_rate": s.avg_heart_rate,
                                "max_heart_rate": s.max_heart_rate,
                                "elevation_m": s.elevation_m,
                                "intensity": s.intensity,
                                "notes": s.notes
                            }
                            for s in sorted(e.sets, key=lambda s: s.set_number)
                        ]
                    }
                    for e in w.exercises
                ]
            }
            for w in workouts
        ],
        "summary": {
            "total_workouts": len(workouts),
            "total_duration_minutes": total_duration,
            "total_calories_burned": round(total_calories, 1),
            "total_volume_kg": round(total_volume, 1),
        }
    }

@router.post("/", response_model=WorkoutResponse)
def log_workout(workout: WorkoutCreate, db: Session = Depends(get_db)):
    """Log a full workout with exercises and sets"""
    
    # Create workout
    new_workout = Workout(
        date=date.today(),
        workout_type=workout.workout_type,
        name=workout.name,
        duration_minutes=workout.duration_minutes,
        calories_burned=workout.calories_burned,
        notes=workout.notes
    )
    db.add(new_workout)
    db.flush()  # Get the workout ID
    
    # Add exercises and sets
    for exercise_data in workout.exercises:
        exercise = Exercise(
            workout_id=new_workout.id,
            exercise_name=exercise_data.exercise_name,
            exercise_category=exercise_data.exercise_category
        )
        db.add(exercise)
        db.flush()
        
        # Add sets for this exercise
        for set_data in exercise_data.sets:
            exercise_set = ExerciseSet(
                exercise_id=exercise.id,
                set_number=set_data.set_number,
                reps=set_data.reps,
                weight_kg=set_data.weight_kg,
                duration_seconds=set_data.duration_seconds,
                distance_km=set_data.distance_km,
                notes=set_data.notes
            )
            db.add(exercise_set)
    
    db.commit()
    db.refresh(new_workout)
    
    # Return with relationships loaded
    return db.query(Workout).options(
        joinedload(Workout.exercises).joinedload(Exercise.sets)
    ).filter(Workout.id == new_workout.id).first()

@router.post("/quick-cardio")
def quick_log_cardio(cardio: QuickCardioCreate, db: Session = Depends(get_db)):
    """Quick log a cardio session"""
    
    workout = Workout(
        date=date.today(),
        workout_type="cardio",
        name=cardio.exercise_type.capitalize(),
        duration_minutes=cardio.duration_minutes,
        calories_burned=cardio.calories_burned,
        notes=cardio.notes
    )
    db.add(workout)
    db.flush()
    
    # Add as single exercise with one "set"
    exercise = Exercise(
        workout_id=workout.id,
        exercise_name=cardio.exercise_type.capitalize(),
        exercise_category="cardio"
    )
    db.add(exercise)
    db.flush()
    
    # Add set with duration/distance
    exercise_set = ExerciseSet(
        exercise_id=exercise.id,
        set_number=1,
        duration_seconds=cardio.duration_minutes * 60,
        distance_km=cardio.distance_km,
        avg_heart_rate=cardio.avg_heart_rate,
        max_heart_rate=cardio.max_heart_rate,
        elevation_m=cardio.elevation_m,
        intensity=cardio.intensity,
    )
    db.add(exercise_set)
    
    db.commit()
    
    return {"message": "Cardio logged successfully", "workout_id": workout.id}

@router.get("/", response_model=List[WorkoutResponse])
def get_workouts(limit: int = 30, offset: int = 0, db: Session = Depends(get_db)):
    """Get workout history with all exercises and sets"""
    workouts = db.query(Workout).options(
        subqueryload(Workout.exercises).subqueryload(Exercise.sets)
    ).order_by(
        Workout.date.desc(),
        Workout.created_at.desc()
    ).offset(offset).limit(limit).all()
    
    return workouts

@router.get("/today")
def get_today_workouts(db: Session = Depends(get_db)):
    """Get today's workouts with summary"""
    today = date.today()
    workouts = db.query(Workout).options(
        joinedload(Workout.exercises).joinedload(Exercise.sets)
    ).filter(Workout.date == today).all()
    
    total_duration = sum(w.duration_minutes or 0 for w in workouts)
    total_calories = sum(w.calories_burned or 0 for w in workouts)
    total_exercises = sum(len(w.exercises) for w in workouts)
    total_sets = sum(len(e.sets) for w in workouts for e in w.exercises)
    
    # Calculate total volume (sets * reps * weight)
    total_volume = 0
    for workout in workouts:
        for exercise in workout.exercises:
            for s in exercise.sets:
                if s.reps and s.weight_kg:
                    total_volume += s.reps * s.weight_kg
    
    return {
        "date": today,
        "workouts": [
            {
                "id": w.id,
                "workout_type": w.workout_type,
                "name": w.name,
                "duration_minutes": w.duration_minutes,
                "calories_burned": w.calories_burned,
                "notes": w.notes,
                "created_at": w.created_at,
                "exercises": [
                    {
                        "id": e.id,
                        "exercise_name": e.exercise_name,
                        "exercise_category": e.exercise_category,
                        "sets": [
                            {
                                "id": s.id,
                                "set_number": s.set_number,
                                "reps": s.reps,
                                "weight_kg": s.weight_kg,
                                "duration_seconds": s.duration_seconds,
                                "distance_km": s.distance_km,
                                "avg_heart_rate": s.avg_heart_rate,
                                "max_heart_rate": s.max_heart_rate,
                                "elevation_m": s.elevation_m,
                                "intensity": s.intensity,
                                "notes": s.notes
                            }
                            for s in e.sets
                        ]
                    }
                    for e in w.exercises
                ]
            }
            for w in workouts
        ],
        "summary": {
            "total_workouts": len(workouts),
            "total_duration_minutes": total_duration,
            "total_calories_burned": round(total_calories, 1),
            "total_exercises": total_exercises,
            "total_sets": total_sets,
            "total_volume_kg": round(total_volume, 1)
        }
    }

@router.get("/stats")
def get_workout_stats(db: Session = Depends(get_db)):
    """Get workout statistics"""
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    
    # This week
    week_workouts = db.query(Workout).options(
        joinedload(Workout.exercises).joinedload(Exercise.sets)
    ).filter(Workout.date >= week_ago).all()
    
    week_duration = sum(w.duration_minutes or 0 for w in week_workouts)
    week_calories = sum(w.calories_burned or 0 for w in week_workouts)
    week_volume = sum(
        s.reps * s.weight_kg 
        for w in week_workouts 
        for e in w.exercises 
        for s in e.sets 
        if s.reps and s.weight_kg
    )
    
    # This month
    month_workouts = db.query(Workout).options(
        joinedload(Workout.exercises).joinedload(Exercise.sets)
    ).filter(Workout.date >= month_ago).all()
    
    month_duration = sum(w.duration_minutes or 0 for w in month_workouts)
    month_calories = sum(w.calories_burned or 0 for w in month_workouts)
    
    # Most common exercises
    all_exercises = [e.exercise_name for w in month_workouts for e in w.exercises]
    most_common = Counter(all_exercises).most_common(5)
    
    # Personal records via SQL (max weight per exercise this month)
    from sqlalchemy import func as sqlfunc
    pr_query = (
        db.query(Exercise.exercise_name, sqlfunc.max(ExerciseSet.weight_kg))
        .join(ExerciseSet, ExerciseSet.exercise_id == Exercise.id)
        .join(Workout, Workout.id == Exercise.workout_id)
        .filter(Workout.date >= month_ago, ExerciseSet.weight_kg.isnot(None))
        .group_by(Exercise.exercise_name)
        .all()
    )
    pr_records = {name: weight for name, weight in pr_query}
    
    return {
        "this_week": {
            "total_workouts": len(week_workouts),
            "total_minutes": week_duration,
            "total_calories": round(week_calories, 1),
            "total_volume_kg": round(week_volume, 1)
        },
        "this_month": {
            "total_workouts": len(month_workouts),
            "total_minutes": month_duration,
            "total_calories": round(month_calories, 1)
        },
        "favorite_exercises": [{"name": name, "count": count} for name, count in most_common],
        "personal_records": pr_records
    }

@router.post("/{workout_id}/exercise")
def add_exercise_to_workout(
    workout_id: int, 
    exercise: ExerciseCreate, 
    db: Session = Depends(get_db)
):
    """Add an exercise to an existing workout"""
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    new_exercise = Exercise(
        workout_id=workout_id,
        exercise_name=exercise.exercise_name,
        exercise_category=exercise.exercise_category
    )
    db.add(new_exercise)
    db.flush()
    
    for set_data in exercise.sets:
        exercise_set = ExerciseSet(
            exercise_id=new_exercise.id,
            set_number=set_data.set_number,
            reps=set_data.reps,
            weight_kg=set_data.weight_kg,
            duration_seconds=set_data.duration_seconds,
            distance_km=set_data.distance_km,
            notes=set_data.notes
        )
        db.add(exercise_set)
    
    db.commit()
    
    return {"message": "Exercise added", "exercise_id": new_exercise.id}

@router.post("/exercise/{exercise_id}/set")
def add_set_to_exercise(
    exercise_id: int, 
    set_data: SetCreate, 
    db: Session = Depends(get_db)
):
    """Add a set to an existing exercise"""
    exercise = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")
    
    # Auto-increment set number if not provided or 0
    if set_data.set_number == 0 or set_data.set_number == 1:
        existing_sets = [s.set_number for s in exercise.sets]
        max_set = max(existing_sets) if existing_sets else 0
        set_data.set_number = max_set + 1
    
    new_set = ExerciseSet(
        exercise_id=exercise_id,
        **set_data.model_dump()
    )
    db.add(new_set)
    db.commit()
    
    return {"message": "Set added", "set_id": new_set.id}

@router.get("/{workout_id}", response_model=WorkoutResponse)
def get_workout(workout_id: int, db: Session = Depends(get_db)):
    """Get a single workout by ID with all exercises and sets"""
    workout = db.query(Workout).options(
        subqueryload(Workout.exercises).subqueryload(Exercise.sets)
    ).filter(Workout.id == workout_id).first()
    
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    return workout

@router.put("/{workout_id}")
def update_workout(workout_id: int, data: WorkoutCreate, db: Session = Depends(get_db)):
    """Update a workout — replaces all exercises and sets"""
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    # Update workout fields
    workout.workout_type = data.workout_type.value
    workout.name = data.name
    workout.duration_minutes = data.duration_minutes
    workout.calories_burned = data.calories_burned
    workout.notes = data.notes
    
    # Delete old exercises (cascades to sets)
    for ex in workout.exercises:
        db.delete(ex)
    db.flush()
    
    # Add new exercises
    for ex_data in data.exercises:
        exercise = Exercise(
            workout_id=workout.id,
            exercise_name=ex_data.exercise_name,
            exercise_category=ex_data.exercise_category.value if ex_data.exercise_category else None
        )
        db.add(exercise)
        db.flush()
        
        for s in ex_data.sets:
            exercise_set = ExerciseSet(
                exercise_id=exercise.id,
                set_number=s.set_number,
                reps=s.reps,
                weight_kg=s.weight_kg,
                duration_seconds=s.duration_seconds,
                distance_km=s.distance_km,
                notes=s.notes,
            )
            db.add(exercise_set)
    
    db.commit()
    db.refresh(workout)
    
    return {"message": "Workout updated", "workout_id": workout.id}

@router.put("/{workout_id}/cardio")
def update_cardio(workout_id: int, cardio: QuickCardioCreate, db: Session = Depends(get_db)):
    """Update a cardio workout"""
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    workout.workout_type = "cardio"
    workout.name = cardio.exercise_type.capitalize()
    workout.duration_minutes = cardio.duration_minutes
    workout.calories_burned = cardio.calories_burned
    workout.notes = cardio.notes
    
    # Delete old exercises
    for ex in workout.exercises:
        db.delete(ex)
    db.flush()
    
    # Add single exercise with one set
    exercise = Exercise(
        workout_id=workout.id,
        exercise_name=cardio.exercise_type.capitalize(),
        exercise_category="cardio"
    )
    db.add(exercise)
    db.flush()
    
    exercise_set = ExerciseSet(
        exercise_id=exercise.id,
        set_number=1,
        duration_seconds=cardio.duration_minutes * 60,
        distance_km=cardio.distance_km,
        avg_heart_rate=cardio.avg_heart_rate,
        max_heart_rate=cardio.max_heart_rate,
        elevation_m=cardio.elevation_m,
        intensity=cardio.intensity,
    )
    db.add(exercise_set)
    
    db.commit()
    return {"message": "Cardio updated", "workout_id": workout.id}

@router.delete("/{workout_id}")
def delete_workout(workout_id: int, db: Session = Depends(get_db)):
    """Delete a workout and all its exercises/sets"""
    workout = db.query(Workout).filter(Workout.id == workout_id).first()
    
    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found")
    
    db.delete(workout)
    db.commit()
    
    return {"message": "Workout deleted"}

@router.delete("/exercise/{exercise_id}")
def delete_exercise(exercise_id: int, db: Session = Depends(get_db)):
    """Delete an exercise and all its sets"""
    exercise = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")
    
    db.delete(exercise)
    db.commit()
    
    return {"message": "Exercise deleted"}
