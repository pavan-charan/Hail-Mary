import pytest
from fastapi import status

def test_qr_generation_and_active_facility_scan(client):
    # 1. Create active facility
    payload = {
        "name": "MG Road North Metro Toilet",
        "facility_type": "TOILET",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "address": "Opposite Metro Gate 1",
        "ward": "Ward-12",
        "gender_access": "UNISEX",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "06:00",
        "closing_time": "22:00"
    }
    create_resp = client.post("/api/v1/facilities", json=payload)
    facility_id = create_resp.json()["facility_id"]

    # 2. Get QR image metadata
    qr_img_resp = client.get(f"/api/v1/qr/facility/{facility_id}/image")
    assert qr_img_resp.status_code == status.HTTP_200_OK
    qr_data = qr_img_resp.json()
    assert qr_data["qr_payload"] == facility_id # Contains strictly Facility ID
    assert "data:image/png;base64," in qr_data["qr_base64_png"]

    # 3. Scan QR Code
    scan_resp = client.get(f"/api/v1/qr/scan/{facility_id}?user_lat=12.9716&user_lon=77.5946")
    assert scan_resp.status_code == status.HTTP_200_OK
    scan_result = scan_resp.json()
    assert scan_result["is_operational"] is True
    assert scan_result["facility"]["facility_id"] == facility_id
    assert "REPORT_ISSUE" in scan_result["available_actions"]
    assert "RATE_FACILITY" in scan_result["available_actions"]

def test_qr_scan_demolished_facility_guard(client):
    # 1. Create a facility and an alternative facility nearby
    target_resp = client.post("/api/v1/facilities", json={
        "name": "Old Market Restroom",
        "facility_type": "TOILET",
        "latitude": 12.9700,
        "longitude": 77.5900,
        "address": "Market Street Lane 1",
        "ward": "Ward-12",
        "gender_access": "UNISEX",
        "wheelchair_accessible": False,
        "water_availability": True,
        "opening_time": "06:00",
        "closing_time": "20:00"
    })
    target_id = target_resp.json()["facility_id"]

    alt_resp = client.post("/api/v1/facilities", json={
        "name": "New Modern Sanitary Complex",
        "facility_type": "TOILET",
        "latitude": 12.9710,
        "longitude": 77.5910,
        "address": "Market Main Avenue",
        "ward": "Ward-12",
        "gender_access": "UNISEX",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "05:00",
        "closing_time": "23:00"
    })
    alt_id = alt_resp.json()["facility_id"]

    # 2. Demolish target facility
    client.post(f"/api/v1/facilities/{target_id}/demolish", json={"reason": "Asset decommissioned"})

    # 3. Scan demolished QR
    demolished_scan = client.get(f"/api/v1/qr/scan/{target_id}?user_lat=12.9700&user_lon=77.5900")
    assert demolished_scan.status_code == status.HTTP_200_OK
    data = demolished_scan.json()
    assert data["is_operational"] is False
    assert data["status"] == "DEMOLISHED"
    assert data["message"] == "This facility is no longer operational."
    assert "nearest_alternatives" in data
    assert len(data["nearest_alternatives"]) >= 1
    # Check that alternative is operational
    alt_facility_ids = [alt["facility_id"] for alt in data["nearest_alternatives"]]
    assert alt_id in alt_facility_ids

def test_qr_scan_invalid_facility_id(client):
    invalid_resp = client.get("/api/v1/qr/scan/FAC-INVALID-CODE-999")
    assert invalid_resp.status_code == status.HTTP_404_NOT_FOUND
    assert "Invalid QR Code" in invalid_resp.json()["detail"]
