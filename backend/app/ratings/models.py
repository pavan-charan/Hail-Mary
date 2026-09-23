from datetime import datetime, timezone
from sqlalchemy import Column, Integer, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class FacilityRating(Base):
    __tablename__ = "ratings"
    
    id = Column(Integer, primary_key=True, index=True)
    facility_id = Column(Integer, ForeignKey("facilities.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Rating factors
    cleanliness = Column(Integer, nullable=False) # 1 to 5
    water_availability = Column(Boolean, nullable=False) # True / False
    safety = Column(Integer, nullable=False) # 1 to 5
    accessibility = Column(Float, nullable=False) # 1.0 (Yes), 0.5 (Partial), 0.0 (No)
    
    comments = Column(Text, nullable=True)
    weighted_score = Column(Float, nullable=False) # Computed score (0 - 100)
    
    # Verification mode: QR scanned or GPS <= 30m
    is_qr_verified = Column(Boolean, default=False)
    is_gps_verified = Column(Boolean, default=False)
    submission_latitude = Column(Float, nullable=True)
    submission_longitude = Column(Float, nullable=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    
    facility = relationship("Facility", back_populates="ratings")
    user = relationship("User", back_populates="ratings")
