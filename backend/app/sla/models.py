import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum as SQLEnum, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from app.database import Base

class SLAStep(str, enum.Enum):
    ASSIGNMENT = "ASSIGNMENT"
    REMINDER_24H = "REMINDER_24H"
    AI_VOICE_CALL_1 = "AI_VOICE_CALL_1"
    AI_VOICE_CALL_2 = "AI_VOICE_CALL_2"
    AI_VOICE_CALL_3 = "AI_VOICE_CALL_3"
    PENALTY_AND_REASSIGN = "PENALTY_AND_REASSIGN"

class SLALog(Base):
    __tablename__ = "sla_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    ticket_id = Column(Integer, ForeignKey("tickets.id"), nullable=False, index=True)
    step = Column(SQLEnum(SLAStep), nullable=False)
    triggered_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    status_response = Column(String(100), nullable=True) # e.g. "ANSWERED", "MISSED", "DELIVERED"
    details = Column(Text, nullable=True)
    
    ticket = relationship("Ticket", back_populates="sla_logs")

class WorkerPenalty(Base):
    __tablename__ = "penalties"
    
    id = Column(Integer, primary_key=True, index=True)
    worker_id = Column(Integer, ForeignKey("local_body_workers.id"), nullable=False, index=True)
    ticket_id = Column(Integer, ForeignKey("tickets.id"), nullable=False, index=True)
    reason = Column(String(255), nullable=False)
    penalty_points = Column(Integer, default=10)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    
    worker = relationship("LocalBodyWorker", back_populates="penalties")
