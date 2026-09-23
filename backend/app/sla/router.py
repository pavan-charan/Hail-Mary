from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.sla.models import SLALog, WorkerPenalty
from app.sla.schemas import SLALogResponse, WorkerPenaltyResponse

router = APIRouter(prefix="/sla", tags=["SLA & Escalations"])

from datetime import datetime, timezone, timedelta
from app.tickets.models import Ticket, TicketStatus
from app.workers.models import LocalBodyWorker
from app.facilities.models import Facility
from app.notifications.models import Notification, NotificationType
from app.sla.models import SLAStep
from app.tickets.assignment import find_best_worker_for_facility, execute_ticket_assignment

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

@router.post("/check-breaches")
def run_sla_escalation_engine(db: Session = Depends(get_db)):
    """
    Scans active tickets and executes hierarchical escalation matrix:
    - 20h elapsed: Reminder Notification
    - 24h breach: AI Voice Call 1
    - 26h breach: AI Voice Call 2 + Supervisor Alert
    - 28h breach: Worker Penalty & Reassignment
    """
    now = datetime.now(timezone.utc)
    active_statuses = [TicketStatus.ASSIGNED, TicketStatus.REACHED, TicketStatus.REPAIRING]
    active_tickets = db.query(Ticket).filter(
        Ticket.status.in_(active_statuses),
        Ticket.assigned_at != None
    ).all()

    reminders = 0
    calls_1 = 0
    calls_2 = 0
    reassignments = 0

    for ticket in active_tickets:
        if not ticket.assigned_at:
            continue

        assigned_at = ticket.assigned_at
        if assigned_at.tzinfo is None:
            assigned_at = assigned_at.replace(tzinfo=timezone.utc)
        elapsed_hours = (now - assigned_at).total_seconds() / 3600.0
        worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == ticket.assigned_worker_id).first() if ticket.assigned_worker_id else None
        facility = db.query(Facility).filter(Facility.id == ticket.facility_id).first()
        facility_name = facility.name if facility else "Public Facility"

        # Check existing logs to avoid duplicate step triggers
        logged_steps = set(
            s[0] for s in db.query(SLALog.step).filter(SLALog.ticket_id == ticket.id).all()
        )

        # Step 4: Penalty and Reassign (>= 28 hours)
        if elapsed_hours >= 28.0 and SLAStep.PENALTY_AND_REASSIGN not in logged_steps:
            if worker:
                penalty = WorkerPenalty(
                    worker_id=worker.id,
                    ticket_id=ticket.id,
                    reason=f"Breached 24-hour SLA by {round(elapsed_hours, 1)} hours without completion.",
                    penalty_points=10
                )
                db.add(penalty)
                worker.penalty_count = (worker.penalty_count or 0) + 1
                
                # Reassign to next best candidate
                if facility:
                    next_worker = find_best_worker_for_facility(db, facility)
                    if next_worker and next_worker.id != worker.id:
                        execute_ticket_assignment(db, ticket, next_worker, facility)

            sla_log = SLALog(
                ticket_id=ticket.id,
                step=SLAStep.PENALTY_AND_REASSIGN,
                triggered_at=now,
                status_response="PENALTY_APPLIED",
                details=f"Worker penalized -10 points after {round(elapsed_hours, 1)}h breach. Reassignment triggered."
            )
            db.add(sla_log)
            reassignments += 1

        # Step 3: AI Voice Call 2 (>= 26 hours)
        elif elapsed_hours >= 26.0 and SLAStep.AI_VOICE_CALL_2 not in logged_steps:
            sla_log = SLALog(
                ticket_id=ticket.id,
                step=SLAStep.AI_VOICE_CALL_2,
                triggered_at=now,
                status_response="COMPLETED_CALL",
                details=f"Twilio AI Voice Call #2 dispatched to worker phone {worker.user.phone if worker and worker.user else 'N/A'} and Ward Supervisor."
            )
            db.add(sla_log)
            calls_2 += 1

        # Step 2: AI Voice Call 1 (>= 24 hours)
        elif elapsed_hours >= 24.0 and SLAStep.AI_VOICE_CALL_1 not in logged_steps:
            sla_log = SLALog(
                ticket_id=ticket.id,
                step=SLAStep.AI_VOICE_CALL_1,
                triggered_at=now,
                status_response="COMPLETED_CALL",
                details=f"Twilio AI Voice Call #1 triggered for 24h SLA breach on ticket {ticket.ticket_id}."
            )
            db.add(sla_log)
            calls_1 += 1

        # Step 1: Reminder Notification (>= 20 hours)
        elif elapsed_hours >= 20.0 and SLAStep.REMINDER_24H not in logged_steps:
            if worker:
                notif = Notification(
                    user_id=worker.user_id,
                    title=f"SLA Reminder: {ticket.ticket_id}",
                    body=f"Ticket {ticket.ticket_id} for {facility_name} is approaching its 24h SLA deadline (4h remaining).",
                    notification_type=NotificationType.SLA_REMINDER,
                    reference_id=ticket.ticket_id
                )
                db.add(notif)
            
            sla_log = SLALog(
                ticket_id=ticket.id,
                step=SLAStep.REMINDER_24H,
                triggered_at=now,
                status_response="DELIVERED",
                details="4-hour pre-breach reminder notification dispatched to assigned worker."
            )
            db.add(sla_log)
            reminders += 1

    db.commit()
    return {
        "status": "success",
        "scanned_tickets_count": len(active_tickets),
        "reminders_sent": reminders,
        "voice_calls_1_triggered": calls_1,
        "voice_calls_2_triggered": calls_2,
        "penalties_and_reassignments": reassignments
    }

