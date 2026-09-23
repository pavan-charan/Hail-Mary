import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, Enum as SQLEnum, Text, Time
from sqlalchemy.orm import relationship
from app.database import Base

class FacilityType(str, enum.Enum):
    TOILET = "TOILET"
    DRINKING_WATER = "DRINKING_WATER"

class GenderAccess(str, enum.Enum):
    MALE = "MALE"
    FEMALE = "FEMALE"
    UNISEX = "UNISEX"

class FacilityStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    UNDER_MAINTENANCE = "UNDER_MAINTENANCE"
    CLOSED = "CLOSED"
    DEMOLISHED = "DEMOLISHED"

class Facility(Base):
    __tablename__ = "facilities"
    
    id = Column(Integer, primary_key=True, index=True)
    facility_id = Column(String(50), unique=True, index=True, nullable=False) # e.g. FAC-WARD12-TLT-001
    name = Column(String(150), nullable=False)
    facility_type = Column(SQLEnum(FacilityType), nullable=False, index=True)
    latitude = Column(Float, nullable=False, index=True)
    longitude = Column(Float, nullable=False, index=True)
    address = Column(Text, nullable=False)
    ward = Column(String(50), nullable=False, index=True)
    
    gender_access = Column(SQLEnum(GenderAccess), default=GenderAccess.UNISEX, nullable=False)
    wheelchair_accessible = Column(Boolean, default=False, nullable=False)
    water_availability = Column(Boolean, default=True, nullable=False)
    
    opening_time = Column(String(10), default="06:00")
    closing_time = Column(String(10), default="22:00")
    
    status = Column(SQLEnum(FacilityStatus), default=FacilityStatus.ACTIVE, nullable=False, index=True)
    qr_code_hash = Column(String(255), unique=True, nullable=True)
    
    confidence_score = Column(Float, default=100.0) # 0 to 100
    last_verified_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    # Relationships
    tickets = relationship("Ticket", back_populates="facility")
    ratings = relationship("FacilityRating", back_populates="facility")
    history_logs = relationship("FacilityHistory", back_populates="facility")
