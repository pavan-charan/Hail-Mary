from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
import math
import uuid

from app.database import get_db
from app.facilities.models import Facility, FacilityStatus, FacilityType, GenderAccess
from app.facilities.schemas import FacilityCreateSchema, FacilityUpdateSchema, FacilityResponseSchema
from app.history.models import FacilityHistory, FacilityAction
from app.qr.models import QRCodeRecord

router = APIRouter(prefix="/facilities", tags=["Facilities"])

def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Returns distance in meters
    R = 6371000  # Radius of earth in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

@router.get("", response_model=List[FacilityResponseSchema])
def list_facilities(
    user_lat: Optional[float] = Query(None, description="User latitude for distance calculation"),
    user_lon: Optional[float] = Query(None, description="User longitude for distance calculation"),
    facility_type: Optional[FacilityType] = None,
    gender_access: Optional[GenderAccess] = None,
    wheelchair_only: Optional[bool] = False,
    include_demolished: bool = False,
    max_distance_meters: Optional[float] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Facility)
    if not include_demolished:
        query = query.filter(Facility.status != FacilityStatus.DEMOLISHED)
    if facility_type:
        query = query.filter(Facility.facility_type == facility_type)
    if gender_access:
        query = query.filter(Facility.gender_access == gender_access)
    if wheelchair_only:
        query = query.filter(Facility.wheelchair_accessible == True)
        
    facilities = query.all()
    results = []
    
    for f in facilities:
        resp = FacilityResponseSchema.model_validate(f)
        if user_lat is not None and user_lon is not None:
            dist = calculate_haversine_distance(user_lat, user_lon, f.latitude, f.longitude)
            resp.distance_meters = round(dist, 1)
            resp.walking_time_minutes = max(1, int(round(dist / 80.0))) # avg 80 meters per minute walking
            if max_distance_meters and dist > max_distance_meters:
                continue
        results.append(resp)
        
    if user_lat is not None and user_lon is not None:
        results.sort(key=lambda x: x.distance_meters or 999999)
        
    return results

@router.post("", response_model=FacilityResponseSchema, status_code=status.HTTP_201_CREATED)
def create_facility(data: FacilityCreateSchema, db: Session = Depends(get_db)):
    # Auto-generate Facility ID: FAC-<WARD>-<TYPE_CODE>-<RANDOM>
    type_code = "TLT" if data.facility_type == FacilityType.TOILET else "WTR"
    clean_ward = data.ward.upper().replace(" ", "").replace("-", "")
    unique_suffix = uuid.uuid4().hex[:6].upper()
    generated_facility_id = f"FAC-{clean_ward}-{type_code}-{unique_suffix}"
    
    facility = Facility(
        facility_id=generated_facility_id,
        name=data.name,
        facility_type=data.facility_type,
        latitude=data.latitude,
        longitude=data.longitude,
        address=data.address,
        ward=data.ward,
        gender_access=data.gender_access,
        wheelchair_accessible=data.wheelchair_accessible,
        water_availability=data.water_availability,
        opening_time=data.opening_time,
        closing_time=data.closing_time,
        status=FacilityStatus.ACTIVE,
        confidence_score=100.0
    )
    db.add(facility)
    db.commit()
    db.refresh(facility)
    
    # Generate QR Code record
    qr_record = QRCodeRecord(
        facility_id=facility.id,
        facility_custom_id=facility.facility_id,
        qr_payload=facility.facility_id,
        is_active=True
    )
    db.add(qr_record)
    
    # Audit log
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.CREATED,
        new_state=f"Facility created with ID {facility.facility_id}"
    )
    db.add(audit)
    db.commit()
    db.refresh(facility)
    
    return FacilityResponseSchema.model_validate(facility)

@router.get("/{facility_id}", response_model=FacilityResponseSchema)
def get_facility(facility_id: str, db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
    return FacilityResponseSchema.model_validate(facility)

@router.put("/{facility_id}", response_model=FacilityResponseSchema)
def update_facility(facility_id: str, data: FacilityUpdateSchema, db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    update_dict = data.model_dump(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(facility, key, value)
        
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.UPDATED,
        new_state=str(update_dict)
    )
    db.add(audit)
    db.commit()
    db.refresh(facility)
    return FacilityResponseSchema.model_validate(facility)

@router.post("/{facility_id}/demolish")
def demolish_facility(facility_id: str, reason: str = "Decommissioned by Admin", db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    facility.status = FacilityStatus.DEMOLISHED
    # Invalidate QR code
    qr_record = db.query(QRCodeRecord).filter(QRCodeRecord.facility_id == facility.id).first()
    if qr_record:
        qr_record.is_active = False
        
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.DEMOLISHED,
        reason=reason
    )
    db.add(audit)
    db.commit()
    return {"success": True, "message": f"Facility {facility.facility_id} marked as demolished", "status": facility.status}

@router.post("/{facility_id}/restore")
def restore_facility(facility_id: str, reason: str = "Restored by Admin", db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    facility.status = FacilityStatus.ACTIVE
    qr_record = db.query(QRCodeRecord).filter(QRCodeRecord.facility_id == facility.id).first()
    if qr_record:
        qr_record.is_active = True
        
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.RESTORED,
        reason=reason
    )
    db.add(audit)
    db.commit()
    return {"success": True, "message": f"Facility {facility.facility_id} successfully restored", "status": facility.status}
