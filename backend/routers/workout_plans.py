from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload, subqueryload
from database import get_db, SessionLocal
from models import (
    WorkoutRoutine, WorkoutRoutineExercise, WorkoutRoutineExerciseOption,
    WorkoutPlan, WorkoutPlanDay
)
from datetime import date, datetime
from pydantic import BaseModel, Field
from typing import Optional, List
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


# ============ Preset Data ============

PRESET_ROUTINES = {
    "Push Day": {
        "description": "Chest, shoulders, triceps",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "chest",
             "options": ["Bench Press", "Dumbbell Bench Press", "Machine Chest Press"]},
            {"sort": 2, "sets": 3, "reps": 12, "cat": "chest",
             "options": ["Incline Dumbbell Press", "Incline Bench Press", "Cable Flyes"]},
            {"sort": 3, "sets": 3, "reps": 10, "cat": "shoulders",
             "options": ["Overhead Press", "Dumbbell Shoulder Press", "Arnold Press"]},
            {"sort": 4, "sets": 3, "reps": 15, "cat": "shoulders",
             "options": ["Lateral Raises", "Cable Lateral Raises"]},
            {"sort": 5, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Tricep Pushdowns", "Overhead Tricep Extension", "Skull Crushers"]},
        ],
    },
    "Pull Day": {
        "description": "Back, biceps, rear delts",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "back",
             "options": ["Barbell Rows", "Dumbbell Rows", "Cable Rows"]},
            {"sort": 2, "sets": 3, "reps": 10, "cat": "back",
             "options": ["Pull Ups", "Lat Pulldowns", "Chin Ups"]},
            {"sort": 3, "sets": 3, "reps": 12, "cat": "back",
             "options": ["Seated Cable Row", "T-Bar Row", "Machine Row"]},
            {"sort": 4, "sets": 3, "reps": 15, "cat": "shoulders",
             "options": ["Face Pulls", "Reverse Flyes", "Rear Delt Machine"]},
            {"sort": 5, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Barbell Curls", "Dumbbell Curls", "Hammer Curls"]},
        ],
    },
    "Leg Day": {
        "description": "Quads, hamstrings, glutes, calves",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "legs",
             "options": ["Barbell Squats", "Leg Press", "Hack Squat"]},
            {"sort": 2, "sets": 3, "reps": 10, "cat": "legs",
             "options": ["Romanian Deadlift", "Stiff Leg Deadlift", "Good Mornings"]},
            {"sort": 3, "sets": 3, "reps": 12, "cat": "legs",
             "options": ["Leg Extension", "Bulgarian Split Squats", "Lunges"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "legs",
             "options": ["Leg Curls", "Nordic Curls", "Seated Leg Curls"]},
            {"sort": 5, "sets": 4, "reps": 15, "cat": "legs",
             "options": ["Calf Raises", "Seated Calf Raises"]},
        ],
    },
    "Upper Body": {
        "description": "Full upper body workout",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "chest",
             "options": ["Bench Press", "Dumbbell Bench Press"]},
            {"sort": 2, "sets": 4, "reps": 8, "cat": "back",
             "options": ["Barbell Rows", "Dumbbell Rows"]},
            {"sort": 3, "sets": 3, "reps": 10, "cat": "shoulders",
             "options": ["Overhead Press", "Dumbbell Shoulder Press"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "back",
             "options": ["Pull Ups", "Lat Pulldowns"]},
            {"sort": 5, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Barbell Curls", "Hammer Curls"]},
            {"sort": 6, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Tricep Pushdowns", "Skull Crushers"]},
        ],
    },
    "Lower Body": {
        "description": "Full lower body workout",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "legs",
             "options": ["Barbell Squats", "Leg Press"]},
            {"sort": 2, "sets": 3, "reps": 10, "cat": "legs",
             "options": ["Romanian Deadlift", "Stiff Leg Deadlift"]},
            {"sort": 3, "sets": 3, "reps": 12, "cat": "legs",
             "options": ["Leg Extension", "Bulgarian Split Squats"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "legs",
             "options": ["Leg Curls", "Nordic Curls"]},
            {"sort": 5, "sets": 3, "reps": 15, "cat": "legs",
             "options": ["Hip Thrust", "Glute Bridge"]},
            {"sort": 6, "sets": 4, "reps": 15, "cat": "legs",
             "options": ["Calf Raises", "Seated Calf Raises"]},
        ],
    },
    "Full Body A": {
        "description": "Full body workout — push emphasis",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "chest",
             "options": ["Bench Press", "Dumbbell Bench Press"]},
            {"sort": 2, "sets": 4, "reps": 8, "cat": "legs",
             "options": ["Barbell Squats", "Leg Press"]},
            {"sort": 3, "sets": 3, "reps": 10, "cat": "shoulders",
             "options": ["Overhead Press", "Dumbbell Shoulder Press"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Tricep Pushdowns", "Overhead Tricep Extension"]},
            {"sort": 5, "sets": 3, "reps": 15, "cat": "core",
             "options": ["Planks", "Cable Crunches"]},
        ],
    },
    "Full Body B": {
        "description": "Full body workout — pull emphasis",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "back",
             "options": ["Barbell Rows", "Dumbbell Rows"]},
            {"sort": 2, "sets": 4, "reps": 8, "cat": "legs",
             "options": ["Romanian Deadlift", "Stiff Leg Deadlift"]},
            {"sort": 3, "sets": 3, "reps": 10, "cat": "back",
             "options": ["Pull Ups", "Lat Pulldowns"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Barbell Curls", "Hammer Curls"]},
            {"sort": 5, "sets": 3, "reps": 15, "cat": "core",
             "options": ["Hanging Leg Raises", "Russian Twists"]},
        ],
    },
    "Full Body C": {
        "description": "Full body workout — legs emphasis",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "legs",
             "options": ["Barbell Squats", "Hack Squat"]},
            {"sort": 2, "sets": 3, "reps": 10, "cat": "chest",
             "options": ["Incline Dumbbell Press", "Cable Flyes"]},
            {"sort": 3, "sets": 3, "reps": 10, "cat": "back",
             "options": ["Seated Cable Row", "Machine Row"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "legs",
             "options": ["Leg Curls", "Leg Extension"]},
            {"sort": 5, "sets": 3, "reps": 15, "cat": "shoulders",
             "options": ["Lateral Raises", "Face Pulls"]},
        ],
    },
    "Chest Day": {
        "description": "Chest-focused bro split",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "chest",
             "options": ["Bench Press", "Dumbbell Bench Press"]},
            {"sort": 2, "sets": 3, "reps": 10, "cat": "chest",
             "options": ["Incline Dumbbell Press", "Incline Bench Press"]},
            {"sort": 3, "sets": 3, "reps": 12, "cat": "chest",
             "options": ["Cable Flyes", "Dumbbell Flyes", "Pec Deck"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "chest",
             "options": ["Dips", "Push Ups", "Decline Press"]},
        ],
    },
    "Back Day": {
        "description": "Back-focused bro split",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 6, "cat": "back",
             "options": ["Deadlift", "Rack Pulls"]},
            {"sort": 2, "sets": 4, "reps": 8, "cat": "back",
             "options": ["Barbell Rows", "Dumbbell Rows"]},
            {"sort": 3, "sets": 3, "reps": 10, "cat": "back",
             "options": ["Pull Ups", "Lat Pulldowns"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "back",
             "options": ["Seated Cable Row", "T-Bar Row"]},
        ],
    },
    "Shoulder Day": {
        "description": "Shoulders-focused bro split",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 8, "cat": "shoulders",
             "options": ["Overhead Press", "Dumbbell Shoulder Press"]},
            {"sort": 2, "sets": 3, "reps": 12, "cat": "shoulders",
             "options": ["Lateral Raises", "Cable Lateral Raises"]},
            {"sort": 3, "sets": 3, "reps": 15, "cat": "shoulders",
             "options": ["Face Pulls", "Reverse Flyes"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "shoulders",
             "options": ["Arnold Press", "Front Raises"]},
        ],
    },
    "Arms Day": {
        "description": "Biceps and triceps",
        "exercises": [
            {"sort": 1, "sets": 4, "reps": 10, "cat": "arms",
             "options": ["Barbell Curls", "EZ Bar Curls"]},
            {"sort": 2, "sets": 3, "reps": 10, "cat": "arms",
             "options": ["Tricep Pushdowns", "Overhead Tricep Extension"]},
            {"sort": 3, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Hammer Curls", "Incline Dumbbell Curls"]},
            {"sort": 4, "sets": 3, "reps": 12, "cat": "arms",
             "options": ["Skull Crushers", "Close Grip Bench Press"]},
        ],
    },
}

