import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class NotificationType(str, enum.Enum):
    TICKET_CREATED = "TICKET_CREATED"
    ASSIGNED = "ASSIGNED"
    REACHED = "REACHED"
    REPAIRING = "REPAIRING"
    COMPLETED = "COMPLETED"
    UNDER_VERIFICATION = "UNDER_VERIFICATION"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"
    SLA_REMINDER = "SLA_REMINDER"
    PENALTY_ALERT = "PENALTY_ALERT"

class Notification(Base):
    __tablename__ = "notifications"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    notification_type = Column(SQLEnum(NotificationType), nullable=False)
    reference_id = Column(String(50), nullable=True) # e.g. ticket_id or facility_id
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    
    user = relationship("User", back_populates="notifications")
