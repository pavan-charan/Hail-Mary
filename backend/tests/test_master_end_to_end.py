import pytest
import uuid
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient

from app.facilities.models import Facility, FacilityType, FacilityStatus
from app.users.models import User, UserRole
from app.workers.models import LocalBodyWorker
from app.tickets.models import Ticket, TicketStatus, TicketPriority
from app.face_verification.service import extract_face_embedding

@pytest.fixture
def master_test_setup(db_session):
    uid = uuid.uuid4().hex[:6]
    
    # 1. Citizen
    citizen = User(phone=f"+9198{uid[:4]}11", full_name="Master Citizen", role=UserRole.CITIZEN, is_active=True)
    
    # 2. Admin
    admin = User(phone=f"+9198{uid[:4]}99", email=f"admin_{uid}@bbmp.gov.in", full_name="Master Admin", role=UserRole.ADMIN, is_active=True)
    
    # 3. Worker
    w_user = User(phone=f"+9198{uid[:4]}55", full_name="Master Worker", role=UserRole.WORKER, is_active=True)
    
    db_session.add_all([citizen, admin, w_user])
    db_session.commit()
    db_session.refresh(citizen)
    db_session.refresh(admin)
    db_session.refresh(w_user)

    # Face embedding
    face_emb = extract_face_embedding("sample_live_selfie_base64_data_string_for_worker_face_enrollment_123456789")
    worker = LocalBodyWorker(
        user_id=w_user.id,
        worker_code=f"WRK-M01-{uid[:3]}",
        ward="Ward-10",
        face_enrolled=True,
        face_embedding=face_emb,
        current_latitude=12.9716,
        current_longitude=77.5946
    )
    db_session.add(worker)

    # Facility
    facility = Facility(
        facility_id=f"FAC-W10-TLT-{uid[:4]}",
        name="MG Road Civic Restroom",
        facility_type=FacilityType.TOILET,
        ward="Ward-10",
        address="MG Road Boulevard",
        latitude=12.9716,
        longitude=77.5946,
        status=FacilityStatus.ACTIVE,
        confidence_score=90.0
    )
    db_session.add(facility)
    db_session.commit()
    db_session.refresh(worker)
    db_session.refresh(facility)

    return {
        "citizen": citizen,
        "admin": admin,
        "worker_user": w_user,
        "worker": worker,
        "facility": facility
    }