PRESET_PLANS = [
    {
        "name": "Push/Pull/Legs (6-Day)",
        "description": "Classic PPL split — train each muscle group twice per week",
        "duration_type": "repeating",
        "days": {0: "Push Day", 1: "Pull Day", 2: "Leg Day",
                 3: "Push Day", 4: "Pull Day", 5: "Leg Day"},
    },
    {
        "name": "Upper/Lower (4-Day)",
        "description": "Alternate upper and lower body with rest days",
        "duration_type": "repeating",
        "days": {0: "Upper Body", 1: "Lower Body",
                 3: "Upper Body", 4: "Lower Body"},
    },
    {
        "name": "Full Body (3-Day)",
        "description": "Three varied full body workouts per week",
        "duration_type": "repeating",
        "days": {0: "Full Body A", 2: "Full Body B", 4: "Full Body C"},
    },
    {
        "name": "Bro Split (5-Day)",
        "description": "Dedicate each day to one muscle group",
        "duration_type": "repeating",
        "days": {0: "Chest Day", 1: "Back Day", 2: "Shoulder Day",
                 3: "Arms Day", 4: "Leg Day"},
    },
]


def seed_presets():
    """Seed preset routines and plans if not already present."""
    db = SessionLocal()
    try:
        existing = db.query(WorkoutRoutine).filter(WorkoutRoutine.is_preset == 1).count()
        if existing > 0:
            logger.info(f"Preset routines already exist ({existing}), skipping seed")
            return

        logger.info("Seeding preset workout routines and plans...")

        routine_map = {}
        for name, data in PRESET_ROUTINES.items():
            routine = WorkoutRoutine(name=name, description=data["description"], is_preset=1)
            db.add(routine)
            db.flush()
            routine_map[name] = routine.id

            for ex_data in data["exercises"]:
                exercise = WorkoutRoutineExercise(
                    routine_id=routine.id,
                    sort_order=ex_data["sort"],
                    target_sets=ex_data["sets"],
                    target_reps=ex_data["reps"],
                    exercise_category=ex_data["cat"],
                )
                db.add(exercise)
                db.flush()

                for i, opt_name in enumerate(ex_data["options"]):
                    db.add(WorkoutRoutineExerciseOption(
                        routine_exercise_id=exercise.id,
                        exercise_name=opt_name,
                        is_default=1 if i == 0 else 0,
                        sort_order=i,
                    ))

        for plan_data in PRESET_PLANS:
            plan = WorkoutPlan(
                name=plan_data["name"],
                description=plan_data["description"],
                duration_type=plan_data["duration_type"],
                is_preset=1,
            )
            db.add(plan)
            db.flush()

            for dow, routine_name in plan_data["days"].items():
                db.add(WorkoutPlanDay(
                    plan_id=plan.id,
                    day_of_week=dow,
                    routine_id=routine_map[routine_name],
                ))

        db.commit()
        logger.info(f"Seeded {len(PRESET_ROUTINES)} routines and {len(PRESET_PLANS)} plans")
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to seed presets: {e}")
    finally:
        db.close()

