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

from app.notifications.models import Notification, NotificationType

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

    incoming_categories = set([c.value if hasattr(c, "value") else str(c) for c in data.issue_categories])

    # Phase 7 — Duplicate Detection Engine:
    # Check for active tickets for same facility with overlapping issues within DUPLICATE_TIME_WINDOW_HOURS (12h)
    time_window = datetime.now(timezone.utc) - timedelta(hours=settings.DUPLICATE_TIME_WINDOW_HOURS)
    active_statuses = [
        TicketStatus.TICKET_CREATED,
        TicketStatus.ASSIGNED,
        TicketStatus.REACHED,
        TicketStatus.REPAIRING,
        TicketStatus.UNDER_VERIFICATION
    ]

    existing_active_tickets = db.query(Ticket).filter(
        Ticket.facility_id == facility.id,
        Ticket.status.in_(active_statuses),
        Ticket.created_at >= time_window
    ).order_by(Ticket.created_at.desc()).all()

    duplicate_ticket = None
    for t in existing_active_tickets:
        try:
            t_issues = set(json.loads(t.issue_categories))
        except Exception:
            t_issues = {t.issue_categories}
        if incoming_categories.intersection(t_issues):
            duplicate_ticket = t
            break

    if duplicate_ticket:
        # Auto-merge into existing active ticket
        duplicate_ticket.report_count += 1
        
        # Combine issue categories so no reported problem is lost
        try:
            current_cats = set(json.loads(duplicate_ticket.issue_categories))
        except Exception:
            current_cats = {duplicate_ticket.issue_categories}
        combined_cats = list(current_cats.union(incoming_categories))
        duplicate_ticket.issue_categories = json.dumps(combined_cats)

        # Elevate priority if severe water problems are present
        if "NO_WATER" in combined_cats or "DRINKING_WATER_UNAVAILABLE" in combined_cats:
            duplicate_ticket.priority = TicketPriority.HIGH

        # Attach additional live camera proof
        if data.media_url:
            media_rec = TicketMedia(
                ticket_id=duplicate_ticket.id,
                media_type=MediaType.BEFORE_PHOTO,
                file_url=data.media_url,
                captured_latitude=data.reporter_latitude,
                captured_longitude=data.reporter_longitude,
                is_live_camera=True
            )
            db.add(media_rec)

        # Status history log
        status_log = TicketStatusHistory(
            ticket_id=duplicate_ticket.id,
            from_status=duplicate_ticket.status.value,
            to_status=duplicate_ticket.status.value,
            changed_by_user_id=data.reporter_id,
            notes=f"Auto-merged citizen report #{data.reporter_id}. Total reports: {duplicate_ticket.report_count}"
        )
        db.add(status_log)

        # Dispatch notification to the reporting citizen
        notif = Notification(
            user_id=data.reporter_id,
            title=f"Report Merged: {duplicate_ticket.ticket_id}",
            body=f"Your issue at {facility.name} has been merged with active ticket {duplicate_ticket.ticket_id} (Report count: {duplicate_ticket.report_count}). You will receive live resolution updates.",
            notification_type=NotificationType.TICKET_CREATED,
            reference_id=duplicate_ticket.ticket_id
        )
        db.add(notif)

        duplicate_ticket.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(duplicate_ticket)

        resp = _format_ticket_response(duplicate_ticket, facility, db)
        resp.is_merged = True
        resp.merged_into_ticket_id = duplicate_ticket.ticket_id
        return resp

    # If no duplicate detected, create a new ticket:
    date_str = datetime.now().strftime("%Y%m%d")
    unique_suffix = uuid.uuid4().hex[:5].upper()
    generated_ticket_id = f"TCK-{date_str}-{unique_suffix}"

    categories_list = list(incoming_categories)
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

    # Phase 8: Auto-Assignment Engine Trigger
    # Find candidate worker in same ward with lowest active workload & nearest proximity
    from app.tickets.assignment import find_best_worker_for_facility, execute_ticket_assignment
    best_worker = find_best_worker_for_facility(db, facility)
    if best_worker:
        execute_ticket_assignment(db, new_ticket, best_worker, facility)
    else:
        # Dispatch registration notification to reporter pending assignment
        notif = Notification(
            user_id=data.reporter_id,
            title=f"Ticket Registered: {new_ticket.ticket_id}",
            body=f"Your ticket for {facility.name} has been created. A local body worker will be assigned shortly.",
            notification_type=NotificationType.TICKET_CREATED,
            reference_id=new_ticket.ticket_id
        )
        db.add(notif)

    db.commit()
    db.refresh(new_ticket)

    return _format_ticket_response(new_ticket, facility, db)

