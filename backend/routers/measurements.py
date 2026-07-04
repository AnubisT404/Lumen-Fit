from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import BodyMeasurement
from datetime import date, datetime, timedelta
from pydantic import BaseModel, Field
from typing import Optional, List

router = APIRouter()

class MeasurementCreate(BaseModel):
    weight_kg: float = Field(..., gt=1, lt=500)
    body_fat_percentage: Optional[float] = Field(None, ge=1, le=70)
    chest_cm: Optional[float] = Field(None, gt=0, lt=300)
    waist_cm: Optional[float] = Field(None, gt=0, lt=300)
    hips_cm: Optional[float] = Field(None, gt=0, lt=300)
    notes: Optional[str] = Field(None, max_length=500)

class MeasurementResponse(BaseModel):
    id: int
    date: date
    weight_kg: float
    body_fat_percentage: Optional[float]
    chest_cm: Optional[float]
    waist_cm: Optional[float]
    hips_cm: Optional[float]
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

@router.post("/", response_model=MeasurementResponse)
def log_measurement(measurement: MeasurementCreate, db: Session = Depends(get_db)):
    """Log body measurements for today (upsert — one entry per day)"""
    from sqlalchemy import text
    
    today = date.today()
    data = measurement.model_dump(exclude_unset=True)
    
    # Atomic upsert: avoids read-then-write race condition
    existing = db.query(BodyMeasurement).filter(BodyMeasurement.date == today).with_for_update().first()
    
    if existing:
        for key, value in data.items():
            setattr(existing, key, value)
        db.commit()
        db.refresh(existing)
        return existing
    
    new_measurement = BodyMeasurement(date=today, **measurement.model_dump())
    db.add(new_measurement)
    db.commit()
    db.refresh(new_measurement)
    
    return new_measurement

@router.get("/", response_model=List[MeasurementResponse])
def get_measurements(limit: int = 30, offset: int = 0, db: Session = Depends(get_db)):
    """Get measurement history with pagination"""
    measurements = db.query(BodyMeasurement).order_by(
        BodyMeasurement.date.desc()
    ).offset(offset).limit(limit).all()
    
    return measurements

@router.get("/latest", response_model=MeasurementResponse)
def get_latest_measurement(db: Session = Depends(get_db)):
    """Get most recent measurement"""
    measurement = db.query(BodyMeasurement).order_by(
        BodyMeasurement.date.desc()
    ).first()
    
    if not measurement:
        raise HTTPException(status_code=404, detail="No measurements found")
    
    return measurement

@router.get("/stats")
def get_measurement_stats(db: Session = Depends(get_db)):
    """Get weight change statistics"""
    measurements = db.query(BodyMeasurement).order_by(
        BodyMeasurement.date.asc()
    ).all()
    
    if not measurements:
        return {
            "total_measurements": 0,
            "current_weight": None,
            "starting_weight": None,
            "weight_change": None,
            "trend": None
        }
    
    starting_weight = measurements[0].weight_kg
    current_weight = measurements[-1].weight_kg
    weight_change = current_weight - starting_weight
    
    # Calculate trend (last 7 days)
    seven_days_ago = date.today() - timedelta(days=7)
    recent = [m for m in measurements if m.date >= seven_days_ago]
    
    if len(recent) >= 2:
        trend_change = recent[-1].weight_kg - recent[0].weight_kg
        if trend_change < -0.5:
            trend = "decreasing"
        elif trend_change > 0.5:
            trend = "increasing"
        else:
            trend = "stable"
    else:
        trend = "insufficient_data"
    
    return {
        "total_measurements": len(measurements),
        "current_weight": current_weight,
        "starting_weight": starting_weight,
        "weight_change": round(weight_change, 2),
        "weight_change_percentage": round((weight_change / starting_weight) * 100, 2) if starting_weight else 0,
        "trend": trend,
        "first_measurement_date": measurements[0].date,
        "last_measurement_date": measurements[-1].date
    }

@router.delete("/{measurement_id}")
def delete_measurement(measurement_id: int, db: Session = Depends(get_db)):
    """Delete a measurement"""
    measurement = db.query(BodyMeasurement).filter(
        BodyMeasurement.id == measurement_id
    ).first()
    
    if not measurement:
        raise HTTPException(status_code=404, detail="Measurement not found")
    
    db.delete(measurement)
    db.commit()
    
    return {"message": "Measurement deleted successfully"}
