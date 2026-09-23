import pytest
from fastapi import status
from app.facilities.models import FacilityStatus, FacilityType, GenderAccess

def test_create_facility_with_auto_generated_id_and_qr(client):
    payload = {
        "name": "Koramangala Public Sanitation Complex",
        "facility_type": "TOILET",
        "latitude": 12.9352,
        "longitude": 77.6245,
        "address": "80 Feet Road, Koramangala 4th Block",
        "ward": "Ward-151",
        "gender_access": "UNISEX",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "06:00",
        "closing_time": "22:30"
    }
    resp = client.post("/api/v1/facilities", json=payload)
    assert resp.status_code == status.HTTP_201_CREATED
    data = resp.json()
    
    assert data["name"] == payload["name"]
    assert data["facility_id"].startswith("FAC-WARD151-TLT-")
    assert data["status"] == "ACTIVE"
    assert data["wheelchair_accessible"] is True
    assert data["confidence_score"] == 100.0

    # Verify QR image is generated and downloadable
    qr_resp = client.get(f"/api/v1/qr/facility/{data['facility_id']}/image")
    assert qr_resp.status_code == status.HTTP_200_OK
    assert "data:image/png;base64," in qr_resp.json()["qr_base64_png"]

def test_edit_facility_and_audit_history(client):
    # 1. Create drinking water station
    payload = {
        "name": "Indiranagar 100ft Rd Water Point",
        "facility_type": "DRINKING_WATER",
        "latitude": 12.9784,
        "longitude": 77.6408,
        "address": "Near 12th Main Junction, Indiranagar",
        "ward": "Ward-74",
        "gender_access": "UNISEX",
        "wheelchair_accessible": False,
        "water_availability": True,
        "opening_time": "05:00",
        "closing_time": "23:00"
    }
    create_resp = client.post("/api/v1/facilities", json=payload)
    facility_id = create_resp.json()["facility_id"]

    # 2. Edit timings, accessibility, and status
    update_payload = {
        "opening_time": "04:30",
        "closing_time": "23:59",
        "wheelchair_accessible": True,
        "status": "UNDER_MAINTENANCE"
    }
    update_resp = client.put(f"/api/v1/facilities/{facility_id}", json=update_payload)
    assert update_resp.status_code == status.HTTP_200_OK
    updated = update_resp.json()
    assert updated["opening_time"] == "04:30"
    assert updated["wheelchair_accessible"] is True
    assert updated["status"] == "UNDER_MAINTENANCE"

    # 3. Check audit history logs
    hist_resp = client.get(f"/api/v1/facilities/{facility_id}/history")
    assert hist_resp.status_code == status.HTTP_200_OK
    history_logs = hist_resp.json()
    assert len(history_logs) >= 2 # CREATED + UPDATED
    actions = [h["action"] for h in history_logs]
    assert "CREATED" in actions
    assert "UPDATED" in actions

def test_demolition_rules_and_restoration(client):
    # 1. Create a facility
    payload = {
        "name": "Commercial Street Temporary Toilet",
        "facility_type": "TOILET",
        "latitude": 12.9822,
        "longitude": 77.6083,
        "address": "Commercial Street Lane 3",
        "ward": "Ward-110",
        "gender_access": "MALE",
        "wheelchair_accessible": False,
        "water_availability": True,
        "opening_time": "08:00",
        "closing_time": "20:00"
    }
    create_resp = client.post("/api/v1/facilities", json=payload)
    facility_id = create_resp.json()["facility_id"]

    # 2. Demolish facility with a reason
    demolish_resp = client.post(f"/api/v1/facilities/{facility_id}/demolish", json={
        "reason": "Road widening and drainage restructuring project"
    })
    assert demolish_resp.status_code == status.HTTP_200_OK
    assert demolish_resp.json()["status"] == "DEMOLISHED"

    # 3. Rule: Demolished facility is HIDDEN from standard discovery query
    public_list = client.get("/api/v1/facilities").json()
    public_ids = [f["facility_id"] for f in public_list]
    assert facility_id not in public_ids

    # 4. Rule: Admin can view demolished facilities when explicitly requested
    admin_list = client.get("/api/v1/facilities?include_demolished=true").json()
    admin_ids = [f["facility_id"] for f in admin_list]
    assert facility_id in admin_ids

    # 5. Rule: QR scanning returns demolished notice & nearest operational alternatives
    scan_resp = client.get(f"/api/v1/qr/scan/{facility_id}")
    assert scan_resp.status_code == status.HTTP_200_OK
    scan_data = scan_resp.json()
    assert scan_data["is_operational"] is False
    assert scan_data["status"] == "DEMOLISHED"
    assert scan_data["message"] == "This facility is no longer operational."
    assert "nearest_alternatives" in scan_data

    # 6. Restore facility
    restore_resp = client.post(f"/api/v1/facilities/{facility_id}/restore", json={
        "reason": "Construction finished, facility re-opened for public"
    })
    assert restore_resp.status_code == status.HTTP_200_OK
    assert restore_resp.json()["status"] == "ACTIVE"

    # 7. Restored facility is visible again in default discovery
    restored_list = client.get("/api/v1/facilities").json()
    restored_ids = [f["facility_id"] for f in restored_list]
    assert facility_id in restored_ids