# ============ Pydantic Schemas ============

class ExerciseOptionCreate(BaseModel):
    exercise_name: str = Field(..., min_length=1)
    is_default: bool = False
    sort_order: int = 0

class RoutineExerciseCreate(BaseModel):
    sort_order: int = 0
    target_sets: int = Field(3, ge=1, le=20)
    target_reps: Optional[int] = Field(None, ge=1, le=100)
    exercise_category: Optional[str] = None
    options: List[ExerciseOptionCreate] = []

class RoutineCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    exercises: List[RoutineExerciseCreate] = []

class PlanDayCreate(BaseModel):
    day_of_week: int = Field(..., ge=0, le=6)  # 0=Mon..6=Sun
    routine_id: Optional[int] = None  # None = rest day

class PlanCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    duration_type: str = Field("repeating", pattern="^(repeating|fixed)$")
    duration_weeks: Optional[int] = Field(None, ge=1, le=52)
    days: List[PlanDayCreate] = []

# ============ Response Schemas ============

class ExerciseOptionResponse(BaseModel):
    id: int
    exercise_name: str
    is_default: bool
    sort_order: int
    class Config:
        from_attributes = True

class RoutineExerciseResponse(BaseModel):
    id: int
    sort_order: int
    target_sets: int
    target_reps: Optional[int]
    exercise_category: Optional[str]
    options: List[ExerciseOptionResponse]
    class Config:
        from_attributes = True

class RoutineResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    is_preset: bool
    exercises: List[RoutineExerciseResponse]
    created_at: datetime
    class Config:
        from_attributes = True

class PlanDayResponse(BaseModel):
    id: int
    day_of_week: int
    routine_id: Optional[int]
    routine: Optional[RoutineResponse] = None
    class Config:
        from_attributes = True

class PlanResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    duration_type: str
    duration_weeks: Optional[int]
    start_date: Optional[date]
    is_active: bool
    is_preset: bool
    days: List[PlanDayResponse]
    created_at: datetime
    class Config:
        from_attributes = True


# ============ Routine Endpoints ============

def _load_routine(routine_id: int, db: Session) -> WorkoutRoutine:
    routine = db.query(WorkoutRoutine).options(
        subqueryload(WorkoutRoutine.exercises).subqueryload(WorkoutRoutineExercise.options)
    ).filter(WorkoutRoutine.id == routine_id).first()
    if not routine:
        raise HTTPException(status_code=404, detail="Routine not found")
    return routine


@router.get("/routines", response_model=List[RoutineResponse])
def list_routines(db: Session = Depends(get_db)):
    """List all routines (presets + custom)"""
    return db.query(WorkoutRoutine).options(
        subqueryload(WorkoutRoutine.exercises).subqueryload(WorkoutRoutineExercise.options)
    ).order_by(WorkoutRoutine.is_preset.desc(), WorkoutRoutine.name).all()


@router.get("/routines/{routine_id}", response_model=RoutineResponse)
def get_routine(routine_id: int, db: Session = Depends(get_db)):
    return _load_routine(routine_id, db)


@router.post("/routines", response_model=RoutineResponse)
def create_routine(data: RoutineCreate, db: Session = Depends(get_db)):
    routine = WorkoutRoutine(name=data.name, description=data.description)
    db.add(routine)
    db.flush()

    for ex_data in data.exercises:
        exercise = WorkoutRoutineExercise(
            routine_id=routine.id,
            sort_order=ex_data.sort_order,
            target_sets=ex_data.target_sets,
            target_reps=ex_data.target_reps,
            exercise_category=ex_data.exercise_category,
        )
        db.add(exercise)
        db.flush()

        has_default = False
        for i, opt in enumerate(ex_data.options):
            is_def = opt.is_default or (i == 0 and not has_default)
            if is_def:
                has_default = True
            db.add(WorkoutRoutineExerciseOption(
                routine_exercise_id=exercise.id,
                exercise_name=opt.exercise_name,
                is_default=1 if is_def else 0,
                sort_order=opt.sort_order or i,
            ))

    db.commit()
    return _load_routine(routine.id, db)


