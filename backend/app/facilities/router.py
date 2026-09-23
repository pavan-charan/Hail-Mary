from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
import math
import uuid
import json

from app.database import get_db
from app.facilities.models import Facility, FacilityStatus, FacilityType, GenderAccess
from app.facilities.schemas import FacilityCreateSchema, FacilityUpdateSchema, FacilityResponseSchema, DemolishRestoreSchema
from app.history.models import FacilityHistory, FacilityAction
from app.qr.models import QRCodeRecord
from app.history.router import HistoryResponseSchema

router = APIRouter(prefix="/facilities", tags=["Facilities"])

def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000  # Earth radius in meters
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
    ward: Optional[str] = None,
    status_filter: Optional[FacilityStatus] = None,
    wheelchair_only: Optional[bool] = False,
    include_demolished: bool = False,
    max_distance_meters: Optional[float] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Facility)
    
    # Phase 3 Demolished Rule: Hide from standard map discovery unless explicitly requested by Admin
    if not include_demolished:
        query = query.filter(Facility.status != FacilityStatus.DEMOLISHED)
    if status_filter:
        query = query.filter(Facility.status == status_filter)
    if facility_type:
        query = query.filter(Facility.facility_type == facility_type)
    if gender_access:
        query = query.filter(Facility.gender_access == gender_access)
    if ward:
        query = query.filter(Facility.ward == ward)
    if wheelchair_only:
        query = query.filter(Facility.wheelchair_accessible == True)
    if search:
        query = query.filter(
            (Facility.name.ilike(f"%{search}%")) |
            (Facility.facility_id.ilike(f"%{search}%")) |
            (Facility.address.ilike(f"%{search}%"))
        )
        
    facilities = query.order_by(Facility.created_at.desc()).all()
    results = []
    
    for f in facilities:
        resp = FacilityResponseSchema.model_validate(f)
        if user_lat is not None and user_lon is not None:
            dist = calculate_haversine_distance(user_lat, user_lon, f.latitude, f.longitude)
            resp.distance_meters = round(dist, 1)
            resp.walking_time_minutes = max(1, int(round(dist / 80.0)))
            if max_distance_meters and dist > max_distance_meters:
                continue
        results.append(resp)
        
    if user_lat is not None and user_lon is not None:
        results.sort(key=lambda x: x.distance_meters or 999999)
        
    return results

@router.post("", response_model=FacilityResponseSchema, status_code=status.HTTP_201_CREATED)
def create_facility(data: FacilityCreateSchema, db: Session = Depends(get_db)):
    # Automatically generate unique Facility ID: FAC-<WARD>-<TYPE>-<HEX>
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
        confidence_score=100.0,
        qr_code_hash=generated_facility_id
    )
    db.add(facility)
    db.commit()
    db.refresh(facility)
    
    # Store QR code linked to Facility ID
    qr_record = QRCodeRecord(
        facility_id=facility.id,
        facility_custom_id=facility.facility_id,
        qr_payload=facility.facility_id,
        is_active=True
    )
    db.add(qr_record)
    
    # Maintain Audit History
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.CREATED,
        new_state=json.dumps({
            "facility_id": facility.facility_id,
            "name": facility.name,
            "status": facility.status.value,
            "ward": facility.ward,
            "type": facility.facility_type.value,
        }),
        reason="Initial asset registration by Municipal Administration"
    )
    db.add(audit)
    db.commit()
    db.refresh(facility)
    
    return FacilityResponseSchema.model_validate(facility)

@router.get("/{facility_id}", response_model=FacilityResponseSchema)
def get_facility_by_id(facility_id: str, db: Session = Depends(get_db)):
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
        
    prev_snapshot = {
        "timings": f"{facility.opening_time} - {facility.closing_time}",
        "gender_access": facility.gender_access.value if facility.gender_access else None,
        "wheelchair_accessible": facility.wheelchair_accessible,
        "water_availability": facility.water_availability,
        "status": facility.status.value
    }
    
    update_dict = data.model_dump(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(facility, key, value)
        
    new_snapshot = {
        "timings": f"{facility.opening_time} - {facility.closing_time}",
        "gender_access": facility.gender_access.value if facility.gender_access else None,
        "wheelchair_accessible": facility.wheelchair_accessible,
        "water_availability": facility.water_availability,
        "status": facility.status.value
    }
    
    # Audit log
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.UPDATED,
        previous_state=json.dumps(prev_snapshot),
        new_state=json.dumps(new_snapshot),
        reason="Facility attributes updated by Municipal Administrator"
    )
    db.add(audit)
    db.commit()
    db.refresh(facility)
    return FacilityResponseSchema.model_validate(facility)

@router.post("/{facility_id}/demolish")
def demolish_facility(facility_id: str, data: Optional[DemolishRestoreSchema] = None, db: Session = Depends(get_db)):
    reason = data.reason if data else "Facility decommissioned/demolished by Municipal Administration"
    
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    prev_status = facility.status
    facility.status = FacilityStatus.DEMOLISHED
    
    # Invalidate QR code
    qr_record = db.query(QRCodeRecord).filter(QRCodeRecord.facility_id == facility.id).first()
    if qr_record:
        qr_record.is_active = False
        
    # Audit log: Keep complete history, never delete database record
    audit = FacilityHistory(
        facility_id=facility.id,
        action=FacilityAction.DEMOLISHED,
        previous_state=json.dumps({"status": prev_status.value}),
        new_state=json.dumps({"status": FacilityStatus.DEMOLISHED.value}),
        reason=reason
    )
    db.add(audit)
    db.commit()
    return {
        "success": True,
        "message": f"Facility {facility.facility_id} marked as demolished. Record preserved in audit database.",
        "facility_id": facility.facility_id,
        "status": facility.status
    }

@router.post("/{facility_id}/restore")
def restore_facility(facility_id: str, data: Optional[DemolishRestoreSchema] = None, db: Session = Depends(get_db)):
    reason = data.reason if data else "Facility restored to active service by Municipal Administration"
    
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    prev_status = facility.status
    facility.status = FacilityStatus.ACTIVE
    
    # Reactivate QR code
    qr_record = db.query(QRCodeRecord).filter(QRCodeRecord.facility_id == facility.id).first()
    if qr_record:
        qr_record.is_active = True
    else:
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
        action=FacilityAction.RESTORED,
        previous_state=json.dumps({"status": prev_status.value}),
        new_state=json.dumps({"status": FacilityStatus.ACTIVE.value}),
        reason=reason
    )
    db.add(audit)
    db.commit()
    return {
        "success": True,
        "message": f"Facility {facility.facility_id} successfully restored to active status.",
        "facility_id": facility.facility_id,
        "status": facility.status
    }

@router.get("/{facility_id}/history", response_model=List[HistoryResponseSchema])
def get_facility_history_logs(facility_id: str, db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    return db.query(FacilityHistory).filter(FacilityHistory.facility_id == facility.id).order_by(FacilityHistory.created_at.desc()).all()
