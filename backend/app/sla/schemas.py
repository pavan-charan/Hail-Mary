from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.sla.models import SLAStep

class SLALogResponse(BaseModel):
    id: int
    ticket_id: int
    step: SLAStep
    triggered_at: datetime
    status_response: Optional[str]
    details: Optional[str]

    class Config:
        from_attributes = True

class WorkerPenaltyResponse(BaseModel):
    id: int
    worker_id: int
    ticket_id: int
    reason: str
    penalty_points: int
    created_at: datetime

    class Config:
        from_attributes = True
