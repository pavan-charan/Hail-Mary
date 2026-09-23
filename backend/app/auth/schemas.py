from pydantic import BaseModel, Field
from typing import Optional
from app.users.models import UserRole

class RequestOTPSchema(BaseModel):
    phone: str = Field(..., example="+919876543210")

class VerifyOTPSchema(BaseModel):
    phone: str = Field(..., example="+919876543210")
    otp: str = Field(..., example="123456")
    full_name: Optional[str] = None
    role: UserRole = UserRole.CITIZEN

class AdminLoginSchema(BaseModel):
    email: str = Field(..., example="admin@municipal.gov.in")
    password: str = Field(..., example="AdminSecurePassword123!")

class TokenResponseSchema(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    user_id: int
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
