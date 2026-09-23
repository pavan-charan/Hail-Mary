import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class LocalBodyWorker(Base):
    __tablename__ = "local_body_workers"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    worker_code = Column(String(50), unique=True, index=True, nullable=False) # e.g. WRK-2026-004
    ward = Column(String(50), nullable=False, index=True)
    
    face_enrolled = Column(Boolean, default=False)
    face_embedding = Column(Text, nullable=True) # JSON or serialized vector
    
    active_workload_count = Column(Integer, default=0)
    total_resolved_count = Column(Integer, default=0)
    penalty_count = Column(Integer, default=0)
    
    current_latitude = Column(Float, nullable=True)
    current_longitude = Column(Float, nullable=True)
    last_location_updated_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    
    # Relationships
    user = relationship("User", back_populates="worker_profile")
    assigned_tickets = relationship("Ticket", back_populates="assigned_worker")
    penalties = relationship("WorkerPenalty", back_populates="worker")
