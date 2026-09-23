from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from app.tickets.models import IssueCategory, TicketStatus, TicketPriority, MediaType

class TicketCreateSchema(BaseModel):
    facility_id: str = Field(..., example="FAC-WARD12-TLT-001")
    reporter_id: int = Field(..., example=1)
    issue_categories: List[IssueCategory] = Field(..., min_length=1)
    description: Optional[str] = None
    reporter_latitude: float = Field(..., example=12.9716)
    reporter_longitude: float = Field(..., example=77.5946)
    media_url: Optional[str] = None
    is_live_camera: bool = Field(True, description="Must be captured directly from live camera")

class TicketStatusUpdateSchema(BaseModel):
    status: TicketStatus
    worker_notes: Optional[str] = None
    current_latitude: Optional[float] = None
    current_longitude: Optional[float] = None
    after_media_url: Optional[str] = None
    face_image_base64: Optional[str] = None
    rejection_reason: Optional[str] = None

class TicketResponseSchema(BaseModel):
    id: int
    ticket_id: str
    facility_id: int
    facility_custom_id: Optional[str] = None
    facility_name: Optional[str] = None
    reporter_id: int
    assigned_worker_id: Optional[int] = None
    assigned_worker_name: Optional[str] = None
    issue_categories: List[str]
    description: Optional[str]
    status: TicketStatus
    priority: TicketPriority
    report_count: int
    reporter_latitude: float
    reporter_longitude: float
    assigned_at: Optional[datetime]
    expected_sla_deadline: Optional[datetime]
    face_match_score: Optional[float]
    face_verified: bool
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
