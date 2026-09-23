from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone, timedelta
import json
import uuid

from app.database import get_db
from app.tickets.models import Ticket, TicketStatus, TicketPriority, TicketMedia, TicketStatusHistory, MediaType
from app.tickets.schemas import TicketCreateSchema, TicketStatusUpdateSchema, TicketResponseSchema
from app.facilities.models import Facility, FacilityStatus
from app.workers.models import LocalBodyWorker
from app.users.models import User
from app.config import settings

router = APIRouter(prefix="/tickets", tags=["Tickets"])

@router.post("", response_model=TicketResponseSchema, status_code=status.HTTP_201_CREATED)
def raise_ticket(data: TicketCreateSchema, db: Session = Depends(get_db)):
    if not data.is_live_camera:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Camera-only uploads are permitted. Gallery uploads are prohibited.")
        
    facility = db.query(Facility).filter(
        (Facility.facility_id == data.facility_id) | (Facility.id == int(data.facility_id) if data.facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    # Phase 7 Duplicate Detection: Same Facility, Same Issue, within DUPLICATE_TIME_WINDOW_HOURS
    time_window = datetime.now(timezone.utc) - timedelta(hours=settings.DUPLICATE_TIME_WINDOW_HOURS)
    existing_tickets = db.query(Ticket).filter(
        Ticket.facility_id == facility.id,
        Ticket.status.in_([TicketStatus.TICKET_CREATED, TicketStatus.ASSIGNED, TicketStatus.REACHED, TicketStatus.REPAIRING]),
        Ticket.created_at >= time_window
    ).all()
    
    incoming_issues = set([c.value if hasattr(c, "value") else str(c) for c in data.issue_categories])
    duplicate_ticket = None
    
    for t in existing_tickets:
        try:
            t_issues = set(json.loads(t.issue_categories))
            if incoming_issues.intersection(t_issues):
                duplicate_ticket = t
                break
        except Exception:
            continue
            
    if duplicate_ticket:
        # Merge ticket: increase report count
        duplicate_ticket.report_count += 1
        db.commit()
        db.refresh(duplicate_ticket)
        return _format_ticket_response(duplicate_ticket, facility)
        
    # Create new ticket
    ticket_custom_id = f"TCK-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:5].upper()}"
    new_ticket = Ticket(
        ticket_id=ticket_custom_id,
        facility_id=facility.id,
        reporter_id=data.reporter_id,
        issue_categories=json.dumps([c.value if hasattr(c, "value") else str(c) for c in data.issue_categories]),
        description=data.description,
        status=TicketStatus.TICKET_CREATED,
        priority=TicketPriority.HIGH if "NO_WATER" in incoming_issues else TicketPriority.MEDIUM,
        reporter_latitude=data.reporter_latitude,
        reporter_longitude=data.reporter_longitude,
        report_count=1
    )
    db.add(new_ticket)
    db.commit()
    db.refresh(new_ticket)
    
    # Store initial media proof if supplied
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
        db.commit()
        
    return _format_ticket_response(new_ticket, facility)

@router.get("", response_model=List[TicketResponseSchema])
def list_tickets(
    status: Optional[TicketStatus] = None,
    facility_id: Optional[int] = None,
    assigned_worker_id: Optional[int] = None,
    reporter_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Ticket)
    if status:
        query = query.filter(Ticket.status == status)
    if facility_id:
        query = query.filter(Ticket.facility_id == facility_id)
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
