from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.sla.models import SLALog, WorkerPenalty
from app.sla.schemas import SLALogResponse, WorkerPenaltyResponse

router = APIRouter(prefix="/sla", tags=["SLA & Escalations"])

@router.get("/logs", response_model=List[SLALogResponse])
def list_sla_logs(ticket_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(SLALog)
    if ticket_id:
        query = query.filter(SLALog.ticket_id == ticket_id)
    return query.order_by(SLALog.triggered_at.desc()).all()

@router.get("/penalties", response_model=List[WorkerPenaltyResponse])
def list_penalties(worker_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(WorkerPenalty)
    if worker_id:
        query = query.filter(WorkerPenalty.worker_id == worker_id)
    return query.order_by(WorkerPenalty.created_at.desc()).all()
