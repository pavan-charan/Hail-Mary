import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import app.users.models
import app.facilities.models
import app.workers.models
import app.tickets.models
import app.ratings.models
import app.sla.models
import app.notifications.models
import app.history.models
import app.qr.models

from app.database import SessionLocal, engine, Base
from app.users.models import User, Admin, UserRole
from app.facilities.models import Facility, FacilityType, GenderAccess, FacilityStatus
from app.workers.models import LocalBodyWorker
from app.core.security import get_password_hash
from datetime import datetime, timezone

def seed_database():
    db = SessionLocal()
    try:
        # 1. Seed Admin
        admin_email = "admin@sanitation.gov.in"
        existing_user = db.query(User).filter(User.email == admin_email).first()
        if not existing_user:
            print("Seeding Municipal Admin user...")
            admin_user = User(
                email=admin_email,
                phone="+919999999999",
                full_name="Kochi Municipal Corporation Admin",
                hashed_password=get_password_hash("Admin@12345"),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)
            
            admin_profile = Admin(
                user_id=admin_user.id,
                department="Sanitation & Public Works",
                designation="Chief Municipal Sanitation Officer",
                ward_jurisdiction="ALL"
            )
            db.add(admin_profile)
            db.commit()
            print("Admin created: admin@sanitation.gov.in / Admin@12345")
        
        # 2. Seed Sample Kochi Workers
        workers_data = [
            {
                "phone": "+919876543210",
                "full_name": "Suresh Nair",
                "worker_code": "KMC-WKR-0101",
                "ward": "Ward-01 Marine Drive",
            },
            {
                "phone": "+919876543211",
                "full_name": "Ramesh Kumar",
                "worker_code": "KMC-WKR-0102",
                "ward": "Ward-05 Ernakulam Central",
            },
            {
                "phone": "+919876543212",
                "full_name": "Anil Varma",
                "worker_code": "KMC-WKR-0103",
                "ward": "Ward-02 Heritage Fort Kochi",
            },
            {
                "phone": "+919876543213",
                "full_name": "Biju Joseph",
                "worker_code": "KMC-WKR-0104",
                "ward": "Ward-12 Vyttila Terminal",
            }
        ]
        
        for w in workers_data:
            existing_w_user = db.query(User).filter(User.phone == w["phone"]).first()
            if not existing_w_user:
                w_user = User(
                    phone=w["phone"],
                    full_name=w["full_name"],
                    role=UserRole.WORKER,
                    is_active=True
                )
                db.add(w_user)
                db.commit()
                db.refresh(w_user)
                
                worker_profile = LocalBodyWorker(
                    user_id=w_user.id,
                    worker_code=w["worker_code"],
                    ward=w["ward"],
                    face_enrolled=False,
                    active_workload_count=0
                )
                db.add(worker_profile)
                db.commit()
        print("Kochi Workers seeded successfully.")

        # 3. Seed Kochi Facilities
        facilities_data = [
            {
                "facility_id": "FAC-KOC-MD-A8F1",
                "name": "Marine Drive Walkway Public Restroom",
                "facility_type": FacilityType.TOILET,
                "latitude": 9.9784,
                "longitude": 76.2755,
                "address": "Rainbow Bridge Promenade, Marine Drive, Kochi",
                "ward": "Ward-01 Marine Drive",
                "gender_access": GenderAccess.UNISEX,
                "wheelchair_accessible": True,
                "water_availability": True,
                "opening_time": "05:30",
                "closing_time": "23:00",
                "status": FacilityStatus.ACTIVE,
                "confidence_score": 96.0,
                "qr_code_hash": "KOC-MD-A8F1-QR-PROD"
            },
            {
                "facility_id": "FAC-KOC-MG-C349",
                "name": "MG Road Metro Drinking Water Point",
                "facility_type": FacilityType.DRINKING_WATER,
                "latitude": 9.9723,
                "longitude": 76.2831,
                "address": "Opposite Shenoys Junction, MG Road, Ernakulam",
                "ward": "Ward-05 Ernakulam Central",
                "gender_access": GenderAccess.UNISEX,
                "wheelchair_accessible": True,
                "water_availability": True,
                "opening_time": "05:30",
                "closing_time": "22:30",
                "status": FacilityStatus.ACTIVE,
                "confidence_score": 92.0,
                "qr_code_hash": "KOC-MG-C349-QR-PROD"
            },
            {
                "facility_id": "FAC-KOC-FK-9B04",
                "name": "Fort Kochi Heritage Beach Restroom",
                "facility_type": FacilityType.TOILET,
                "latitude": 9.9658,
                "longitude": 76.2421,
                "address": "Near Chinese Fishing Nets, Vasco da Gama Square, Fort Kochi",
                "ward": "Ward-02 Heritage Fort Kochi",
                "gender_access": GenderAccess.FEMALE,
                "wheelchair_accessible": False,
                "water_availability": True,
                "opening_time": "07:00",
                "closing_time": "21:00",
                "status": FacilityStatus.ACTIVE,
                "confidence_score": 88.0,
                "qr_code_hash": "KOC-FK-9B04-QR-PROD"
            },
            {
                "facility_id": "FAC-KOC-VY-D102",
                "name": "Vyttila Mobility Hub Transit Restroom",
                "facility_type": FacilityType.TOILET,
                "latitude": 9.9680,
                "longitude": 76.3180,
                "address": "Platform 3 Bay, Vyttila Mobility Hub, Kochi",
                "ward": "Ward-12 Vyttila Terminal",
                "gender_access": GenderAccess.UNISEX,
                "wheelchair_accessible": True,
                "water_availability": True,
                "opening_time": "00:00",
                "closing_time": "23:59",
                "status": FacilityStatus.ACTIVE,
                "confidence_score": 85.0,
                "qr_code_hash": "KOC-VY-D102-QR-PROD"
            }
        ]

        for f in facilities_data:
            existing_f = db.query(Facility).filter(Facility.facility_id == f["facility_id"]).first()
            if not existing_f:
                facility = Facility(**f)
                db.add(facility)
        db.commit()
        print("Kochi Facilities seeded successfully.")

    except Exception as e:
        db.rollback()
        print("Error seeding database:", e)
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
