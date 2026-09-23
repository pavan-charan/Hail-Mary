from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.tickets.models import Ticket, TicketStatus
from app.facilities.models import Facility, FacilityStatus
from app.workers.models import LocalBodyWorker
from app.sla.models import WorkerPenalty

router = APIRouter(prefix="/analytics", tags=["Analytics & Heatmaps"])

@router.get("/summary")
def get_analytics_summary(db: Session = Depends(get_db)):
    total_facilities = db.query(Facility).count()
    active_facilities = db.query(Facility).filter(Facility.status == FacilityStatus.ACTIVE).count()
    demolished_facilities = db.query(Facility).filter(Facility.status == FacilityStatus.DEMOLISHED).count()
    
    total_tickets = db.query(Ticket).count()
    open_tickets = db.query(Ticket).filter(
        Ticket.status.in_([TicketStatus.TICKET_CREATED, TicketStatus.ASSIGNED, TicketStatus.REACHED, TicketStatus.REPAIRING, TicketStatus.UNDER_VERIFICATION])
    ).count()
    resolved_tickets = db.query(Ticket).filter(Ticket.status == TicketStatus.RESOLVED).count()
    
    total_workers = db.query(LocalBodyWorker).count()
    total_penalties = db.query(WorkerPenalty).count()
    
    avg_confidence = db.query(func.avg(Facility.confidence_score)).filter(Facility.status == FacilityStatus.ACTIVE).scalar() or 100.0
    
    # Low confidence facilities (< 60)
    low_confidence_facilities = db.query(Facility).filter(
        Facility.status == FacilityStatus.ACTIVE,
        Facility.confidence_score < 60.0
    ).count()
    
    # Ward-level ticket breakdown
    wards = db.query(Facility.ward, func.count(Ticket.id)).join(Ticket, Ticket.facility_id == Facility.id, isouter=True).group_by(Facility.ward).all()
    ward_stats = [{"ward": w[0], "ticket_count": w[1]} for w in wards]

    return {
        "facilities": {
            "total": total_facilities,
            "active": active_facilities,
            "demolished": demolished_facilities,
            "avg_confidence_score": round(float(avg_confidence), 1),
            "low_confidence_count": low_confidence_facilities
        },
        "tickets": {
            "total": total_tickets,
            "open": open_tickets,
            "resolved": resolved_tickets,
            "resolution_rate_percent": round((resolved_tickets / total_tickets * 100) if total_tickets > 0 else 100.0, 1)
        },
        "workers": {
            "total": total_workers,
            "total_penalties": total_penalties
        },
        "ward_performance": ward_stats
    }

@router.get("/heatmaps")
def get_heatmap_points(db: Session = Depends(get_db)):
    # Returns coordinates and intensity based on ticket volume / low confidence
    facilities = db.query(Facility).filter(Facility.status != FacilityStatus.DEMOLISHED).all()
    points = []
    for f in facilities:
        ticket_count = db.query(Ticket).filter(Ticket.facility_id == f.id).count()
        # Intensity factor 0.0 - 1.0
        intensity = min(1.0, max(0.1, (ticket_count * 0.2) + ((100.0 - f.confidence_score) / 100.0 * 0.5)))
        points.append({
            "facility_id": f.facility_id,
            "name": f.name,
            "latitude": f.latitude,
            "longitude": f.longitude,
            "ticket_count": ticket_count,
            "confidence_score": f.confidence_score,
            "intensity": round(intensity, 2)
        })
    return points
