from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
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
        "qr_base64_png": f"data:image/png;base64,{qr_base64}"
    }

@router.get("/scan/{facility_id}")
def scan_qr_code(facility_id: str, user_lat: float = None, user_lon: float = None, db: Session = Depends(get_db)):
    """
    Phase 5 QR Scanning Engine:
    Validates QR. If active, returns facility details & allowed actions.
    If demolished, returns 'no longer operational' and suggests nearest alternatives.
    """
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid QR code: Facility not found")
        
    if facility.status == FacilityStatus.DEMOLISHED:
        # Fetch nearest active alternatives
        alternatives = db.query(Facility).filter(
            Facility.status != FacilityStatus.DEMOLISHED,
            Facility.facility_type == facility.facility_type
        ).all()
        
        alt_list = []
        for alt in alternatives:
            dist = calculate_haversine_distance(facility.latitude, facility.longitude, alt.latitude, alt.longitude)
            alt_resp = FacilityResponseSchema.model_validate(alt)
            alt_resp.distance_meters = round(dist, 1)
            alt_resp.walking_time_minutes = max(1, int(round(dist / 80.0)))
            alt_list.append(alt_resp)
            
        alt_list.sort(key=lambda x: x.distance_meters or 999999)
        
        return {
            "is_operational": False,
            "status": "DEMOLISHED",
            "message": "This facility is no longer operational.",
            "demolished_facility": FacilityResponseSchema.model_validate(facility),
            "nearest_alternatives": alt_list[:3]
        }
        
    return {
        "is_operational": True,
        "status": facility.status,
        "facility": FacilityResponseSchema.model_validate(facility),
        "available_actions": ["REPORT_ISSUE", "RATE_FACILITY"]
    }
