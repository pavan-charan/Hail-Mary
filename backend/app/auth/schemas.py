from pydantic import BaseModel, Field
from typing import Optional
from app.users.models import UserRole

class RequestOTPSchema(BaseModel):
    phone: str = Field(..., json_schema_extra={"example": "+919876543210"})
    role: UserRole = UserRole.CITIZEN

class VerifyOTPSchema(BaseModel):
    phone: str = Field(..., json_schema_extra={"example": "+919876543210"})
    otp: str = Field(..., json_schema_extra={"example": "123456"})
    full_name: Optional[str] = None
    role: UserRole = UserRole.CITIZEN

class WorkerFaceEnrollmentRequest(BaseModel):
    phone: str = Field(..., json_schema_extra={"example": "+919876543210"})
    face_image_base64: str

class AdminLoginSchema(BaseModel):
    email: str = Field(..., json_schema_extra={"example": "admin@municipal.gov.in"})
    password: str = Field(..., json_schema_extra={"example": "Admin123!"})

class TokenResponseSchema(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    user_id: int
    worker_id: Optional[int] = None
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    requires_face_enrollment: bool = False
    is_active: bool = True
