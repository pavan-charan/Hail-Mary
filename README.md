# 🚰 Smart Public Sanitation & Drinking Water Management System
> **A Production-Grade Civic Infrastructure & Maintenance Automation Platform**  
> *Target Pilot: Kochi Municipal Corporation (KMC), Kerala, India*

[![FastAPI](https://img.shields.io/badge/Backend-FastAPI_0.110-009688.svg?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter_3.x-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Database-Supabase_PostgreSQL_17_+_PostGIS_3.3-3ECF8E.svg?logo=supabase&logoColor=white)](https://supabase.com)
[![MediaPipe](https://img.shields.io/badge/Biometrics-MediaPipe_Face_Landmarks-FF6F00.svg?logo=google&logoColor=white)](https://developers.google.com/mediapipe)
[![Tests](https://img.shields.io/badge/Tests-24%2F24_Passing_(100%25)-brightgreen.svg)](#-testing--quality-assurance)

---

## 📌 1. Problem Statement & Civic Context

Urban public sanitation and drinking water facilities in Indian municipalities often suffer from severe operational gaps:
- **Lack of Real-Time Discovery**: Citizens struggle to find clean, open, and accessible public restrooms or drinking water points with verified working status and amenities (wheelchair accessibility, female-friendly facilities).
- **Ghost Maintenance & False Closures**: Traditional complaint logging lacks cryptographic proof of presence and work order verification, allowing unresolved maintenance tickets to be prematurely marked as fixed.
- **Complaint Fatigue & Redundant Work**: Multiple citizens reporting the same broken tap or clogged toilet create disjointed duplicate tickets, overwhelming municipal field officers.
- **Unenforced SLAs**: Without automated multi-channel escalation, tickets remain stagnant beyond acceptable public health resolution windows.
- **Accountability Vacuum**: Absence of objective facility health metrics leaves municipal administrators blind to chronic ward-level sanitation deficiencies.

**The Solution:** An end-to-end civic platform connecting **Citizens**, **Local Body Workers**, and **Municipal Administrators** with automated spatial dispatch, live camera & geofence validation, MediaPipe biometric verification, dynamic confidence scoring, and multi-tier Twilio voice escalation.

---

## 🏛️ 2. System Architecture

The platform is engineered using **Clean Architecture** principles across both the backend micro-modular services and the reactive Flutter client.

```
                                  ┌───────────────────────────────┐
                                  │      Flutter Client App       │
                                  │  (Citizen / Worker / Admin)   │
                                  └───────────────┬───────────────┘
                                                  │ HTTPS / REST / GeoJSON
                                                  ▼
                                  ┌───────────────────────────────┐
                                  │       FastAPI Gateway         │
                                  │      (Uvicorn ASGI App)       │
                                  └───────┬───────────────┬───────┘
                                          │               │
                 ┌────────────────────────┼───────────────┼────────────────────────┐
                 │                        │               │                        │
                 ▼                        ▼               ▼                        ▼
        ┌─────────────────┐      ┌─────────────────┐ ┌──────────────┐     ┌────────────────┐
        │  Auth & Biometrics │   │  Spatial Asset   │ │ SLA Engine   │     │ Communications │
        │  (JWT / MediaPipe)│    │  & Ticket Dispatch││ & Escalation │     │ (Twilio/FCM)   │
        └─────────────────┘      └────────┬────────┘ └──────────────┘     └────────────────┘
                                          │ PostGIS Geometry & Spatial Queries
                                          ▼
                         ┌────────────────────────────────────────┐
                         │   Supabase PostgreSQL 17 + PostGIS 3.3  │
                         │     (AWS ap-south-1 Mumbai Pooler)     │
                         └────────────────────────────────────────┘
```

### Architecture Layers & Technologies
| Component | Technology | Responsibility |
|---|---|---|
| **Frontend Framework** | **Flutter (Android + Web)** | Unified responsive application for Citizens, Workers, and Municipal Admin. |
| **State Management** | **Riverpod 2.5 + GoRouter** | Declarative dependency injection, cached state, and role-based route guards. |
| **Mapping & GIS** | **`flutter_map` + OpenStreetMap** | Real-time tile rendering, GPS tracking, and categorized custom facility markers. |
| **Backend API** | **FastAPI (Python 3.12)** | Asynchronous REST endpoints, Pydantic V2 validation, and clean modular services. |
| **Database Engine** | **Supabase PostgreSQL 17 + PostGIS 3.3** | Spatial indexing (`ST_DWithin`, `ST_Distance_Sphere`), spatial tables, and connection pooling. |
| **ORM & Data Layer** | **SQLAlchemy 2.0 ORM** | Object-relational mapping, eager relationships, and connection health pinging. |
| **Biometric Verification** | **Google MediaPipe Face Mesh** | 468 3D facial landmark embedding extraction & cosine similarity verification. |
| **Telephony & Notifications**| **Twilio Voice/SMS & FCM** | Automated voice escalation calls, OTP verification, and push notifications. |

---

## 🚀 3. Setup & Installation Guide

### Prerequisites
- **Python**: `3.10` or higher (`3.12` recommended)
- **Flutter SDK**: `3.16` or higher
- **PostgreSQL**: PostgreSQL 15+ with PostGIS extension (or use the configured **Supabase** instance)
- **Git**

---

### Backend Setup (FastAPI)

1. **Navigate to backend workspace**:
   ```bash
   cd backend
   ```

2. **Create and activate a virtual environment**:
   ```bash
   # Windows (PowerShell)
   python -m venv venv
   .\venv\Scripts\Activate.ps1

   # Linux / macOS
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure Environment Variables**:
   A ready-to-use `.env` file is generated with Supabase PostgreSQL configuration:
   ```bash
   # Copy example if setting up custom environment
   cp ../.env.example .env
   ```

5. **Seed Initial Kochi Municipal Data**:
   Populates Municipal Admin (`admin@sanitation.gov.in` / `Admin@12345`), 4 Ward field workers, and Kochi core sanitation hubs:
   ```bash
   python app/seed.py
   ```

6. **Start the FastAPI Development Server**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   - **API Root**: `http://localhost:8000/api/v1`
   - **Interactive OpenAPI Documentation**: `http://localhost:8000/docs`
   - **Alternative ReDoc UI**: `http://localhost:8000/redoc`

---

### Frontend Setup (Flutter Android / Web)

1. **Navigate to frontend workspace**:
   ```bash
   cd frontend
   ```

2. **Fetch packages**:
   ```bash
   flutter pub get
   ```

3. **Launch the application**:
   ```bash
   # Run in Chrome (Web Admin & Citizen preview)
   flutter run -d chrome

   # Run on connected Android Device / Emulator
   flutter run -d android
   ```

---

## ⚡ 4. Completed Features (20-Phase Breakdown)

All **20 development phases** are implemented and verified:

### 📱 Citizen Module
- **Passwordless Authentication (Phase 2)**: Quick SMS OTP login with automated user provisioning.
- **Spatial Map Discovery (Phase 4)**: OpenStreetMap discovery centered on **Kochi, Kerala** (`9.9723, 76.2831`), calculating walking times (at 80m/min) with multi-criteria filters (Toilets, Drinking Water, Gender Access, Wheelchair Accessibility).
- **Cryptographic QR Scanner (Phase 5)**: Live QR scanning of facility codes (`/qr/scan/{id}`) with a soft-demolished safety interceptor recommending the top 3 nearest active facilities.
- **Live-Camera Ticket Raising (Phase 6)**: Multi-issue selection with live camera capture enforcement (gallery uploads prohibited), auto GPS tagging, and unique Ticket ID generation (`TCK-<YYYYMMDD>-<HEX>`).
- **Duplicate Auto-Merge (Phase 7)**: 12-hour spatial merge engine grouping concurrent complaints into single work orders while escalating priority and keeping all reporting citizens notified.
- **Geo-Fenced Ratings & Confidence Score (Phases 14 & 15)**: 30-meter proximity-verified reviews with a dynamic 0–100 facility health algorithm and 4-tier color status rings.
- **Real-Time Lifecycle Timeline (Phase 13)**: End-to-end tracking from `REPORTED` &rarr; `ASSIGNED` &rarr; `REACHED` &rarr; `COMPLETED` &rarr; `RESOLVED`.

---

### 👷 Field Worker Module
- **Admin Pre-Registration & Face Enrollment (Phases 2 & 11)**: Strict admin pre-approval requirement followed by biometric face registration.
- **Priority Work Queue (Phase 9)**: Real-time ticket feed ranked by severity with SLA countdown timers and turn-by-turn navigation.
- **4-Stage Maintenance Stepper (Phase 10)**:
  1. `ASSIGNED` &rarr; Accept task.
  2. `REACHED` &rarr; Validated via 30-meter GPS geo-fence.
  3. `REPAIRING` &rarr; Work in progress status.
  4. `COMPLETED` &rarr; Submission of live after-repair photo proof.
- **MediaPipe Biometric Verification (Phase 11)**: Cosine similarity comparison (threshold $\ge 0.75$) between live repair selfie and registered face embeddings to prevent proxy maintenance.

---

### 🛡️ Municipal Administration Module
- **Asset Lifecycle Management (Phase 3)**: CRUD for municipal facilities with automatic unique ID generation (`FAC-<WARD>-<TYPE>-<HEX>`), printable QR hashes, soft-demolition rules, and full restoration audit history.
- **Automated Workload Dispatch (Phase 8)**: Intelligent assignment pairing tickets with the least-loaded worker in the same ward with proximity tie-breaking.
- **Admin Verification Portal (Phase 12)**: Side-by-side Before/After media inspection, biometric match score validation, and 1-click Approval (`RESOLVED`) or Rejection with feedback.
- **Multi-Tier SLA Escalation Engine (Phase 16)**: Automated 24-hour breach checker:
  - `T + 20h`: SMS warning reminder to worker.
  - `T + 24h`: Level-1 automated Twilio AI voice alert call.
  - `T + 26h`: Level-2 voice escalation call to worker & supervisor.
  - `T + 28h`: Work order reassignment and penalty point logging.
- **Ward Analytics & Intensity Heatmaps (Phase 19)**: Real-time municipal KPIs, resolution velocity breakdown, and geographic issue density maps.
- **Unified Notification Hub (Phase 18)**: Role-based notification dispatcher with instant read/unread states.
- **Offline Synchronization (Phase 17)**: Local SQLite action queue with auto-replay upon network reconnection.
- **Spatial PostGIS Database Hardening (Phase 20)**: Indexed spatial query optimization, connection pool resilience, and schema validations.

---

## 📍 5. Single-City Focus: Kochi, Kerala

The system is calibrated for the **Kochi Municipal Corporation (KMC)**:
- **Default Map Center**: `9.9723, 76.2831` (Ernakulam Central / MG Road)
- **Initial Seeded Facilities**:
  1. **Marine Drive Walkway Public Restroom** (`9.9784, 76.2755` — *Ward-01 Marine Drive*)
  2. **MG Road Metro Drinking Water Point** (`9.9723, 76.2831` — *Ward-05 Ernakulam Central*)
  3. **Fort Kochi Beach Heritage Restroom** (`9.9658, 76.2421` — *Ward-02 Fort Kochi*)
  4. **Vyttila Mobility Hub Transit Restroom** (`9.9680, 76.3180` — *Ward-12 Vyttila Terminal*)

---

## 🧪 6. Testing & Quality Assurance

The codebase maintains a 100% test pass rate across unit, spatial, integration, and UI smoke tests.

### Running Backend Pytest Suite
```bash
python -m pytest backend/tests -v
```

**Test Suite Coverage (24/24 Passing):**
- `test_auth.py`: Passwordless OTP flow, unregistered worker rejection, worker enrollment, admin login.
- `test_facilities.py`: Facility auto-ID generation, QR generation, edit history, soft demolition, restoration.
- `test_citizen_discovery.py`: PostGIS spatial discovery, distance calculation, multi-attribute filtering.
- `test_qr_system.py`: Active QR scanning, demolished facility guard, alternative recommendations.
- `test_ticket_raising.py`: Camera-only proof enforcement, gallery upload rejection, GPS/timestamp tagging.
- `test_ticket_duplicate_merge.py`: 12h duplicate merging, issue set union, priority escalation.
- `test_auto_assignment.py`: Same-ward worker assignment, workload minimization, manual reassignment.
- `test_master_end_to_end.py`: Comprehensive phase 9–20 workflow execution.

### Running Frontend Tests
```bash
cd frontend
flutter test
```
- Validates Flutter Riverpod state containers, role routing guards, and UI widget foundations.

---

## ⚠️ 7. Limitations & Future Roadmap

### Current Limitations
1. **Camera Hardware Emulation on Web**: In desktop browser environments, live camera constraints fallback to standard HTML5 file upload inputs. Native Android builds enforce hardware camera capture strictly.
2. **Network Bandwidth in Low-Coverage Pockets**: High-resolution image submissions in low-bandwidth zones depend on the offline SQLite sync queue (`Phase 17`).
3. **Third-Party Telephony Dependency**: Automated AI voice calls and SMS alerts require active Twilio API credentials with appropriate regional telephony permissions.

### Future Roadmap
- [ ] **Vernacular Language Support**: Malayalam (മലയാളം) & Hindi localization alongside English.
- [ ] **IoT Telemetry Integration**: Ultrasonic water tank level sensors, smart water meter flow counters, and ammonia odor sensors for predictive maintenance dispatch.
- [ ] **Citizen Rewards Program**: Civic credit points for verified ratings and active community reporting.
- [ ] **Drone & Street-View Route Verification**: Integrated street-level imagery for rapid facility accessibility audits.

---

## 📄 License & Attribution
Developed for municipal civic enhancement and open public infrastructure accountability.  
Repository: **[https://github.com/pavan-charan/Hail-Mary](https://github.com/pavan-charan/Hail-Mary)**
