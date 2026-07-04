from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import WaterLog
from datetime import date, datetime
from pydantic import BaseModel, Field
from typing import List

router = APIRouter()

class WaterLogCreate(BaseModel):
    amount_ml: int = Field(..., gt=0, le=5000, description="Water amount in ml (1-5000)")

class WaterLogResponse(BaseModel):
    id: int
    date: date
    amount_ml: int
    logged_at: datetime

    class Config:
        from_attributes = True

class WaterEntryBrief(BaseModel):
    id: int
    amount_ml: int
    created_at: str

class WaterTodayResponse(BaseModel):
    date: date
    total_ml: int
    goal_ml: int
    percentage: float
    remaining_ml: int
    entries: List[WaterEntryBrief]

@router.post("/", response_model=WaterLogResponse)
def log_water(water: WaterLogCreate, db: Session = Depends(get_db)):
    """Log water intake (capped at 10,000ml total per day)"""
    today = date.today()
    
    # Check daily total won't exceed reasonable cap
    current_total = sum(
        log.amount_ml for log in db.query(WaterLog).filter(WaterLog.date == today).all()
    )
    if current_total + water.amount_ml > 10000:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=400,
            detail=f"Daily water cap exceeded. Current: {current_total}ml, max: 10,000ml."
        )
    
    log = WaterLog(
        date=today,
        amount_ml=water.amount_ml
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    
    return log

@router.get("/today")
def get_today_water(db: Session = Depends(get_db)):
    """Get today's total water intake"""
    today = date.today()
    logs = db.query(WaterLog).filter(WaterLog.date == today).all()
    
    total_ml = sum(log.amount_ml for log in logs)
    
    # Get goal (default 2000ml if not set)
    from models import Goals
    goals = db.query(Goals).first()
    goal_ml = goals.water_ml if goals else 2000
    
    return {
        "date": today,
        "total_ml": total_ml,
        "goal_ml": goal_ml,
        "percentage": round((total_ml / goal_ml) * 100, 1) if goal_ml else 0,
        "remaining_ml": max(0, goal_ml - total_ml),
        "entries": [{"id": log.id, "amount_ml": log.amount_ml, "created_at": log.logged_at.isoformat()} for log in logs]
    }

@router.get("/history")
def get_water_history(days: int = 7, limit: int = 100, offset: int = 0, db: Session = Depends(get_db)):
    """Get water intake history with pagination"""
    from datetime import timedelta
    
    start_date = date.today() - timedelta(days=days)
    logs = db.query(WaterLog).filter(
        WaterLog.date >= start_date
    ).order_by(WaterLog.date.desc()).offset(offset).limit(limit).all()
    
    # Group by date
    daily_totals = {}
    for log in logs:
        date_str = str(log.date)
        if date_str not in daily_totals:
            daily_totals[date_str] = 0
        daily_totals[date_str] += log.amount_ml
    
    return {
        "days": days,
        "daily_totals": daily_totals
    }

@router.delete("/today/reset")
def reset_today_water(db: Session = Depends(get_db)):
    """Delete all water logs for today"""
    today = date.today()
    deleted = db.query(WaterLog).filter(WaterLog.date == today).delete()
    db.commit()
    return {"message": f"Deleted {deleted} water entries"}

@router.delete("/{log_id}")
def delete_water_log(log_id: int, db: Session = Depends(get_db)):
    """Delete a water log entry"""
    from fastapi import HTTPException
    log = db.query(WaterLog).filter(WaterLog.id == log_id).first()
    
    if not log:
        raise HTTPException(status_code=404, detail="Water log not found")
    
    db.delete(log)
    db.commit()
    
    return {"message": "Water log deleted"}