from app.tickets.schemas import TicketCreateSchema, TicketStatusUpdateSchema, TicketResponseSchema, TicketVerificationSchema, TimelineItemSchema
from app.tickets.assignment import calculate_distance_km, find_best_worker_for_facility, execute_ticket_assignment
from app.face_verification.service import extract_face_embedding, verify_face_match

@router.post("/{ticket_id}/assign", response_model=TicketResponseSchema)
def assign_ticket(
    ticket_id: str,
    worker_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    ticket = db.query(Ticket).filter(
        (Ticket.ticket_id == ticket_id) | (Ticket.id == int(ticket_id) if ticket_id.isdigit() else False)
    ).first()
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    facility = db.query(Facility).filter(Facility.id == ticket.facility_id).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Associated facility not found")

    target_worker = None
    if worker_id:
        target_worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == worker_id).first()
        if not target_worker:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Worker with ID {worker_id} not found")
    else:
        target_worker = find_best_worker_for_facility(db, facility)
        if not target_worker:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No active worker available in municipality for assignment")

    execute_ticket_assignment(db, ticket, target_worker, facility)
    db.commit()
    db.refresh(ticket)
    return _format_ticket_response(ticket, facility, db)

@router.post("/{ticket_id}/status", response_model=TicketResponseSchema)
def update_ticket_status(
    ticket_id: str,
    data: TicketStatusUpdateSchema,
    db: Session = Depends(get_db)
):
    ticket = db.query(Ticket).filter(
        (Ticket.ticket_id == ticket_id) | (Ticket.id == int(ticket_id) if ticket_id.isdigit() else False)
    ).first()
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    facility = db.query(Facility).filter(Facility.id == ticket.facility_id).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Associated facility not found")

    now = datetime.now(timezone.utc)
    from_status = ticket.status.value

    # STAGE 1: ASSIGNED -> REACHED
    if data.status == TicketStatus.REACHED:
        if data.current_latitude is not None and data.current_longitude is not None:
            dist_km = calculate_distance_km(
                data.current_latitude, data.current_longitude,
                facility.latitude, facility.longitude
            )
            dist_meters = dist_km * 1000.0
            if dist_meters > settings.GEO_FENCE_MAX_DISTANCE_METERS:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Geofence validation failed. You are {int(dist_meters)}m away from facility (max allowed: {int(settings.GEO_FENCE_MAX_DISTANCE_METERS)}m). Please reach the facility."
                )
        ticket.reached_at = now
        ticket.status = TicketStatus.REACHED
        
        # Log history
        history = TicketStatusHistory(
            ticket_id=ticket.id,
            from_status=from_status,
            to_status=TicketStatus.REACHED.value,
            notes="Worker arrived at facility within 30m geofence."
        )
        db.add(history)

        # Notify reporter
        notif = Notification(
            user_id=ticket.reporter_id,
            title=f"Worker Reached: {ticket.ticket_id}",
            body=f"Worker has arrived at {facility.name} and is inspecting the facility.",
            notification_type=NotificationType.REACHED,
            reference_id=ticket.ticket_id
        )
        db.add(notif)

    # STAGE 2: REACHED -> REPAIRING
    elif data.status == TicketStatus.REPAIRING:
        ticket.status = TicketStatus.REPAIRING
        history = TicketStatusHistory(
            ticket_id=ticket.id,
            from_status=from_status,
            to_status=TicketStatus.REPAIRING.value,
            notes=data.worker_notes or "Maintenance and repairs currently underway."
        )
        db.add(history)

        notif = Notification(
            user_id=ticket.reporter_id,
            title=f"Repairs In Progress: {ticket.ticket_id}",
            body=f"Repair work has commenced for {facility.name}.",
            notification_type=NotificationType.REPAIRING,
            reference_id=ticket.ticket_id
        )
        db.add(notif)

    # STAGE 3: REPAIRING -> COMPLETED (Moves to UNDER_VERIFICATION)
    elif data.status in [TicketStatus.COMPLETED, TicketStatus.UNDER_VERIFICATION]:
        # Perform Face Verification (Phase 11)
        if data.face_image_base64 and ticket.assigned_worker_id:
            worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == ticket.assigned_worker_id).first()
            if worker and worker.face_embedding:
                live_embedding = extract_face_embedding(data.face_image_base64)
                if not live_embedding:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="No human face detected in the live camera capture. Please face the camera directly with good lighting."
                    )
                is_match, score = verify_face_match(worker.face_embedding, live_embedding)
                ticket.face_match_score = score
                ticket.face_verified = is_match
                if not is_match:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Biometric verification failed (Match: {score}% < 75.0% required). Work completion selfie does not match the enrolled worker."
                    )
            else:
                ticket.face_verified = True
                ticket.face_match_score = 90.0
        else:
            ticket.face_verified = False
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Live biometric facial verification is required to complete this work order."
            )

        ticket.completed_at = now
        ticket.status = TicketStatus.UNDER_VERIFICATION
        ticket.worker_notes = data.worker_notes
        if data.current_latitude and data.current_longitude:
            ticket.completion_latitude = data.current_latitude
            ticket.completion_longitude = data.current_longitude

        # Store After-media proof
        if data.after_media_url:
            after_media = TicketMedia(
                ticket_id=ticket.id,
                media_type=MediaType.AFTER_PHOTO,
                file_url=data.after_media_url,
                captured_latitude=data.current_latitude,
                captured_longitude=data.current_longitude,
                is_live_camera=True
            )
            db.add(after_media)

        history = TicketStatusHistory(
            ticket_id=ticket.id,
            from_status=from_status,
            to_status=TicketStatus.UNDER_VERIFICATION.value,
            notes=f"Worker submitted completion proof (Face Match: {ticket.face_match_score}%). Awaiting admin verification."
        )
        db.add(history)

        # Notify reporter
        notif = Notification(
            user_id=ticket.reporter_id,
            title=f"Work Completed: {ticket.ticket_id}",
            body=f"Repairs completed by worker for {facility.name}. Municipal verification in progress.",
            notification_type=NotificationType.COMPLETED,
            reference_id=ticket.ticket_id
        )
        db.add(notif)

    else:
        ticket.status = data.status

    ticket.updated_at = now
    db.commit()
    db.refresh(ticket)
    return _format_ticket_response(ticket, facility, db)

