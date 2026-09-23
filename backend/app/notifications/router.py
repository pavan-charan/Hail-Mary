from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.notifications.models import Notification
from app.notifications.schemas import NotificationResponseSchema

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("", response_model=List[NotificationResponseSchema])
def list_notifications(user_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(Notification)
    if user_id is not None:
        query = query.filter(Notification.user_id == user_id)
    return query.order_by(Notification.created_at.desc()).all()

@router.get("/user/{user_id}", response_model=List[NotificationResponseSchema])
def get_user_notifications(user_id: int, db: Session = Depends(get_db)):
    return db.query(Notification).filter(Notification.user_id == user_id).order_by(Notification.created_at.desc()).all()

@router.post("/{notification_id}/read")
@router.patch("/{notification_id}/read")
def mark_as_read(notification_id: int, db: Session = Depends(get_db)):
    notif = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notif:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    notif.is_read = True
    db.commit()
    return {"success": True, "id": notification_id, "is_read": True}

@router.post("/user/{user_id}/read-all")
@router.patch("/user/{user_id}/read-all")
@router.patch("/mark-all-read")
def mark_all_as_read(user_id: Optional[int] = 1, db: Session = Depends(get_db)):
    db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False
    ).update({"is_read": True})
    db.commit()
    return {"success": True, "message": "All notifications marked as read"}

