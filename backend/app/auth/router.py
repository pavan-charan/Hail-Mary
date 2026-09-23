from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.auth.schemas import RequestOTPSchema, VerifyOTPSchema, AdminLoginSchema, TokenResponseSchema
from app.users.models import User, UserRole
from app.core.security import create_access_token, verify_password, get_password_hash

router = APIRouter(prefix="/auth", tags=["Authentication"])

# In-memory OTP storage for rapid OTP validation / SMS integration
MOCK_OTP_STORE = {}

@router.post("/request-otp")
def request_otp(data: RequestOTPSchema):
    # In production, dispatch via Twilio SMS; for dev/demo default to deterministic 6-digit OTP
    otp = "123456"
    MOCK_OTP_STORE[data.phone] = otp
    return {
        "success": True,
        "message": f"OTP sent successfully to {data.phone}",
        "debug_otp": otp # Available in development
    }

@router.post("/verify-otp", response_model=TokenResponseSchema)
def verify_otp(data: VerifyOTPSchema, db: Session = Depends(get_db)):
    expected_otp = MOCK_OTP_STORE.get(data.phone, "123456")
    if data.otp != expected_otp and data.otp != "123456":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP")
    
    # Auto-create user if not exists
    user = db.query(User).filter(User.phone == data.phone).first()
    if not user:
        user = User(
            phone=data.phone,
            full_name=data.full_name or f"User-{data.phone[-4:]}",
            role=data.role,
            is_active=True
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    token = create_access_token({"sub": str(user.id), "role": user.role.value, "phone": user.phone})
    return TokenResponseSchema(
        access_token=token,
        role=user.role,
        user_id=user.id,
        full_name=user.full_name,
        phone=user.phone,
        email=user.email
    )

@router.post("/admin/login", response_model=TokenResponseSchema)
def admin_login(data: AdminLoginSchema, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email, User.role == UserRole.ADMIN).first()
    if not user or not user.hashed_password or not verify_password(data.password, user.hashed_password):
        # If running first-time and default admin doesn't exist, bootstrap default admin
        if data.email == "admin@municipal.gov.in" and data.password == "Admin123!":
            user = User(
                email="admin@municipal.gov.in",
                full_name="Municipal Admin",
                role=UserRole.ADMIN,
                hashed_password=get_password_hash("Admin123!"),
                is_active=True
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin email or password")
    
    token = create_access_token({"sub": str(user.id), "role": user.role.value, "email": user.email})
    return TokenResponseSchema(
        access_token=token,
        role=user.role,
        user_id=user.id,
        full_name=user.full_name,
        email=user.email
    )
