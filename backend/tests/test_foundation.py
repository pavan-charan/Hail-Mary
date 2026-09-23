from fastapi import status

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "healthy"
    assert "Smart Public Sanitation" in data["app_name"]

def test_auth_request_and_verify_otp(client):
    # Request OTP
    req_resp = client.post("/api/v1/auth/request-otp", json={"phone": "+919999988888"})
    assert req_resp.status_code == status.HTTP_200_OK
    assert req_resp.json()["success"] is True

    # Verify OTP
    verify_resp = client.post("/api/v1/auth/verify-otp", json={
        "phone": "+919999988888",
        "otp": "123456",
        "full_name": "Test Citizen",
        "role": "CITIZEN"
    })
    assert verify_resp.status_code == status.HTTP_200_OK
    token_data = verify_resp.json()
    assert "access_token" in token_data
    assert token_data["role"] == "CITIZEN"

def test_facility_lifecycle_and_qr(client):
    # Create facility
    facility_data = {
        "name": "Central Bus Stand Restroom",
        "facility_type": "TOILET",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "address": "Platform 1, Central Bus Stand",
        "ward": "Ward-04",
        "gender_access": "UNISEX",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "05:00",
        "closing_time": "23:00"
    }
    create_resp = client.post("/api/v1/facilities", json=facility_data)
    assert create_resp.status_code == status.HTTP_201_CREATED
    facility = create_resp.json()
    facility_id = facility["facility_id"]
    assert facility_id.startswith("FAC-WARD04-TLT-")

    # QR Scan
    scan_resp = client.get(f"/api/v1/qr/scan/{facility_id}")
    assert scan_resp.status_code == status.HTTP_200_OK
    scan_data = scan_resp.json()
    assert scan_data["is_operational"] is True
    assert "REPORT_ISSUE" in scan_data["available_actions"]

    # Demolish facility
    demolish_resp = client.post(f"/api/v1/facilities/{facility_id}/demolish")
    assert demolish_resp.status_code == status.HTTP_200_OK
    assert demolish_resp.json()["status"] == "DEMOLISHED"

    # Scan demolished facility
    demolished_scan = client.get(f"/api/v1/qr/scan/{facility_id}")
    assert demolished_scan.status_code == status.HTTP_200_OK
    dem_data = demolished_scan.json()
    assert dem_data["is_operational"] is False
    assert dem_data["message"] == "This facility is no longer operational."

    # Restore facility
    restore_resp = client.post(f"/api/v1/facilities/{facility_id}/restore")
    assert restore_resp.status_code == status.HTTP_200_OK
    assert restore_resp.json()["status"] == "ACTIVE"