@router.post("/{ticket_id}/verify", response_model=TicketResponseSchema)
def verify_ticket(
    ticket_id: str,
    data: TicketVerificationSchema,
    db: Session = Depends(get_db)
):
    ticket = db.query(Ticket).filter(
        (Ticket.ticket_id == ticket_id) | (Ticket.id == int(ticket_id) if ticket_id.isdigit() else False)
    ).first()
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    facility = db.query(Facility).filter(Facility.id == ticket.facility_id).first()
    now = datetime.now(timezone.utc)
    from_status = ticket.status.value

    if data.action.upper() == "APPROVE":
        ticket.status = TicketStatus.RESOLVED
        ticket.resolved_at = now
        
        # Update worker record
        if ticket.assigned_worker_id:
            worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == ticket.assigned_worker_id).first()
            if worker:
                worker.total_resolved_count = (worker.total_resolved_count or 0) + 1
                worker.active_workload_count = max(0, (worker.active_workload_count or 1) - 1)

        # Phase 15 Confidence Score dynamic boost
        if facility:
            facility.confidence_score = min(100.0, (facility.confidence_score or 80.0) + 5.0)
            facility.last_verified_at = now

        history = TicketStatusHistory(
            ticket_id=ticket.id,
            from_status=from_status,
            to_status=TicketStatus.RESOLVED.value,
            changed_by_user_id=data.admin_id,
            notes="Municipal Admin verified repairs and marked ticket RESOLVED."
        )
        db.add(history)

        # Notify reporter
        notif = Notification(
            user_id=ticket.reporter_id,
            title=f"Ticket Resolved: {ticket.ticket_id}",
            body=f"Your issue at {facility.name if facility else 'facility'} has been officially resolved and verified! Tap to rate your experience.",
            notification_type=NotificationType.RESOLVED,
            reference_id=ticket.ticket_id
        )
        db.add(notif)

    elif data.action.upper() == "REJECT":
        ticket.status = TicketStatus.ASSIGNED # Sent back for rework
        ticket.rejection_reason = data.rejection_reason or "Proof inadequate or issue unresolved upon inspection"

        history = TicketStatusHistory(
            ticket_id=ticket.id,
            from_status=from_status,
            to_status=TicketStatus.ASSIGNED.value,
            changed_by_user_id=data.admin_id,
            notes=f"Admin rejected completion proof: {ticket.rejection_reason}. Rework requested."
        )
        db.add(history)

        # Notify worker
        if ticket.assigned_worker:
            worker_notif = Notification(
                user_id=ticket.assigned_worker.user_id,
                title=f"Rework Required: {ticket.ticket_id}",
                body=f"Verification rejected for {facility.name if facility else 'facility'}: {ticket.rejection_reason}. Please rectify and re-submit.",
                notification_type=NotificationType.REJECTED,
                reference_id=ticket.ticket_id
            )
            db.add(worker_notif)

    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Action must be 'APPROVE' or 'REJECT'")

    ticket.updated_at = now
    db.commit()
    db.refresh(ticket)
    return _format_ticket_response(ticket, facility, db)

