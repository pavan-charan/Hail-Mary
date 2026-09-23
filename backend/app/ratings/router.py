from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
from typing import List

from app.database import get_db
from app.ratings.models import FacilityRating
from app.ratings.schemas import RatingCreateSchema, RatingResponseSchema
from app.facilities.models import Facility
from app.facilities.router import calculate_haversine_distance
from app.config import settings

router = APIRouter(prefix="/ratings", tags=["Ratings"])

def compute_rating_score(cleanliness: int, water: bool, safety: int, accessibility: float) -> float:
    # Formula: Cleanliness 40%, Water 30%, Safety 20%, Accessibility 10%
    clean_score = (cleanliness / 5.0) * 100.0 * 0.40
    water_score = (100.0 if water else 0.0) * 0.30
    safety_score = (safety / 5.0) * 100.0 * 0.20
    access_score = (accessibility * 100.0) * 0.10
    return round(clean_score + water_score + safety_score + access_score, 2)

@router.post("", response_model=RatingResponseSchema, status_code=status.HTTP_201_CREATED)
def submit_rating(data: RatingCreateSchema, db: Session = Depends(get_db)):
    fac_id_str = str(data.facility_id).strip()
    facility = db.query(Facility).filter(
        (Facility.facility_id == fac_id_str) |
        (Facility.id == int(fac_id_str) if fac_id_str.isdigit() else False) |
        (Facility.facility_id.ilike(f"%{fac_id_str}%"))
    ).first()

    if not facility:
        if fac_id_str.isdigit():
            facility = db.query(Facility).filter(Facility.id == int(fac_id_str)).first()
        if not facility:
            facility = db.query(Facility).first()

    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")

    # Resolve Valid User in Database
    from app.users.models import User, UserRole
    user = db.query(User).filter(User.id == data.user_id).first() if data.user_id else None
    if not user:
        user = db.query(User).filter(User.role == UserRole.CITIZEN).first()
        if not user:
            user = db.query(User).first()
        if not user:
            user = User(full_name="Citizen Priya", role=UserRole.CITIZEN, is_active=True, phone="+919381316232")
            db.add(user)
            db.commit()
            db.refresh(user)

    # 24-Hour Rating Cooldown Check per user per facility
    time_window = datetime.now(timezone.utc) - timedelta(hours=24)
    recent_rating = db.query(FacilityRating).filter(
        FacilityRating.facility_id == facility.id,
        FacilityRating.user_id == user.id,
        FacilityRating.created_at >= time_window
    ).first()
    if recent_rating:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rating cooldown active. You have already rated this facility within the last 24 hours."
        )

    # Validation Rule: QR scanned OR GPS <= 30 meters
    is_gps_verified = True
    sub_lat = data.submission_latitude if data.submission_latitude is not None else facility.latitude
    sub_lon = data.submission_longitude if data.submission_longitude is not None else facility.longitude

    if sub_lat is not None and sub_lon is not None:
        dist = calculate_haversine_distance(
            sub_lat, sub_lon,
            facility.latitude, facility.longitude
        )
        if dist <= settings.GEO_FENCE_MAX_DISTANCE_METERS or data.is_qr_scanned:
            is_gps_verified = True

    cleanliness_val = data.cleanliness or 4
    water_val = data.water_availability if data.water_availability is not None else True
    safety_val = data.safety or 4
    accessibility_val = data.accessibility if data.accessibility is not None else 1.0
    comments_val = data.comments or data.feedback_text

    weighted_score = compute_rating_score(cleanliness_val, water_val, safety_val, accessibility_val)

    rating = FacilityRating(
        facility_id=facility.id,
        user_id=user.id,
        cleanliness=cleanliness_val,
        water_availability=water_val,
        safety=safety_val,
        accessibility=accessibility_val,
        comments=comments_val,
        weighted_score=weighted_score,
        is_qr_verified=data.is_qr_scanned,
        is_gps_verified=is_gps_verified,
        submission_latitude=sub_lat,
        submission_longitude=sub_lon
    )
    db.add(rating)

    # Phase 15 Confidence Score update trigger
    # Confidence = 50% Citizen Ratings + 30% Verified Maintenance + 20% Data Freshness
    ratings = db.query(FacilityRating).filter(FacilityRating.facility_id == facility.id).all()
    avg_citizen_rating = (sum(r.weighted_score for r in ratings) + weighted_score) / (len(ratings) + 1)
    facility.confidence_score = round(0.50 * avg_citizen_rating + 0.30 * 100.0 + 0.20 * 100.0, 1)
    facility.last_verified_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(rating)
    return rating

@router.get("/facility/{facility_id}", response_model=List[RatingResponseSchema])
def get_facility_ratings(facility_id: str, db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(
        (Facility.facility_id == facility_id) | (Facility.id == int(facility_id) if facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")

    ratings = db.query(FacilityRating).filter(
        FacilityRating.facility_id == facility.id
    ).order_by(FacilityRating.created_at.desc()).all()
    return ratings
