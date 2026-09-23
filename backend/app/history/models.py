import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class FacilityAction(str, enum.Enum):
    CREATED = "CREATED"
    UPDATED = "UPDATED"
    STATUS_CHANGED = "STATUS_CHANGED"
    DEMOLISHED = "DEMOLISHED"
    RESTORED = "RESTORED"

class FacilityHistory(Base):
    __tablename__ = "facility_history"
    
    id = Column(Integer, primary_key=True, index=True)
    facility_id = Column(Integer, ForeignKey("facilities.id"), nullable=False, index=True)
    action = Column(SQLEnum(FacilityAction), nullable=False)
    performed_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    previous_state = Column(Text, nullable=True) # JSON snapshot
    new_state = Column(Text, nullable=True)      # JSON snapshot
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    
    facility = relationship("Facility", back_populates="history_logs")