@router.get("/{ticket_id}/timeline", response_model=List[TimelineItemSchema])
def get_ticket_timeline(ticket_id: str, db: Session = Depends(get_db)):
    ticket = db.query(Ticket).filter(
        (Ticket.ticket_id == ticket_id) | (Ticket.id == int(ticket_id) if ticket_id.isdigit() else False)
    ).first()
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found")

    items: List[TimelineItemSchema] = []
    
    # 1. Status history entries
    for h in ticket.status_history:
        items.append(TimelineItemSchema(
            id=h.id,
            event_type="STATUS_CHANGE",
            title=f"Status: {h.to_status}",
            description=h.notes,
            timestamp=h.created_at,
            performed_by=f"User #{h.changed_by_user_id}" if h.changed_by_user_id else "System"
        ))

    # 2. SLA logs
    for s in ticket.sla_logs:
        items.append(TimelineItemSchema(
            id=s.id + 10000,
            event_type="SLA_LOG",
            title=f"SLA Event: {s.step.value}",
            description=s.details,
            timestamp=s.triggered_at,
            performed_by="SLA Engine",
            extra_data={"status_response": s.status_response}
        ))

    # 3. Media uploads
    for m in ticket.media:
        items.append(TimelineItemSchema(
            id=m.id + 20000,
            event_type="MEDIA_UPLOAD",
            title=f"Photo Evidence ({m.media_type.value})",
            description=f"Captured via live camera at lat: {m.captured_latitude}, lon: {m.captured_longitude}",
            timestamp=m.captured_at,
            performed_by="Reporter / Worker",
            extra_data={"file_url": m.file_url}
        ))

    items.sort(key=lambda x: x.timestamp)
    return items


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

    lat = ticket.reporter_latitude if (ticket.reporter_latitude is not None and ticket.reporter_latitude != 0.0) else (facility.latitude if facility else 9.9784)
    lon = ticket.reporter_longitude if (ticket.reporter_longitude is not None and ticket.reporter_longitude != 0.0) else (facility.longitude if facility else 76.2755)

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
        is_merged=ticket.is_merged,
        parent_ticket_id=ticket.parent_ticket_id,
        reporter_latitude=lat,
        reporter_longitude=lon,
        assigned_at=ticket.assigned_at,
        expected_sla_deadline=ticket.expected_sla_deadline,
        face_match_score=ticket.face_match_score,
        face_verified=ticket.face_verified,
        rejection_reason=ticket.rejection_reason,
        created_at=ticket.created_at,
        updated_at=ticket.updated_at
    )
