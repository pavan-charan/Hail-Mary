from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

from app.database import get_db
from app.history.models import FacilityHistory, FacilityAction

router = APIRouter(prefix="/history", tags=["Audit History"])

class HistoryResponseSchema(BaseModel):
    id: int
    facility_id: int
    action: FacilityAction
    performed_by_user_id: Optional[int]
    previous_state: Optional[str]
    new_state: Optional[str]
    reason: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

@router.get("/facility/{facility_id}", response_model=List[HistoryResponseSchema])
def get_facility_audit_history(facility_id: int, db: Session = Depends(get_db)):
    return db.query(FacilityHistory).filter(FacilityHistory.facility_id == facility_id).order_by(FacilityHistory.created_at.desc()).all()
