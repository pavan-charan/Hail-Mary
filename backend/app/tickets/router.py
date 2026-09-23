from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone, timedelta
import json
import uuid

from app.database import get_db
from app.tickets.models import Ticket, TicketStatus, TicketPriority, TicketMedia, TicketStatusHistory, MediaType, IssueCategory
from app.tickets.schemas import TicketCreateSchema, TicketStatusUpdateSchema, TicketResponseSchema
from app.facilities.models import Facility
from app.workers.models import LocalBodyWorker
from app.config import settings

router = APIRouter(prefix="/tickets", tags=["Tickets"])

@router.post("", response_model=TicketResponseSchema, status_code=status.HTTP_201_CREATED)
def raise_ticket(data: TicketCreateSchema, db: Session = Depends(get_db)):
    # Validation Rule: Camera-only uploads. Gallery uploads are prohibited.
    if not data.is_live_camera:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Gallery uploads are strictly prohibited. You must capture live proof directly from your camera."
        )

    # Validate issue categories
    if not data.issue_categories or len(data.issue_categories) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one issue category must be selected."
        )

    facility = db.query(Facility).filter(
        (Facility.facility_id == data.facility_id) | (Facility.id == int(data.facility_id) if data.facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found in civic registry")

    # Generate unique Ticket ID: TCK-<YYYYMMDD>-<5_HEX>
    date_str = datetime.now().strftime("%Y%m%d")
    unique_suffix = uuid.uuid4().hex[:5].upper()
    generated_ticket_id = f"TCK-{date_str}-{unique_suffix}"

    categories_list = [c.value if hasattr(c, "value") else str(c) for c in data.issue_categories]
    
    # Priority calculation: High priority if No Water or Drinking Water Unavailable
    priority = TicketPriority.HIGH if ("NO_WATER" in categories_list or "DRINKING_WATER_UNAVAILABLE" in categories_list) else TicketPriority.MEDIUM

    new_ticket = Ticket(
        ticket_id=generated_ticket_id,
        facility_id=facility.id,
        reporter_id=data.reporter_id,
        issue_categories=json.dumps(categories_list),
        description=data.description,
        status=TicketStatus.TICKET_CREATED,
        priority=priority,
        reporter_latitude=data.reporter_latitude,
        reporter_longitude=data.reporter_longitude,
        report_count=1,
        face_verified=False
    )
    db.add(new_ticket)
    db.commit()
    db.refresh(new_ticket)

    # Attach live camera media proof
    if data.media_url:
        media_rec = TicketMedia(
            ticket_id=new_ticket.id,
            media_type=MediaType.BEFORE_PHOTO,
            file_url=data.media_url,
            captured_latitude=data.reporter_latitude,
            captured_longitude=data.reporter_longitude,
            is_live_camera=True
        )
        db.add(media_rec)

    # Record Initial Status History
    status_log = TicketStatusHistory(
        ticket_id=new_ticket.id,
        from_status=None,
        to_status=TicketStatus.TICKET_CREATED.value,
        changed_by_user_id=data.reporter_id,
        notes=f"Ticket created with {len(categories_list)} reported issue(s)"
    )
    db.add(status_log)
    db.commit()
    db.refresh(new_ticket)

    return _format_ticket_response(new_ticket, facility, db)

@router.get("", response_model=List[TicketResponseSchema])
def list_tickets(
    status: Optional[TicketStatus] = None,
    facility_id: Optional[str] = None,
    assigned_worker_id: Optional[int] = None,
    reporter_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Ticket)
    if status:
        query = query.filter(Ticket.status == status)
    if facility_id:
        facility = db.query(Facility).filter(
            (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
        ).first()
        if facility:
            query = query.filter(Ticket.facility_id == facility.id)
    if assigned_worker_id:
        query = query.filter(Ticket.assigned_worker_id == assigned_worker_id)
    if reporter_id:
        query = query.filter(Ticket.reporter_id == reporter_id)

    tickets = query.order_by(Ticket.created_at.desc()).all()
    results = []
    for t in tickets:
        facility = db.query(Facility).filter(Facility.id == t.facility_id).first()
        results.append(_format_ticket_response(t, facility, db))
    return results

@router.get("/{ticket_id}", response_model=TicketResponseSchema)
def get_ticket(ticket_id: str, db: Session = Depends(get_db)):
    ticket = db.query(Ticket).filter(
        (Ticket.ticket_id == ticket_id) | (Ticket.id == int(ticket_id) if ticket_id.isdigit() else False)
    ).first()
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")
    facility = db.query(Facility).filter(Facility.id == ticket.facility_id).first()
    return _format_ticket_response(ticket, facility, db)

def _format_ticket_response(ticket: Ticket, facility: Optional[Facility] = None, db: Optional[Session] = None) -> TicketResponseSchema:
    try:
        categories = json.loads(ticket.issue_categories)
    except Exception:
        categories = [ticket.issue_categories]

    worker_name = None
    if ticket.assigned_worker_id and db:
        worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == ticket.assigned_worker_id).first()
        if worker and worker.user:
            worker_name = worker.user.full_name

    return TicketResponseSchema(
        id=ticket.id,
        ticket_id=ticket.ticket_id,
        facility_id=ticket.facility_id,
        facility_custom_id=facility.facility_id if facility else None,
        facility_name=facility.name if facility else None,
        reporter_id=ticket.reporter_id,
        assigned_worker_id=ticket.assigned_worker_id,
        assigned_worker_name=worker_name,
        issue_categories=categories,
        description=ticket.description,
        status=ticket.status,
        priority=ticket.priority,
        report_count=ticket.report_count,
        reporter_latitude=ticket.reporter_latitude,
        reporter_longitude=ticket.reporter_longitude,
        assigned_at=ticket.assigned_at,
        expected_sla_deadline=ticket.expected_sla_deadline,
        face_match_score=ticket.face_match_score,
        face_verified=ticket.face_verified,
        rejection_reason=ticket.rejection_reason,
        created_at=ticket.created_at,
        updated_at=ticket.updated_at
    )