def test_complete_phase_9_to_20_lifecycle(client: TestClient, db_session, master_test_setup):
    env = master_test_setup
    facility = env["facility"]
    citizen = env["citizen"]
    worker = env["worker"]
    admin = env["admin"]

    # 1. Citizen raises ticket
    r_raise = client.post("/api/v1/tickets", json={
        "facility_id": facility.facility_id,
        "reporter_id": citizen.id,
        "issue_categories": ["NO_WATER", "DIRTY"],
        "description": "Tap has no water and needs sanitation",
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    })
    assert r_raise.status_code == 201
    ticket_data = r_raise.json()
    ticket_id = ticket_data["ticket_id"]
    assert ticket_data["status"] == "ASSIGNED"
    assert ticket_data["assigned_worker_id"] == worker.id

    # 2. Phase 9: Worker Station Queue & Stats
    r_queue = client.get(f"/api/v1/workers/{worker.id}/tickets")
    assert r_queue.status_code == 200
    queue = r_queue.json()
    assert len(queue) >= 1
    assert queue[0]["ticket_id"] == ticket_id

    r_stats = client.get(f"/api/v1/workers/{worker.id}/stats")
    assert r_stats.status_code == 200
    assert r_stats.json()["active_assigned"] >= 1

    # 3. Phase 10: 4-Stage Workflow - Stage 1 (REACHED) Geofence Fail Test (>30m)
    r_reach_fail = client.post(f"/api/v1/tickets/{ticket_id}/status", json={
        "status": "REACHED",
        "current_latitude": 13.0500, # 8 km away
        "current_longitude": 77.6500
    })
    assert r_reach_fail.status_code == 400
    assert "Geofence validation failed" in r_reach_fail.json()["detail"]

    # 4. Stage 1 (REACHED) Geofence Pass (within 30m)
    r_reach_pass = client.post(f"/api/v1/tickets/{ticket_id}/status", json={
        "status": "REACHED",
        "current_latitude": 12.9716,
        "current_longitude": 77.5946
    })
    assert r_reach_pass.status_code == 200
    assert r_reach_pass.json()["status"] == "REACHED"

    # 5. Stage 2 (REPAIRING)
    r_repair = client.post(f"/api/v1/tickets/{ticket_id}/status", json={
        "status": "REPAIRING",
        "worker_notes": "Replaced valve washers and disinfected floor surfaces"
    })
    assert r_repair.status_code == 200
    assert r_repair.json()["status"] == "REPAIRING"

    # 6. Stage 3 (COMPLETED / UNDER_VERIFICATION) with Phase 11 MediaPipe Face Verification
    r_complete = client.post(f"/api/v1/tickets/{ticket_id}/status", json={
        "status": "COMPLETED",
        "worker_notes": "Repairs finalized and water flow restored",
        "current_latitude": 12.9716,
        "current_longitude": 77.5946,
        "after_media_url": "https://storage.googleapis.com/hail-mary/after_proof.jpg",
        "face_image_base64": "sample_live_selfie_base64_data_string_for_worker_face_enrollment_123456789"
    })
    assert r_complete.status_code == 200
    assert r_complete.json()["status"] == "UNDER_VERIFICATION"
    assert r_complete.json()["face_verified"] is True
    assert r_complete.json()["face_match_score"] >= 75.0

    # 7. Phase 12: Admin Verification Portal (Approve -> RESOLVED)
    r_verify = client.post(f"/api/v1/tickets/{ticket_id}/verify", json={
        "action": "APPROVE",
        "admin_id": admin.id
    })
    assert r_verify.status_code == 200
    assert r_verify.json()["status"] == "RESOLVED"

    # 8. Phase 13: Ticket Timeline
    r_timeline = client.get(f"/api/v1/tickets/{ticket_id}/timeline")
    assert r_timeline.status_code == 200
    timeline = r_timeline.json()
    assert len(timeline) >= 4 # Creation, Reached, Repairing, Completed, Resolved

    # 9. Phase 14: Geo-Fenced Rating System
    r_rate = client.post("/api/v1/ratings", json={
        "facility_id": facility.facility_id,
        "user_id": citizen.id,
        "cleanliness": 5,
        "water_availability": True,
        "safety": 5,
        "accessibility": 1.0,
        "comments": "Very clean now, water is flowing perfectly!",
        "submission_latitude": 12.9716,
        "submission_longitude": 77.5946,
        "is_qr_scanned": True
    })
    assert r_rate.status_code == 201
    assert r_rate.json()["weighted_score"] >= 90.0

    # Test 24-hour Rating Cooldown
    r_rate_dup = client.post("/api/v1/ratings", json={
        "facility_id": facility.facility_id,
        "user_id": citizen.id,
        "cleanliness": 5,
        "water_availability": True,
        "safety": 5,
        "accessibility": 1.0,
        "submission_latitude": 12.9716,
        "submission_longitude": 77.5946,
        "is_qr_scanned": True
    })
    assert r_rate_dup.status_code == 429

    # 10. Phase 16: SLA Escalation Engine
    r_sla = client.post("/api/v1/sla/check-breaches")
    assert r_sla.status_code == 200
    assert r_sla.json()["status"] == "success"

    # 11. Phase 18: Notification Hub
    r_notifs = client.get(f"/api/v1/notifications/user/{citizen.id}")
    assert r_notifs.status_code == 200
    notifs = r_notifs.json()
    assert len(notifs) >= 1

    r_read_all = client.post(f"/api/v1/notifications/user/{citizen.id}/read-all")
    assert r_read_all.status_code == 200

    # 12. Phase 19: Analytics & Heatmaps
    r_analytics = client.get("/api/v1/analytics/summary")
    assert r_analytics.status_code == 200
    summary = r_analytics.json()
    assert summary["tickets"]["resolved"] >= 1
    assert summary["facilities"]["total"] >= 1

    r_heatmaps = client.get("/api/v1/analytics/heatmaps")
    assert r_heatmaps.status_code == 200
    assert len(r_heatmaps.json()) >= 1
