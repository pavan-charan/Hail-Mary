from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid

from app.database import get_db
from app.workers.models import LocalBodyWorker
from app.sla.models import WorkerPenalty
from app.workers.schemas import WorkerRegisterSchema, WorkerEnrollFaceSchema, WorkerResponseSchema
from app.users.models import User, UserRole
from app.face_verification.service import extract_face_embedding

router = APIRouter(prefix="/workers", tags=["Workers"])

@router.post("/register", response_model=WorkerResponseSchema, status_code=status.HTTP_201_CREATED)
def register_worker(data: WorkerRegisterSchema, db: Session = Depends(get_db)):
    # Check if phone already registered
    existing_user = db.query(User).filter(User.phone == data.phone).first()
    if not existing_user:
        existing_user = User(
            phone=data.phone,
            full_name=data.full_name,
            role=UserRole.WORKER,
            is_active=True
        )
        db.add(existing_user)
        db.commit()
        db.refresh(existing_user)
    else:
        existing_user.role = UserRole.WORKER
        existing_user.full_name = data.full_name
        
    existing_worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.user_id == existing_user.id).first()
    if existing_worker:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Worker already exists for this user")
        
    worker_code = f"WRK-{data.ward.upper().replace(' ', '')}-{uuid.uuid4().hex[:4].upper()}"
    worker = LocalBodyWorker(
        user_id=existing_user.id,
        worker_code=worker_code,
        ward=data.ward,
        face_enrolled=False
    )
    db.add(worker)
    db.commit()
    db.refresh(worker)
    
    return WorkerResponseSchema(
        id=worker.id,
        user_id=worker.user_id,
        worker_code=worker.worker_code,
        ward=worker.ward,
        full_name=existing_user.full_name,
        phone=existing_user.phone,
        face_enrolled=worker.face_enrolled,
        active_workload_count=worker.active_workload_count,
        total_resolved_count=worker.total_resolved_count,
        penalty_count=worker.penalty_count
    )

@router.post("/enroll-face")
def enroll_face(data: WorkerEnrollFaceSchema, db: Session = Depends(get_db)):
    worker = db.query(LocalBodyWorker).filter(LocalBodyWorker.id == data.worker_id).first()
    if not worker:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Worker not found")
        
    embedding = extract_face_embedding(data.face_image_base64)
    if not embedding:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No face detected in enrollment image")
        
    worker.face_embedding = embedding
    worker.face_enrolled = True
    db.commit()
    return {"success": True, "message": "Face enrollment successful. Worker account activated."}

@router.get("", response_model=List[WorkerResponseSchema])
def list_workers(ward: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(LocalBodyWorker)
    if ward:
        query = query.filter(LocalBodyWorker.ward == ward)
    workers = query.all()
    
    results = []
    for w in workers:
        results.append(WorkerResponseSchema(
            id=w.id,
            user_id=w.user_id,
            worker_code=w.worker_code,
            ward=w.ward,
            full_name=w.user.full_name if w.user else None,
            phone=w.user.phone if w.user else None,
            face_enrolled=w.face_enrolled,
            active_workload_count=w.active_workload_count,
            total_resolved_count=w.total_resolved_count,
            penalty_count=w.penalty_count,
            current_latitude=w.current_latitude,
            current_longitude=w.current_longitude
        ))
    return results
