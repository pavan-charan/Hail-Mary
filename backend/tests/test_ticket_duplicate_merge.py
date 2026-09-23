import pytest
import uuid
from fastapi.testclient import TestClient
from app.facilities.models import Facility, FacilityType, FacilityStatus
from app.users.models import User, UserRole
from app.tickets.models import Ticket, TicketStatus, TicketPriority

@pytest.fixture
def setup_civic_data(db_session):
    uid = uuid.uuid4().hex[:6]
    # Create test users
    citizen1 = User(phone=f"+919999{uid[:4]}01", full_name="Citizen One", role=UserRole.CITIZEN, is_active=True)
    citizen2 = User(phone=f"+919999{uid[:4]}02", full_name="Citizen Two", role=UserRole.CITIZEN, is_active=True)
    citizen3 = User(phone=f"+919999{uid[:4]}03", full_name="Citizen Three", role=UserRole.CITIZEN, is_active=True)
    
    # Create test facilities
    fac1 = Facility(
        facility_id=f"FAC-W01-TLT-{uid[:4]}1",
        name="MG Road Public Restroom",
        facility_type=FacilityType.TOILET,
        ward="Ward-01",
        address="MG Road, Bangalore",
        latitude=12.9716,
        longitude=77.5946,
        status=FacilityStatus.ACTIVE
    )
    fac2 = Facility(
        facility_id=f"FAC-W01-WTR-{uid[:4]}2",
        name="Indiranagar Water ATM",
        facility_type=FacilityType.DRINKING_WATER,
        ward="Ward-01",
        address="Indiranagar 100ft Road",
        latitude=12.9780,
        longitude=77.6400,
        status=FacilityStatus.ACTIVE
    )
    db_session.add_all([citizen1, citizen2, citizen3, fac1, fac2])
    db_session.commit()
    return {"c1": citizen1, "c2": citizen2, "c3": citizen3, "f1": fac1, "f2": fac2}

def test_duplicate_ticket_auto_merging(client: TestClient, db_session, setup_civic_data):
    data = setup_civic_data
    
    # 1. Citizen 1 raises initial ticket
    payload_1 = {
        "facility_id": data["f1"].facility_id,
        "reporter_id": data["c1"].id,
        "issue_categories": ["DIRTY", "BAD_SMELL"],
        "description": "Floor is muddy and there is a bad smell.",
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "media_url": "https://storage.googleapis.com/hail-mary/proof1.jpg",
        "is_live_camera": True
    }
    r1 = client.post("/api/v1/tickets", json=payload_1)
    assert r1.status_code == 201
    res1 = r1.json()
    ticket_1_id = res1["ticket_id"]
    assert res1["report_count"] == 1
    assert set(res1["issue_categories"]) == {"DIRTY", "BAD_SMELL"}

    # 2. Citizen 2 raises overlapping ticket for the SAME facility
    payload_2 = {
        "facility_id": data["f1"].facility_id,
        "reporter_id": data["c2"].id,
        "issue_categories": ["BAD_SMELL", "BROKEN_SEAT"],
        "description": "Very bad smell and toilet seat is cracked.",
        "reporter_latitude": 12.9717,
        "reporter_longitude": 77.5947,
        "media_url": "https://storage.googleapis.com/hail-mary/proof2.jpg",
        "is_live_camera": True
    }
    r2 = client.post("/api/v1/tickets", json=payload_2)
    assert r2.status_code == 201
    res2 = r2.json()
    
    # Verify auto-merge behavior
    assert res2["ticket_id"] == ticket_1_id
    assert res2["is_merged"] is True
    assert res2["report_count"] == 2
    # Combined issues union: DIRTY, BAD_SMELL, BROKEN_SEAT
    assert "DIRTY" in res2["issue_categories"]
    assert "BAD_SMELL" in res2["issue_categories"]
    assert "BROKEN_SEAT" in res2["issue_categories"]

    # 3. Citizen 3 raises another overlapping report
    payload_3 = {
        "facility_id": data["f1"].facility_id,
        "reporter_id": data["c3"].id,
        "issue_categories": ["DIRTY"],
        "description": "Still dirty.",
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    }
    r3 = client.post("/api/v1/tickets", json=payload_3)
    assert r3.status_code == 201
    res3 = r3.json()
    assert res3["ticket_id"] == ticket_1_id
    assert res3["report_count"] == 3

    # 4. Verify in DB only 1 ticket row exists for the facility
    tickets_in_db = db_session.query(Ticket).filter(Ticket.facility_id == data["f1"].id).all()
    assert len(tickets_in_db) == 1
    assert tickets_in_db[0].report_count == 3

def test_priority_escalation_on_merge(client: TestClient, db_session, setup_civic_data):
    data = setup_civic_data
    
    # First report has standard priority (MEDIUM)
    r1 = client.post("/api/v1/tickets", json={
        "facility_id": data["f1"].facility_id,
        "reporter_id": data["c1"].id,
        "issue_categories": ["DIRTY"],
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    })
    assert r1.status_code == 201
    assert r1.json()["priority"] == "MEDIUM"

    # Second report brings in critical NO_WATER issue -> Escalates priority to HIGH
    r2 = client.post("/api/v1/tickets", json={
        "facility_id": data["f1"].facility_id,
        "reporter_id": data["c2"].id,
        "issue_categories": ["DIRTY", "NO_WATER"],
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    })
    assert r2.status_code == 201
    assert r2.json()["priority"] == "HIGH"
    assert r2.json()["report_count"] == 2

def test_different_facilities_do_not_merge(client: TestClient, db_session, setup_civic_data):
    data = setup_civic_data
    
    r1 = client.post("/api/v1/tickets", json={
        "facility_id": data["f1"].facility_id,
        "reporter_id": data["c1"].id,
        "issue_categories": ["DIRTY"],
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    })
    r2 = client.post("/api/v1/tickets", json={
        "facility_id": data["f2"].facility_id,
        "reporter_id": data["c2"].id,
        "issue_categories": ["DIRTY"],
        "reporter_latitude": 12.9780,
        "reporter_longitude": 77.6400,
        "is_live_camera": True
    })
    assert r1.status_code == 201
    assert r2.status_code == 201
    assert r1.json()["ticket_id"] != r2.json()["ticket_id"]
    assert r1.json()["report_count"] == 1
    assert r2.json()["report_count"] == 1
