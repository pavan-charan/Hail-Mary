from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class RatingCreateSchema(BaseModel):
    facility_id: str = Field(..., example="FAC-WARD12-TLT-001")
    user_id: int = Field(..., example=1)
    cleanliness: int = Field(..., ge=1, le=5, description="Cleanliness score (1-5)")
    water_availability: bool = Field(..., description="Water available True/False")
    safety: int = Field(..., ge=1, le=5, description="Safety score (1-5)")
    accessibility: float = Field(..., ge=0.0, le=1.0, description="1.0 for Yes, 0.5 for Partial, 0.0 for No")
    comments: Optional[str] = None
    is_qr_scanned: bool = False
    submission_latitude: Optional[float] = None
    submission_longitude: Optional[float] = None

class RatingResponseSchema(BaseModel):
    id: int
    facility_id: int
    user_id: int
    cleanliness: int
    water_availability: bool
    safety: int
    accessibility: float
    comments: Optional[str]
    weighted_score: float
    is_qr_verified: bool
    is_gps_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True
