from pydantic import BaseModel, Field, root_validator
from typing import Optional, Union
from datetime import datetime

class RatingCreateSchema(BaseModel):
    facility_id: Union[str, int] = Field(..., example="FAC-WARD12-TLT-001")
    user_id: Optional[int] = Field(1, example=1)
    cleanliness: Optional[int] = Field(4, ge=1, le=5, description="Cleanliness score (1-5)")
    cleanliness_rating: Optional[int] = None
    water_availability: Optional[bool] = Field(True, description="Water available True/False")
    water_availability_rating: Optional[int] = None
    safety: Optional[int] = Field(4, ge=1, le=5, description="Safety score (1-5)")
    accessibility: Optional[float] = Field(1.0, ge=0.0, le=1.0, description="1.0 for Yes, 0.5 for Partial, 0.0 for No")
    comments: Optional[str] = None
    feedback_text: Optional[str] = None
    is_qr_scanned: bool = False
    submission_latitude: Optional[float] = None
    submission_longitude: Optional[float] = None
    user_latitude: Optional[float] = None
    user_longitude: Optional[float] = None

    @root_validator(pre=True)
    def unify_aliases(cls, values):
        if not isinstance(values, dict):
            return values
        if 'cleanliness' not in values and 'cleanliness_rating' in values:
            values['cleanliness'] = values['cleanliness_rating']
        if 'comments' not in values and 'feedback_text' in values:
            values['comments'] = values['feedback_text']
        if 'submission_latitude' not in values and 'user_latitude' in values:
            values['submission_latitude'] = values['user_latitude']
        if 'submission_longitude' not in values and 'user_longitude' in values:
            values['submission_longitude'] = values['user_longitude']
        if 'water_availability' not in values:
            if 'running_water' in values:
                values['water_availability'] = bool(values['running_water'])
            elif 'water_availability_rating' in values:
                values['water_availability'] = (values['water_availability_rating'] >= 3)
        return values

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
