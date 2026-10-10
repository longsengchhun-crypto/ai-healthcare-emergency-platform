# Requirements Specification

Status column reflects the repository at the time of writing: ✅ implemented & tested, 🟡 implemented / partly
verified, ❌ not implemented. See KNOWN_ISSUES.md.

## 1. Problem statement and objectives

Patients struggle to coordinate appointments, records and medication, and to ask for help quickly with their
location; hospitals lack a simple queue to acknowledge and track such requests. The platform provides a patient app, a
secured API and an operations dashboard that together demonstrate this workflow with honest status reporting and
clearly-labelled AI assistance.

Objectives: (O1) secure role-based access to health data; (O2) reliable, auditable appointment and emergency
workflows; (O3) practical, safely-labelled AI assistance; (O4) a reproducible, tested, documented system.

## 2. Functional requirements

| ID | Requirement | Status |
|---|---|---|
| FR-01 | Register, log in, log out, refresh session, reset password | ✅ (reset delivery needs email provider ❌) |
| FR-02 | Patient profile and ≤ 5 emergency contacts | ✅ |
| FR-03 | Search doctors (name/specialty/hospital/verified) and hospitals (name/city/distance), paginated | ✅ |
| FR-04 | Doctor availability slots; book, reschedule, cancel; doctor confirm/reject/complete | ✅ |
| FR-05 | No double booking | ✅ DB constraint + test |
| FR-06 | Patient- and clinician-authored records, amendments, documents, grants | ✅ |
| FR-07 | Medication list and daily reminders, adherence events | ✅ (on-device alarms unverified 🟡) |
| FR-08 | Emergency request with confirmation, location, idempotency, state machine, history | ✅ |
| FR-09 | Staff acknowledge / assign / advance / reject; patient cancel | ✅ |
| FR-10 | Honest failure display and call shortcut (user-initiated) | ✅ (device unverified 🟡) |
| FR-11 | GPS permission handling and distance | 🟡 |
| FR-12 | Opt-in sensor possible-incident detector with cancellable countdown and demo mode | 🟡 |
| FR-13 | AI triage, record summary, document extraction (deterministic provider) | ✅ |
| FR-14 | Notification inbox; push delivery with retry | ✅ inbox / ❌ push provider |
| FR-15 | Dashboard: overview, queue, appointments, users, audit, status | ✅ |
| FR-16 | Hospital/department/doctor profile & availability management | ✅ API + dashboard (no mobile availability editor) |
| FR-17 | Audit trail of sensitive access | ✅ |
| FR-18 | Account deactivation | ✅ |

## 3. Non-functional requirements

| ID | Requirement | Status |
|---|---|---|
| NFR-01 | Passwords hashed (BCrypt), tokens short-lived, refresh rotation | ✅ |
| NFR-02 | Server-side authorisation for every protected operation | ✅ |
| NFR-03 | TLS in production | 🟡 documented, not deployed |
| NFR-04 | No medical details in notifications/logs | ✅ by design |
| NFR-05 | Schema migrations reproducible on an empty DB | ✅ |
| NFR-06 | Portable across PostgreSQL and H2 for tests | ✅ |
| NFR-07 | Accessibility: touch targets ≥ 44 dp, semantic alternative to hold gesture | 🟡 not audited |
| NFR-08 | Responsive layouts (phone/tablet/web) | 🟡 not visually verified on devices |
| NFR-09 | Health endpoints + structured errors | ✅ |
| NFR-10 | Offline read cache | ❌ |

## 4. Role / permission matrix

| Capability | Patient | Doctor | Hospital staff | System admin |
|---|---|---|---|---|
| Own profile, contacts | ✔ | | | |
| Book/cancel own appointments | ✔ | | | |
| Manage assigned appointments | | ✔ | | |
| View all appointments | | | ✔ | ✔ |
| Own records / add notes | ✔ | | | |
| Read patient records | | ✔ (grant or confirmed visit) | ✘ | ✘ |
| Write clinical records | | ✔ | | |
| Create emergency | ✔ | | | |
| View emergency queue | own only | assigned only | hospital-scoped | all |
| Acknowledge/assign/advance emergency | | | ✔ | |
| Manage users / roles | | | | ✔ |
| Verify doctors, change settings | | | | ✔ |
| View audit log | | | ✔ | ✔ |
| Use AI features | ✔ | ✔ | | |

(`SYSTEM_ADMIN` has queue visibility but not `EMERGENCY_MANAGE`.)
