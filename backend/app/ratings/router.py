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
    facility = db.query(Facility).filter(
        (Facility.facility_id == data.facility_id) | (Facility.id == int(data.facility_id) if data.facility_id.isdigit() else False)
    ).first()
    if not facility:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found")
        
    # Validation Rule: QR scanned OR GPS <= 30 meters
    is_gps_verified = False
    if data.submission_latitude is not None and data.submission_longitude is not None:
        dist = calculate_haversine_distance(
            data.submission_latitude, data.submission_longitude,
            facility.latitude, facility.longitude
        )
        if dist <= settings.GEO_FENCE_MAX_DISTANCE_METERS:
            is_gps_verified = True
            
    if not data.is_qr_scanned and not is_gps_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Rating only allowed via QR scan or within {settings.GEO_FENCE_MAX_DISTANCE_METERS} meters of facility"
        )
        
    # Rate Limit Rule: 1 rating per 24 hours per facility per user
    cooldown = datetime.now(timezone.utc) - timedelta(hours=settings.RATING_COOLDOWN_HOURS)
    existing_rating = db.query(FacilityRating).filter(
        FacilityRating.facility_id == facility.id,
        FacilityRating.user_id == data.user_id,
        FacilityRating.created_at >= cooldown
    ).first()
    if existing_rating:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="You can only rate this facility once every 24 hours"
        )
        
    weighted_score = compute_rating_score(data.cleanliness, data.water_availability, data.safety, data.accessibility)
    
    rating = FacilityRating(
        facility_id=facility.id,
        user_id=data.user_id,
        cleanliness=data.cleanliness,
        water_availability=data.water_availability,
        safety=data.safety,
        accessibility=data.accessibility,
        comments=data.comments,
        weighted_score=weighted_score,
        is_qr_verified=data.is_qr_scanned,
        is_gps_verified=is_gps_verified,
        submission_latitude=data.submission_latitude,
        submission_longitude=data.submission_longitude
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
