from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid

from app.database import get_db
from app.workers.models import LocalBodyWorker
from app.sla.models import WorkerPenalty
from app.workers.schemas import WorkerRegisterSchema, WorkerEnrollFaceSchema, WorkerResponseSchema
from app.users.models import User, UserRole
from app.face_verification.service import extract_face_embedding
from app.tickets.schemas import TicketResponseSchema
from app.tickets.models import TicketStatus

router = APIRouter(prefix="/workers", tags=["Workers"])

@router.post("/register", response_model=WorkerResponseSchema, status_code=status.HTTP_201_CREATED)
def register_worker(data: WorkerRegisterSchema, db: Session = Depends(get_db)):
    clean_phone = data.phone.strip()
    if not clean_phone.startswith("+"):
        clean_phone = f"+91{clean_phone}" if len(clean_phone) == 10 else f"+{clean_phone}"
        
    # Check if phone already registered
    existing_user = db.query(User).filter(User.phone == clean_phone).first()
    if not existing_user:
        existing_user = User(
            phone=clean_phone,
            full_name=data.full_name,
            role=UserRole.WORKER,
            is_active=True
        )
        db.add(existing_user)
        db.commit()
        db.refresh(existing_user)
    else:
        existing_user.role = UserRole.WORKER
        existing_user.full_name = data.full_name
        existing_user.is_active = True
        
    existing_worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.user_id == existing_user.id).first()
    if existing_worker:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Worker already exists for this user")
        
    worker_code = f"WRK-{data.ward.upper().replace(' ', '')}-{uuid.uuid4().hex[:4].upper()}"
    worker = LocalBodyWorker(
        user_id=existing_user.id,
        worker_code=worker_code,
        ward=data.ward,
        face_enrolled=False
    )
    db.add(worker)
    db.commit()
    db.refresh(worker)
    
    return WorkerResponseSchema(
        id=worker.id,
        user_id=worker.user_id,
        worker_code=worker.worker_code,
        ward=worker.ward,
        full_name=existing_user.full_name,
        phone=existing_user.phone,
        face_enrolled=worker.face_enrolled,
        active_workload_count=worker.active_workload_count,
        total_resolved_count=worker.total_resolved_count,
        penalty_count=worker.penalty_count
    )

@router.delete("/{worker_id}")
def delete_worker(worker_id: int, db: Session = Depends(get_db)):
    from app.tickets.models import Ticket

    worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == worker_id).first()
    if not worker:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Worker not found")
    
    # Unassign any active tickets assigned to this worker so they return to open pool
    active_tickets = db.query(Ticket).filter(
        Ticket.assigned_worker_id == worker.id,
        Ticket.status.in_([TicketStatus.ASSIGNED, TicketStatus.REACHED, TicketStatus.REPAIRING])
    ).all()
    for t in active_tickets:
        t.assigned_worker_id = None
        t.status = TicketStatus.TICKET_CREATED
    
    # Delete associated penalties if any
    db.query(WorkerPenalty).filter(WorkerPenalty.worker_id == worker.id).delete()

    user = worker.user
    db.delete(worker)
    if user:
        user.role = UserRole.CITIZEN
    db.commit()
    
    return {"success": True, "message": "Worker profile successfully removed."}


@router.post("/enroll-face")
def enroll_face(data: WorkerEnrollFaceSchema, db: Session = Depends(get_db)):
    worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == data.worker_id).first()
    if not worker:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Worker not found")
        
    embedding = extract_face_embedding(data.face_image_base64)
    if not embedding:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No face detected in enrollment image")
        
    worker.face_embedding = embedding
    worker.face_enrolled = True
    db.commit()
    return {"success": True, "message": "Face enrollment successful. Worker account activated."}

@router.get("", response_model=List[WorkerResponseSchema])
def list_workers(ward: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(LocalBodyWorker)
    if ward:
        query = query.filter(LocalBodyWorker.ward == ward)
    workers = query.all()
    
    results = []
    for w in workers:
        results.append(WorkerResponseSchema(
            id=w.id,
            user_id=w.user_id,
            worker_code=w.worker_code,
            ward=w.ward,
            full_name=w.user.full_name if w.user else None,
            phone=w.user.phone if w.user else None,
            face_enrolled=w.face_enrolled,
            active_workload_count=w.active_workload_count,
            total_resolved_count=w.total_resolved_count,
            penalty_count=w.penalty_count,
            current_latitude=w.current_latitude,
            current_longitude=w.current_longitude
        ))
    return results

@router.get("/{worker_id}/tickets", response_model=List[TicketResponseSchema])
def get_worker_tickets(
    worker_id: int,
    status: Optional[TicketStatus] = None,
    db: Session = Depends(get_db)
):
    from app.tickets.models import Ticket, TicketPriority
    from app.tickets.router import _format_ticket_response
    from app.facilities.models import Facility

    worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == worker_id).first()
    if not worker:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Worker not found")

    query = db.query(Ticket).filter(Ticket.assigned_worker_id == worker.id)
    if status:
        query = query.filter(Ticket.status == status)
    
    tickets = query.all()
    
    # Priority rank: CRITICAL (0), HIGH (1), MEDIUM (2), LOW (3)
    priority_order = {
        TicketPriority.CRITICAL: 0,
        TicketPriority.HIGH: 1,
        TicketPriority.MEDIUM: 2,
        TicketPriority.LOW: 3
    }
    
    tickets.sort(key=lambda t: (
        priority_order.get(t.priority, 2),
        t.expected_sla_deadline or t.created_at
    ))

    results = []
    for t in tickets:
        facility = db.query(Facility).filter(Facility.id == t.facility_id).first()
        results.append(_format_ticket_response(t, facility, db))
    return results

@router.get("/{worker_id}/stats")
def get_worker_stats(worker_id: int, db: Session = Depends(get_db)):
    from app.tickets.models import Ticket, TicketStatus
    from datetime import datetime, timezone, timedelta
    
    worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == worker_id).first()
    if not worker:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Worker not found")

    active_assigned = db.query(Ticket).filter(
        Ticket.assigned_worker_id == worker.id,
        Ticket.status == TicketStatus.ASSIGNED
    ).count()

    in_progress = db.query(Ticket).filter(
        Ticket.assigned_worker_id == worker.id,
        Ticket.status.in_([TicketStatus.REACHED, TicketStatus.REPAIRING])
    ).count()

    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    completed_today = db.query(Ticket).filter(
        Ticket.assigned_worker_id == worker.id,
        Ticket.status.in_([TicketStatus.COMPLETED, TicketStatus.RESOLVED]),
        Ticket.updated_at >= today_start
    ).count()

    return {
        "worker_id": worker.id,
        "worker_code": worker.worker_code,
        "ward": worker.ward,
        "active_assigned": active_assigned,
        "in_progress": in_progress,
        "completed_today": completed_today,
        "total_resolved": worker.total_resolved_count,
        "penalty_count": worker.penalty_count
    }

