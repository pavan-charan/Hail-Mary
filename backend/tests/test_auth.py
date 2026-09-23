import pytest
from fastapi import status
from app.users.models import UserRole

def test_citizen_passwordless_otp_flow(client):
    phone = "+919876500001"
    
    # 1. Request OTP
    req = client.post("/api/v1/auth/request-otp", json={"phone": phone, "role": "CITIZEN"})
    assert req.status_code == status.HTTP_200_OK
    assert req.json()["success"] is True

    # 2. Verify OTP (Auto creates user)
    verify = client.post("/api/v1/auth/verify-otp", json={
        "phone": phone,
        "otp": "123456",
        "full_name": "Priya Sharma",
        "role": "CITIZEN"
    })
    assert verify.status_code == status.HTTP_200_OK
    data = verify.json()
    assert data["role"] == "CITIZEN"
    assert data["full_name"] == "Priya Sharma"
    assert data["requires_face_enrollment"] is False
    assert "access_token" in data

def test_unregistered_worker_rejected(client):
    unregistered_phone = "+919876599999"
    
    # Attempting worker OTP request without admin pre-registration must fail with 403
    req = client.post("/api/v1/auth/request-otp", json={"phone": unregistered_phone, "role": "WORKER"})
    assert req.status_code == status.HTTP_403_FORBIDDEN
    assert "not registered as a municipal worker" in req.json()["detail"]

def test_worker_complete_enrollment_lifecycle(client):
    worker_phone = "+919876500002"
    worker_name = "Ramesh Kumar"
    
    # 1. Admin registers worker
    reg = client.post("/api/v1/workers/register", json={
        "phone": worker_phone,
        "full_name": worker_name,
        "ward": "Ward-12"
    })
    assert reg.status_code == status.HTTP_201_CREATED
    worker_info = reg.json()
    assert worker_info["face_enrolled"] is False
    assert worker_info["ward"] == "Ward-12"

    # 2. Worker requests OTP
    otp_req = client.post("/api/v1/auth/request-otp", json={"phone": worker_phone, "role": "WORKER"})
    assert otp_req.status_code == status.HTTP_200_OK

    # 3. Worker verifies OTP -> must return requires_face_enrollment: True
    verify = client.post("/api/v1/auth/verify-otp", json={
        "phone": worker_phone,
        "otp": "123456",
        "role": "WORKER"
    })
    assert verify.status_code == status.HTTP_200_OK
    data = verify.json()
    assert data["role"] == "WORKER"
    assert data["requires_face_enrollment"] is True

    # 4. Worker submits Face Enrollment (live selfie base64)
    enroll = client.post("/api/v1/auth/worker/enroll-face", json={
        "phone": worker_phone,
        "face_image_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
    })
    assert enroll.status_code == status.HTTP_200_OK
    activated_data = enroll.json()
    assert activated_data["requires_face_enrollment"] is False
    assert activated_data["is_active"] is True

def test_admin_email_password_login(client):
    # Invalid password
    bad_login = client.post("/api/v1/auth/admin/login", json={
        "email": "admin@municipal.gov.in",
        "password": "WrongPassword!"
    })
    assert bad_login.status_code == status.HTTP_401_UNAUTHORIZED

    # Valid admin login
    good_login = client.post("/api/v1/auth/admin/login", json={
        "email": "admin@municipal.gov.in",
        "password": "Admin123!"
    })
    assert good_login.status_code == status.HTTP_200_OK
    admin_data = good_login.json()
    assert admin_data["role"] == "ADMIN"
    assert "access_token" in admin_data

    # Test /auth/me with Bearer token
    headers = {"Authorization": f"Bearer {admin_data['access_token']}"}
    me_resp = client.get("/api/v1/auth/me", headers=headers)
    assert me_resp.status_code == status.HTTP_200_OK
    assert me_resp.json()["email"] == "admin@municipal.gov.in"
