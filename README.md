# Smart Public Sanitation & Drinking Water Management System

A production-quality civic platform connecting Citizens, Local Body Workers, and Municipal Administration to locate public restrooms and drinking-water points, report issues with live camera proof and geo-fencing, verify repairs with MediaPipe face verification, manage municipal assets, and maintain accountability.

---

## Tech Stack

- **Frontend**: Flutter (Android + Web), Riverpod, GoRouter, `flutter_map` (OpenStreetMap), `mobile_scanner`, `camera`.
- **Backend**: FastAPI (Python), PostgreSQL + PostGIS (`GeoAlchemy2`, `Shapely`), SQLAlchemy 2.0 ORM, Pydantic V2.
- **Authentication**: Phone OTP, Passwordless Citizen Login, Face-Enrolled Worker Profiles, Admin Email/Password, JWT.
- **Verification & Media**: MediaPipe Face Landmark Verification, Camera-only live proof capture, Cryptographic Facility QR generation.
- **Integrations**: Twilio (SMS & automated escalation voice calls), Firebase Cloud Messaging & Storage.

---

## 20-Phase Implementation Status

- [x] **Phase 1: Project Foundation** — Clean architecture backend & Flutter role-based frontend.
- [x] **Phase 2: Authentication Engine** — Citizen Phone OTP, Worker Admin-Registration + OTP + Face Enrollment, Admin Email/Password.
- [x] **Phase 3: Facility Asset Management (Admin)** — Asset CRUD, auto Facility ID & QR generation, soft-demolition rules & audit restoration.
- [x] **Phase 4: Citizen App & Map Discovery** — OpenStreetMap markers (Male/Female/Unisex/Water/Accessible), walking time calculation, multi-attribute filter sheet, facility detail modal.
- [x] **Phase 5: QR System & Demolished Guard** — Exact facility ID scanning, Report/Rate actions, demolished facility alert & nearest alternative suggestions.
- [x] **Phase 6: Ticket Raising Engine** — Multi-issue selection, strict camera-only live capture enforcement, auto GPS & timestamp tagging, unique Ticket ID generation.
- [x] **Phase 7: Duplicate Detection & Auto-Merge** — Active ticket duplicate detection within 12h window, issue set union, report count incrementing, priority auto-escalation, and merged citizen status alerts.
- [ ] **Phase 8: Auto-Assignment Engine**
- [ ] **Phase 9: Worker Station & Queue**
- [ ] **Phase 10: 4-Stage Maintenance Workflow**
- [ ] **Phase 11: MediaPipe Face Verification**
- [ ] **Phase 12: Admin Verification Portal**
- [ ] **Phase 13: Real-Time Lifecycle Tracking**
- [ ] **Phase 14: Geo-Fenced Rating System**
- [ ] **Phase 15: Confidence Score Engine**
- [ ] **Phase 16: SLA Escalation Matrix & AI Voice Calls**
- [ ] **Phase 17: Offline Synchronization**
- [ ] **Phase 18: Unified Notification Hub**
- [ ] **Phase 19: Analytics & Heatmap Dashboard**
- [ ] **Phase 20: Database Hardening & Spatial Optimization**

---

## Running Locally

### Backend (FastAPI)
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
Interactive OpenAPI Docs: `http://localhost:8000/docs`

### Frontend (Flutter Web / Android)
```bash
cd frontend
flutter pub get
flutter run -d chrome # Or android emulator
```

### Running Automated Tests
```bash
# Backend tests
python -m pytest backend/tests -v

# Frontend tests
cd frontend && flutter test
```
