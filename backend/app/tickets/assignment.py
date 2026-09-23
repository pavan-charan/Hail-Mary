import math
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Tuple
from sqlalchemy.orm import Session

from app.facilities.models import Facility
from app.workers.models import LocalBodyWorker
from app.users.models import User, UserRole
from app.tickets.models import Ticket, TicketStatus, TicketStatusHistory
from app.sla.models import SLALog, SLAStep
from app.notifications.models import Notification, NotificationType
from app.config import settings

def calculate_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance in kilometers"""
    R = 6371.0 # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def find_best_worker_for_facility(db: Session, facility: Facility) -> Optional[LocalBodyWorker]:
    """
    Auto-Assignment Decision Matrix:
    1. Filter active workers in the Same Ward (worker.ward == facility.ward).
    2. Rank candidates by lowest active workload (assigned / reached / repairing tickets count).
    3. Tie-breaker: Distance to facility (if worker location known) or lowest worker ID.
    4. Fallback: If no worker in same ward, search across any active worker in municipality with lowest workload.
    """
    active_ticket_statuses = [
        TicketStatus.ASSIGNED,
        TicketStatus.REACHED,
        TicketStatus.REPAIRING
    ]

    # Query all active workers in the same ward
    same_ward_workers = db.query(LocalBodyWorker).join(User).filter(
        LocalBodyWorker.ward == facility.ward,
        User.is_active == True
    ).all()

    candidates = same_ward_workers

    # Fallback to municipal pool if no ward worker exists
    if not candidates:
        candidates = db.query(LocalBodyWorker).join(User).filter(
            User.is_active == True
        ).all()

    if not candidates:
        return None

    # Calculate live workload and distance for each candidate
    ranked_workers: List[Tuple[LocalBodyWorker, int, float]] = []

    for w in candidates:
        # Calculate real active workload from DB
        workload = db.query(Ticket).filter(
            Ticket.assigned_worker_id == w.id,
            Ticket.status.in_(active_ticket_statuses)
        ).count()

        # Update cached workload count on model
        w.active_workload_count = workload

        # Compute distance if location available
        dist = 0.0
        if w.current_latitude is not None and w.current_longitude is not None:
            dist = calculate_distance_km(
                w.current_latitude, w.current_longitude,
                facility.latitude, facility.longitude
            )

        ranked_workers.append((w, workload, dist))

    # Sort primarily by lowest workload, secondarily by closest distance, tertiarily by worker id
    ranked_workers.sort(key=lambda x: (x[1], x[2], x[0].id))

    return ranked_workers[0][0]

def execute_ticket_assignment(
    db: Session,
    ticket: Ticket,
    worker: LocalBodyWorker,
    facility: Facility,
    assigned_by_user_id: Optional[int] = None
) -> Ticket:
    """
    Executes worker assignment, initializes 24h SLA window, logs status history,
    records SLA log, and dispatches real-time notifications to worker & reporter.
    """
    now = datetime.now(timezone.utc)
    sla_deadline = now + timedelta(hours=settings.SLA_RESOLUTION_HOURS)

    from_status = ticket.status.value if ticket.status else TicketStatus.TICKET_CREATED.value

    ticket.assigned_worker_id = worker.id
    ticket.status = TicketStatus.ASSIGNED
    ticket.assigned_at = now
    ticket.expected_sla_deadline = sla_deadline
    ticket.updated_at = now

    # 1. Ticket Status History Entry
    history_entry = TicketStatusHistory(
        ticket_id=ticket.id,
        from_status=from_status,
        to_status=TicketStatus.ASSIGNED.value,
        changed_by_user_id=assigned_by_user_id,
        notes=f"Assigned to {worker.worker_code} ({worker.user.full_name if worker.user else 'Worker'}). SLA Deadline: {sla_deadline.strftime('%Y-%m-%d %H:%M:%S UTC')} (24h window)."
    )
    db.add(history_entry)

    # 2. SLA Log Entry
    sla_log = SLALog(
        ticket_id=ticket.id,
        step=SLAStep.ASSIGNMENT,
        triggered_at=now,
        status_response="ASSIGNED",
        details=f"Assigned to {worker.worker_code}. Target SLA resolution deadline set to {settings.SLA_RESOLUTION_HOURS} hours."
    )
    db.add(sla_log)

    # 3. Notification to Worker
    worker_notif = Notification(
        user_id=worker.user_id,
        title=f"Work Order Assigned: {ticket.ticket_id}",
        body=f"You have been assigned to repair {facility.name} ({facility.facility_id}) in {facility.ward}. Please reach facility and begin work. SLA: 24 hours.",
        notification_type=NotificationType.ASSIGNED,
        reference_id=ticket.ticket_id
    )
    db.add(worker_notif)

    # 4. Notification to Citizen Reporter
    if ticket.reporter_id:
        reporter_notif = Notification(
            user_id=ticket.reporter_id,
            title=f"Worker Assigned: {ticket.ticket_id}",
            body=f"Local body worker {worker.user.full_name if worker.user else worker.worker_code} has been assigned to your report for {facility.name}. Expected resolution within 24 hours.",
            notification_type=NotificationType.ASSIGNED,
            reference_id=ticket.ticket_id
        )
        db.add(reporter_notif)

    # Refresh cached workload count on worker
    worker.active_workload_count = (worker.active_workload_count or 0) + 1

    return ticket
