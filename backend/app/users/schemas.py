from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from app.users.models import UserRole

class UserUpdateSchema(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    fcm_token: Optional[str] = None

class UserResponseSchema(BaseModel):
    id: int
    phone: Optional[str]
    email: Optional[str]
    full_name: Optional[str]
    role: UserRole
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
