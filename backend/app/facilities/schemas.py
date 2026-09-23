from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from app.facilities.models import FacilityType, GenderAccess, FacilityStatus

class FacilityCreateSchema(BaseModel):
    name: str = Field(..., example="MG Road Public Restroom")
    facility_type: FacilityType = FacilityType.TOILET
    latitude: float = Field(..., example=12.9716)
    longitude: float = Field(..., example=77.5946)
    address: str = Field(..., example="Next to Metro Station Gate 2, MG Road")
    ward: str = Field(..., example="Ward-12")
    gender_access: GenderAccess = GenderAccess.UNISEX
    wheelchair_accessible: bool = True
    water_availability: bool = True
    opening_time: str = "06:00"
    closing_time: str = "22:00"

class FacilityUpdateSchema(BaseModel):
    name: Optional[str] = None
    gender_access: Optional[GenderAccess] = None
    wheelchair_accessible: Optional[bool] = None
    water_availability: Optional[bool] = None
    opening_time: Optional[str] = None
    closing_time: Optional[str] = None
    status: Optional[FacilityStatus] = None

class FacilityResponseSchema(BaseModel):
    id: int
    facility_id: str
    name: str
    facility_type: FacilityType
    latitude: float
    longitude: float
    address: str
    ward: str
    gender_access: GenderAccess
    wheelchair_accessible: bool
    water_availability: bool
    opening_time: str
    closing_time: str
    status: FacilityStatus
    confidence_score: float
    last_verified_at: Optional[datetime]
    created_at: datetime
    
    # Computed fields for Citizen discovery
    distance_meters: Optional[float] = None
    walking_time_minutes: Optional[int] = None

    class Config:
        from_attributes = True
