import pytest
from fastapi import status
from datetime import datetime

def test_raise_ticket_with_multiple_issues_and_camera_proof(client):
    # 1. Create a facility
    facility_resp = client.post("/api/v1/facilities", json={
        "name": "Majestic Bus Station Restroom",
        "facility_type": "TOILET",
        "latitude": 12.9767,
        "longitude": 77.5713,
        "address": "Platform 5, KSRTC Concourse",
        "ward": "Ward-93",
        "gender_access": "UNISEX",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "05:00",
        "closing_time": "23:59"
    })
    facility_id = facility_resp.json()["facility_id"]

    # 2. Raise Ticket with multiple issues and live camera photo proof
    ticket_payload = {
        "facility_id": facility_id,
        "reporter_id": 1,
        "issue_categories": ["NO_WATER", "DIRTY", "BAD_SMELL"],
        "description": "Main water valve appears stuck and floor needs immediate sanitation",
        "reporter_latitude": 12.9768,
        "reporter_longitude": 77.5714,
        "media_url": "https://storage.googleapis.com/civic-media/live_proof_12345.jpg",
        "is_live_camera": True
    }
    resp = client.post("/api/v1/tickets", json=ticket_payload)
    assert resp.status_code == status.HTTP_201_CREATED
    data = resp.json()

    # Verify auto-generated Ticket ID format
    assert data["ticket_id"].startswith("TCK-")
    assert len(data["issue_categories"]) == 3
    assert "NO_WATER" in data["issue_categories"]
    assert "DIRTY" in data["issue_categories"]
    assert "BAD_SMELL" in data["issue_categories"]

    # Verify auto-attached metadata
    assert data["facility_custom_id"] == facility_id
    assert data["reporter_id"] == 1
    assert data["reporter_latitude"] == 12.9768
    assert data["reporter_longitude"] == 77.5714
    assert data["status"] in ["TICKET_CREATED", "ASSIGNED"]
    assert data["priority"] == "HIGH" # High priority triggered by NO_WATER

def test_raise_ticket_rejects_gallery_uploads(client):
    # Prohibit gallery uploads
    ticket_payload = {
        "facility_id": "FAC-WARD12-TLT-A8F1",
        "reporter_id": 1,
        "issue_categories": ["BROKEN_SEAT"],
        "description": "Selected photo from saved gallery album",
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "media_url": "file:///sdcard/Download/saved_photo.jpg",
        "is_live_camera": False # Gallery upload attempt
    }
    resp = client.post("/api/v1/tickets", json=ticket_payload)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "Gallery uploads are strictly prohibited" in resp.json()["detail"]

def test_raise_ticket_validation_errors(client):
    # Empty issue categories must be rejected
    empty_issues = {
        "facility_id": "FAC-WARD12-TLT-A8F1",
        "reporter_id": 1,
        "issue_categories": [],
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    }
    resp = client.post("/api/v1/tickets", json=empty_issues)
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY or resp.status_code == status.HTTP_400_BAD_REQUEST
