import pytest
import uuid
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from app.facilities.models import Facility, FacilityType, FacilityStatus
from app.users.models import User, UserRole
from app.workers.models import LocalBodyWorker
from app.tickets.models import Ticket, TicketStatus, TicketPriority
from app.sla.models import SLALog, SLAStep
from app.notifications.models import Notification

@pytest.fixture
def setup_assignment_environment(db_session):
    uid = uuid.uuid4().hex[:6]
    
    # Citizen
    citizen = User(phone=f"+9198{uid[:4]}11", full_name="Citizen Tester", role=UserRole.CITIZEN, is_active=True)
    db_session.add(citizen)
    db_session.commit()
    db_session.refresh(citizen)

    # Facility in Ward-05
    facility = Facility(
        facility_id=f"FAC-W05-TLT-{uid[:4]}",
        name="Ward 5 Public Sanitation Complex",
        facility_type=FacilityType.TOILET,
        ward="Ward-05",
        address="12th Main Road, Ward 5",
        latitude=12.9716,
        longitude=77.5946,
        status=FacilityStatus.ACTIVE
    )
    db_session.add(facility)
    db_session.commit()
    db_session.refresh(facility)

    # Worker 1 in Ward-05 (Heavy workload)
    u_w1 = User(phone=f"+9198{uid[:4]}21", full_name="Ramesh HeavyWorkload", role=UserRole.WORKER, is_active=True)
    db_session.add(u_w1)
    db_session.commit()
    db_session.refresh(u_w1)
    worker1 = LocalBodyWorker(
        user_id=u_w1.id,
        worker_code=f"WRK-W05-01-{uid[:3]}",
        ward="Ward-05",
        face_enrolled=True,
        active_workload_count=2,
        current_latitude=12.9715,
        current_longitude=77.5945
    )
    db_session.add(worker1)
    db_session.commit()
    db_session.refresh(worker1)

    # Pre-assign 2 active tickets to Worker 1
    t1 = Ticket(
        ticket_id=f"TCK-PREV-1-{uid}",
        facility_id=facility.id,
        reporter_id=citizen.id,
        assigned_worker_id=worker1.id,
        issue_categories='["DIRTY"]',
        status=TicketStatus.ASSIGNED,
        reporter_latitude=12.9716,
        reporter_longitude=77.5946
    )
    t2 = Ticket(
        ticket_id=f"TCK-PREV-2-{uid}",
        facility_id=facility.id,
        reporter_id=citizen.id,
        assigned_worker_id=worker1.id,
        issue_categories='["LIGHT_ISSUE"]',
        status=TicketStatus.REPAIRING,
        reporter_latitude=12.9716,
        reporter_longitude=77.5946
    )
    db_session.add_all([t1, t2])
    db_session.commit()

    # Worker 2 in Ward-05 (Zero workload, ideal candidate)
    u_w2 = User(phone=f"+9198{uid[:4]}31", full_name="Suresh LightWorkload", role=UserRole.WORKER, is_active=True)
    db_session.add(u_w2)
    db_session.commit()
    db_session.refresh(u_w2)
    worker2 = LocalBodyWorker(
        user_id=u_w2.id,
        worker_code=f"WRK-W05-02-{uid[:3]}",
        ward="Ward-05",
        face_enrolled=True,
        active_workload_count=0,
        current_latitude=12.9718,
        current_longitude=77.5948
    )
    db_session.add(worker2)
    db_session.commit()
    db_session.refresh(worker2)

    return {
        "citizen": citizen,
        "facility": facility,
        "worker1": worker1,
        "worker2": worker2,
        "user_worker1": u_w1,
        "user_worker2": u_w2,
    }

def test_auto_assignment_same_ward_lowest_workload(client: TestClient, db_session, setup_assignment_environment):
    env = setup_assignment_environment
    facility = env["facility"]
    citizen = env["citizen"]
    worker2 = env["worker2"]

    # Citizen raises ticket for the facility
    payload = {
        "facility_id": facility.facility_id,
        "reporter_id": citizen.id,
        "issue_categories": ["NO_WATER", "BAD_SMELL"],
        "description": "Auto-assignment validation ticket",
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    }
    resp = client.post("/api/v1/tickets", json=payload)
    assert resp.status_code == 201
    data = resp.json()

    # 1. Verify Auto-Assignment to Worker 2 (who had 0 active workload vs Worker 1 who had 2)
    assert data["status"] == "ASSIGNED"
    assert data["assigned_worker_id"] == worker2.id
    assert data["assigned_worker_name"] == env["user_worker2"].full_name

    # 2. Verify 24-Hour SLA Timer
    assert data["assigned_at"] is not None
    assert data["expected_sla_deadline"] is not None

    # 3. Verify SLA Log in DB
    ticket_id_str = data["ticket_id"]
    db_ticket = db_session.query(Ticket).filter(Ticket.ticket_id == ticket_id_str).first()
    assert db_ticket is not None
    sla_logs = db_session.query(SLALog).filter(SLALog.ticket_id == db_ticket.id).all()
    assert len(sla_logs) >= 1
    assert sla_logs[0].step == SLAStep.ASSIGNMENT

    # 4. Verify Worker Notification
    notif = db_session.query(Notification).filter(
        Notification.user_id == worker2.user_id,
        Notification.reference_id == ticket_id_str
    ).first()
    assert notif is not None
    assert "Work Order Assigned" in notif.title

def test_manual_ticket_reassignment_endpoint(client: TestClient, db_session, setup_assignment_environment):
    env = setup_assignment_environment
    facility = env["facility"]
    citizen = env["citizen"]
    worker1 = env["worker1"]

    # Raise a ticket that auto-assigns to Worker 2
    resp = client.post("/api/v1/tickets", json={
        "facility_id": facility.facility_id,
        "reporter_id": citizen.id,
        "issue_categories": ["LOCKED"],
        "reporter_latitude": 12.9716,
        "reporter_longitude": 77.5946,
        "is_live_camera": True
    })
    ticket_id = resp.json()["ticket_id"]

    # Manually reassign to Worker 1
    reassign_resp = client.post(f"/api/v1/tickets/{ticket_id}/assign?worker_id={worker1.id}")
    assert reassign_resp.status_code == 200
    reassigned_data = reassign_resp.json()

    assert reassigned_data["assigned_worker_id"] == worker1.id
    assert reassigned_data["assigned_worker_name"] == env["user_worker1"].full_name
    assert reassigned_data["status"] == "ASSIGNED"
