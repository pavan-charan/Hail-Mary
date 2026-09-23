import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, Float, DateTime, Enum as SQLEnum, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class IssueCategory(str, enum.Enum):
    NO_WATER = "NO_WATER"
    LOCKED = "LOCKED"
    DIRTY = "DIRTY"
    BROKEN_SEAT = "BROKEN_SEAT"
    BAD_SMELL = "BAD_SMELL"
    LIGHT_ISSUE = "LIGHT_ISSUE"
    DRINKING_WATER_UNAVAILABLE = "DRINKING_WATER_UNAVAILABLE"

class TicketStatus(str, enum.Enum):
    TICKET_CREATED = "TICKET_CREATED"
    ASSIGNED = "ASSIGNED"
    REACHED = "REACHED"
    REPAIRING = "REPAIRING"
    COMPLETED = "COMPLETED"
    UNDER_VERIFICATION = "UNDER_VERIFICATION"
    RESOLVED = "RESOLVED"
    REJECTED = "REJECTED"

class TicketPriority(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class Ticket(Base):
    __tablename__ = "tickets"
    
    id = Column(Integer, primary_key=True, index=True)
    ticket_id = Column(String(50), unique=True, index=True, nullable=False) # e.g. TCK-2026-87421
    facility_id = Column(Integer, ForeignKey("facilities.id"), nullable=False, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    assigned_worker_id = Column(Integer, ForeignKey("local_body_workers.id"), nullable=True, index=True)
    
    issue_categories = Column(Text, nullable=False) # Comma-separated or JSON list of IssueCategory
    description = Column(Text, nullable=True)
    
    status = Column(SQLEnum(TicketStatus), default=TicketStatus.TICKET_CREATED, nullable=False, index=True)
    priority = Column(SQLEnum(TicketPriority), default=TicketPriority.MEDIUM, nullable=False)
    
    reporter_latitude = Column(Float, nullable=False)
    reporter_longitude = Column(Float, nullable=False)
    
    # Duplicate merging
    report_count = Column(Integer, default=1)
    is_merged = Column(Boolean, default=False)
    parent_ticket_id = Column(Integer, ForeignKey("tickets.id"), nullable=True)
    
    # SLA & Timers
    assigned_at = Column(DateTime, nullable=True)
    expected_sla_deadline = Column(DateTime, nullable=True)
    reached_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    
    # Worker completion submission details
    worker_notes = Column(Text, nullable=True)
    completion_latitude = Column(Float, nullable=True)
    completion_longitude = Column(Float, nullable=True)
    face_match_score = Column(Float, nullable=True)
    face_verified = Column(Boolean, default=False)
    
    # Admin rejection
    rejection_reason = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    # Relationships
    facility = relationship("Facility", back_populates="tickets")
    reporter = relationship("User", back_populates="tickets_reported", foreign_keys=[reporter_id])
    assigned_worker = relationship("LocalBodyWorker", back_populates="assigned_tickets")
    media = relationship("TicketMedia", back_populates="ticket")
    status_history = relationship("TicketStatusHistory", back_populates="ticket")
    sla_logs = relationship("SLALog", back_populates="ticket")

class MediaType(str, enum.Enum):
    BEFORE_PHOTO = "BEFORE_PHOTO"
    BEFORE_VIDEO = "BEFORE_VIDEO"
    AFTER_PHOTO = "AFTER_PHOTO"
    AFTER_VIDEO = "AFTER_VIDEO"
    FACE_PROOF = "FACE_PROOF"

class TicketMedia(Base):
    __tablename__ = "ticket_media"
    
    id = Column(Integer, primary_key=True, index=True)
    ticket_id = Column(Integer, ForeignKey("tickets.id"), nullable=False, index=True)
    media_type = Column(SQLEnum(MediaType), nullable=False)
    file_url = Column(String(500), nullable=False)
    captured_latitude = Column(Float, nullable=True)
    captured_longitude = Column(Float, nullable=True)
    captured_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_live_camera = Column(Boolean, default=True) # Must be True (no gallery upload)
    
    ticket = relationship("Ticket", back_populates="media")

class TicketStatusHistory(Base):
    __tablename__ = "ticket_status_history"
    
    id = Column(Integer, primary_key=True, index=True)
    ticket_id = Column(Integer, ForeignKey("tickets.id"), nullable=False, index=True)
    from_status = Column(String(50), nullable=True)
    to_status = Column(String(50), nullable=False)
    changed_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    
    ticket = relationship("Ticket", back_populates="status_history")
