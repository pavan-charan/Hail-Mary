from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional, List

from app.database import get_db
from app.facilities.models import Facility, FacilityStatus
from app.facilities.schemas import FacilityResponseSchema
from app.qr.models import QRCodeRecord
from app.qr.service import generate_qr_base64_image
from app.facilities.router import calculate_haversine_distance

router = APIRouter(prefix="/qr", tags=["QR System"])

@router.get("/facility/{facility_id}/image")
def get_facility_qr_image(facility_id: str, db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    qr_base64 = generate_qr_base64_image(facility.facility_id)
    return {
        "facility_id": facility.facility_id,
        "facility_name": facility.name,
        "qr_payload": facility.facility_id,
        "qr_base64_png": f"data:image/png;base64,{qr_base64}"
    }

@router.get("/scan/{facility_id}")
def scan_facility_qr(
    facility_id: str,
    user_lat: Optional[float] = Query(None),
    user_lon: Optional[float] = Query(None),
    db: Session = Depends(get_db)
):
    """
    Phase 5 QR Scanning Engine:
    Validates QR code.
    If active: opens facility page with actions ['REPORT_ISSUE', 'RATE_FACILITY'].
    If demolished: displays 'This facility is no longer operational' and suggests nearest active alternatives.
    """
    clean_id = facility_id.strip()
    facility = db.query(Facility).filter(
        (Facility.facility_id == clean_id) | 
        (Facility.facility_id.ilike(clean_id)) |
        (Facility.facility_id.ilike(f"%{clean_id}%")) |
        (Facility.id == int(clean_id) if clean_id.isdigit() else False)
    ).first()
    
    if not facility:
        # Fallback search by name if ID has keywords
        facility = db.query(Facility).filter(Facility.name.ilike(f"%{clean_id}%")).first()

    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Invalid QR Code: Facility '{clean_id}' not recognized in civic registry.")
        
    ref_lat = user_lat if user_lat is not None else facility.latitude
    ref_lon = user_lon if user_lon is not None else facility.longitude

    # Demolished Facility Rule
    if facility.status == FacilityStatus.DEMOLISHED:
        alternatives = db.query(Facility).filter(
            Facility.status != FacilityStatus.DEMOLISHED,
            Facility.facility_type == facility.facility_type
        ).all()
        
        alt_list = []
        for alt in alternatives:
            dist = calculate_haversine_distance(ref_lat, ref_lon, alt.latitude, alt.longitude)
            alt_resp = FacilityResponseSchema.model_validate(alt)
            alt_resp.distance_meters = round(dist, 1)
            alt_resp.walking_time_minutes = max(1, int(round(dist / 80.0)))
            alt_resp.last_verified_formatted = alt.last_verified_at.strftime("%b %d, %I:%M %p") if alt.last_verified_at else "Verified Recently"
            alt_list.append(alt_resp)
            
        alt_list.sort(key=lambda x: x.distance_meters or 999999)
        
        return {
            "is_operational": False,
            "status": "DEMOLISHED",
            "message": "This facility is no longer operational.",
            "demolished_facility": FacilityResponseSchema.model_validate(facility),
            "nearest_alternatives": alt_list[:3]
        }

    # Active / Operational Facility
    dist = calculate_haversine_distance(ref_lat, ref_lon, facility.latitude, facility.longitude)
    resp = FacilityResponseSchema.model_validate(facility)
    resp.distance_meters = round(dist, 1)
    resp.walking_time_minutes = max(1, int(round(dist / 80.0)))
    resp.last_verified_formatted = facility.last_verified_at.strftime("%b %d, %I:%M %p") if facility.last_verified_at else "Verified Today"

    return {
        "is_operational": True,
        "status": facility.status.value,
        "facility": resp,
        "available_actions": ["REPORT_ISSUE", "RATE_FACILITY"]
    }