@router.put("/routines/{routine_id}", response_model=RoutineResponse)
def update_routine(routine_id: int, data: RoutineCreate, db: Session = Depends(get_db)):
    routine = _load_routine(routine_id, db)

    routine.name = data.name
    routine.description = data.description

    # Delete old exercises (cascades to options)
    for ex in routine.exercises:
        db.delete(ex)
    db.flush()

    for ex_data in data.exercises:
        exercise = WorkoutRoutineExercise(
            routine_id=routine.id,
            sort_order=ex_data.sort_order,
            target_sets=ex_data.target_sets,
            target_reps=ex_data.target_reps,
            exercise_category=ex_data.exercise_category,
        )
        db.add(exercise)
        db.flush()

        has_default = False
        for i, opt in enumerate(ex_data.options):
            is_def = opt.is_default or (i == 0 and not has_default)
            if is_def:
                has_default = True
            db.add(WorkoutRoutineExerciseOption(
                routine_exercise_id=exercise.id,
                exercise_name=opt.exercise_name,
                is_default=1 if is_def else 0,
                sort_order=opt.sort_order or i,
            ))

    db.commit()
    return _load_routine(routine.id, db)


@router.delete("/routines/{routine_id}")
def delete_routine(routine_id: int, db: Session = Depends(get_db)):
    routine = _load_routine(routine_id, db)
    if routine.is_preset:
        raise HTTPException(status_code=400, detail="Cannot delete preset routines")
    db.delete(routine)
    db.commit()
    return {"message": "Routine deleted"}


# ============ Plan Endpoints ============

