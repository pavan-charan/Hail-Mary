from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from app.database import Base

class QRCodeRecord(Base):
    __tablename__ = "qr_codes"
    
    id = Column(Integer, primary_key=True, index=True)
    facility_id = Column(Integer, ForeignKey("facilities.id"), unique=True, nullable=False)
    facility_custom_id = Column(String(50), unique=True, index=True, nullable=False) # e.g. FAC-WARD12-TLT-001
    qr_payload = Column(String(255), nullable=False) # Contains only Facility ID as per requirement
    is_active = Column(Boolean, default=True) # Set to False when facility is demolished
    generated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
