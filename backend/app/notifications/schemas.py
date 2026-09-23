from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.notifications.models import NotificationType

class NotificationResponseSchema(BaseModel):
    id: int
    user_id: int
    title: str
    body: str
    notification_type: NotificationType
    reference_id: Optional[str]
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True