def _load_plan(plan_id: int, db: Session) -> WorkoutPlan:
    plan = db.query(WorkoutPlan).options(
        subqueryload(WorkoutPlan.days).joinedload(WorkoutPlanDay.routine).subqueryload(
            WorkoutRoutine.exercises
        ).subqueryload(WorkoutRoutineExercise.options)
    ).filter(WorkoutPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    return plan


@router.get("/plans", response_model=List[PlanResponse])
def list_plans(db: Session = Depends(get_db)):
    """List all plans (presets + custom)"""
    return db.query(WorkoutPlan).options(
        subqueryload(WorkoutPlan.days).joinedload(WorkoutPlanDay.routine).subqueryload(
            WorkoutRoutine.exercises
        ).subqueryload(WorkoutRoutineExercise.options)
    ).order_by(WorkoutPlan.is_active.desc(), WorkoutPlan.is_preset.desc(), WorkoutPlan.name).all()


@router.get("/plans/active/today")
def get_today_plan(db: Session = Depends(get_db)):
    """Get today's routine from the active plan"""
    plan = db.query(WorkoutPlan).options(
        subqueryload(WorkoutPlan.days).joinedload(WorkoutPlanDay.routine).subqueryload(
            WorkoutRoutine.exercises
        ).subqueryload(WorkoutRoutineExercise.options)
    ).filter(WorkoutPlan.is_active == 1).first()

    if not plan:
        return {"has_plan": False}

    today_dow = date.today().weekday()  # 0=Monday

    # Check if plan has expired (fixed duration)
    current_week = None
    if plan.start_date:
        days_elapsed = (date.today() - plan.start_date).days
        current_week = (days_elapsed // 7) + 1
        if plan.duration_type == "fixed" and plan.duration_weeks and current_week > plan.duration_weeks:
            return {"has_plan": False, "expired": True, "plan_name": plan.name}

    # Find today's routine
    today_day = None
    for day in plan.days:
        if day.day_of_week == today_dow:
            today_day = day
            break

    if not today_day or not today_day.routine:
        return {
            "has_plan": True,
            "plan_name": plan.name,
            "plan_id": plan.id,
            "is_rest_day": True,
            "current_week": current_week,
        }

    routine = today_day.routine
    exercises = []
    for ex in routine.exercises:
        options = [{"exercise_name": o.exercise_name, "is_default": bool(o.is_default)} for o in ex.options]
        default_name = next((o.exercise_name for o in ex.options if o.is_default), ex.options[0].exercise_name if ex.options else "Unknown")
        exercises.append({
            "id": ex.id,
            "sort_order": ex.sort_order,
            "target_sets": ex.target_sets,
            "target_reps": ex.target_reps,
            "exercise_category": ex.exercise_category,
            "default_exercise": default_name,
            "options": options,
        })

    return {
        "has_plan": True,
        "plan_name": plan.name,
        "plan_id": plan.id,
        "routine_name": routine.name,
        "routine_id": routine.id,
        "is_rest_day": False,
        "current_week": current_week,
        "exercises": exercises,
    }


@router.get("/plans/{plan_id}", response_model=PlanResponse)
def get_plan(plan_id: int, db: Session = Depends(get_db)):
    return _load_plan(plan_id, db)


@router.post("/plans", response_model=PlanResponse)
def create_plan(data: PlanCreate, db: Session = Depends(get_db)):
    plan = WorkoutPlan(
        name=data.name,
        description=data.description,
        duration_type=data.duration_type,
        duration_weeks=data.duration_weeks if data.duration_type == "fixed" else None,
    )
    db.add(plan)
    db.flush()

    for day_data in data.days:
        db.add(WorkoutPlanDay(
            plan_id=plan.id,
            day_of_week=day_data.day_of_week,
            routine_id=day_data.routine_id,
        ))

    db.commit()
    return _load_plan(plan.id, db)


@router.put("/plans/{plan_id}", response_model=PlanResponse)
def update_plan(plan_id: int, data: PlanCreate, db: Session = Depends(get_db)):
    plan = _load_plan(plan_id, db)

    plan.name = data.name
    plan.description = data.description
    plan.duration_type = data.duration_type
    plan.duration_weeks = data.duration_weeks if data.duration_type == "fixed" else None

    # Delete old days
    for day in plan.days:
        db.delete(day)
    db.flush()

    for day_data in data.days:
        db.add(WorkoutPlanDay(
            plan_id=plan.id,
            day_of_week=day_data.day_of_week,
            routine_id=day_data.routine_id,
        ))

    db.commit()
    return _load_plan(plan.id, db)


@router.delete("/plans/{plan_id}")
def delete_plan(plan_id: int, db: Session = Depends(get_db)):
    plan = _load_plan(plan_id, db)
    if plan.is_preset:
        raise HTTPException(status_code=400, detail="Cannot delete preset plans")
    db.delete(plan)
    db.commit()
    return {"message": "Plan deleted"}


@router.post("/plans/{plan_id}/activate")
def activate_plan(plan_id: int, db: Session = Depends(get_db)):
    """Activate a plan (deactivates all others)"""
    plan = db.query(WorkoutPlan).filter(WorkoutPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    # Deactivate all plans
    db.query(WorkoutPlan).update({WorkoutPlan.is_active: 0})

    # Activate this one + set start date
    plan.is_active = 1
    if not plan.start_date:
        plan.start_date = date.today()

    db.commit()
    return {"message": f"Plan '{plan.name}' activated", "plan_id": plan.id}


@router.post("/plans/{plan_id}/deactivate")
def deactivate_plan(plan_id: int, db: Session = Depends(get_db)):
    """Deactivate a plan"""
    plan = db.query(WorkoutPlan).filter(WorkoutPlan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    plan.is_active = 0
    db.commit()
    return {"message": f"Plan '{plan.name}' deactivated"}
