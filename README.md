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
- [x] **Phase 8: Auto-Assignment Engine** — Automated worker dispatch based on Same Ward, active workload minimization, proximity tie-breaking, 24-hour SLA deadline initialization, and real-time alerts.
- [x] **Phase 9: Worker Station & Queue** — Priority-ranked active task queue, workload status KPIs, real-time SLA countdowns, and navigation routing.
- [x] **Phase 10: 4-Stage Maintenance Workflow** — Strict 4-step state transitions (`ASSIGNED` &rarr; `REACHED` [30m Geofence validated] &rarr; `REPAIRING` &rarr; `COMPLETED` [Live After-photo proof]).
- [x] **Phase 11: MediaPipe Face Verification** — 3D facial landmark embedding extraction and cosine similarity verification against enrolled worker profile.
- [x] **Phase 12: Admin Verification Portal** — Work order inspection with side-by-side Before/After media comparison, Face Match validation, and 1-click Approval/Rejection with audit feedback.
- [x] **Phase 13: Real-Time Lifecycle Tracking** — Unified ticket timeline aggregating status transitions, SLA logs, media proof uploads, and citizen tracking updates.
- [x] **Phase 14: Geo-Fenced Rating System** — 30-meter proximity validation, 24-hour user cooldown, cleanliness & water quality weighted scoring.
- [x] **Phase 15: Confidence Score Engine** — Dynamic 0-100 facility health algorithm factoring citizen ratings, resolved maintenance turnaround, and open issue penalties with 4-tier color rings.
- [x] **Phase 16: SLA Escalation Matrix & AI Voice Calls** — 24-hour SLA breach engine with multi-tier escalation (20h SMS reminder, 24h & 26h automated Twilio AI voice calls, 28h penalty & reassignment).
- [x] **Phase 17: Offline Synchronization** — Local SQLite caching with optimistic offline queue and automatic replay upon network restoration.
- [x] **Phase 18: Unified Notification Hub** — In-app notification center, read/unread states, bulk mark-as-read, and role-based notification dispatching.
- [x] **Phase 19: Analytics & Heatmap Dashboard** — Municipal KPI cards, ward-by-ward ticket breakdown, and spatial issue intensity heatmaps.
- [x] **Phase 20: Database Hardening & Spatial Optimization** — PostGIS spatial indexing, connection pool resilience, schema validations, and end-to-end integration tests.

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
