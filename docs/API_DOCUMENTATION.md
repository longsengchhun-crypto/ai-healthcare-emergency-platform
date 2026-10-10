# API Documentation

Base path: `/api/v1`. JSON in/out, UTC ISO-8601 timestamps. Interactive docs from the running server:
`/swagger-ui.html` (OpenAPI JSON at `/api-docs`).

**Authentication:** `Authorization: Bearer <accessToken>` (15 min). Obtain via login/register; renew with
`/auth/refresh` (refresh tokens rotate; reuse revokes the whole family).

**Errors** (all endpoints):

```json
{ "code": "SLOT_TAKEN", "message": "That time slot was just booked by someone else",
  "status": 409, "timestamp": "2026-10-10T12:00:00Z", "fields": { "email": "must be a well-formed email address" } }
```

| Status | Meaning |
|---|---|
| 400 | malformed request / business validation (e.g. missing `Idempotency-Key`, bad timezone) |
| 401 | missing/expired token or bad credentials (generic message) |
| 403 | authenticated but lacks the permission |
| 404 | not found **or not yours** (object-level denials return 404 to prevent id probing) |
| 409 | state conflict (slot taken, invalid transition, duplicate registration) |
| 413 | file larger than 10 MB |
| 422 | field validation failed (`fields` populated) |
| 429 | rate limited (auth endpoints, 10/min/IP by default) |
| 500 | unexpected; no internals leaked |

## Authentication & account

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/auth/register` | none | `{email,password(10+),fullName,phone?,deviceLabel?}` → 201 tokens. Always creates a PATIENT. Duplicate → 409 generic. |
| POST | `/auth/login` | none | → `{accessToken,refreshToken,expiresInSeconds}`. 5 failures lock the account 15 min. |
| POST | `/auth/refresh` | none | `{refreshToken}` → new pair. |
| POST | `/auth/logout` | none | `{refreshToken}` → 204, revokes token family. |
| POST | `/auth/password-reset` | none | `{email}` → always 202. Email delivery is **not configured**; see KNOWN_ISSUES. |
| POST | `/auth/password-reset/confirm` | none | `{token,newPassword}` → 204, all sessions revoked. |
| GET | `/users/me` | any | `{id,email,fullName,roles,permissions}` |
| DELETE | `/users/me` | any | Deactivates the account, removes device tokens, revokes sessions. |

## Patient (permission `PROFILE_OWN`)

| Method | Path | Notes |
|---|---|---|
| GET/PATCH | `/patients/me` | PATCH fields optional: `fullName, phone, dateOfBirth, gender, bloodGroup, allergies, conditions, address` |
| GET/POST | `/patients/me/emergency-contacts` | max 5; `{name,relationship?,phone,priority?}` |
| DELETE | `/patients/me/emergency-contacts/{id}` | 204 |
| GET | `/patients/me/privacy` | active record-access grants |
| POST | `/patients/me/access-grants` | `{doctorId}` → doctor may read this patient's records |
| DELETE | `/patients/me/access-grants/{id}` | revoke |

## Directory (any authenticated user)

| Method | Path | Notes |
|---|---|---|
| GET | `/doctors?q&specialty&hospitalId&verifiedOnly&page&size` | paged `{items,page,size,total}` |
| GET | `/doctors/{id}` | includes `verificationStatus`, `demo` |
| GET | `/doctors/{id}/slots?date=YYYY-MM-DD` | free slots (clinic zone Asia/Phnom_Penh), UTC instants |
| GET | `/hospitals?q&city&lat&lon&page&size` | `distanceKm` when lat/lon supplied |
| GET | `/hospitals/{id}` | with departments |

## Appointments

| Method | Path | Permission | Notes |
|---|---|---|---|
| GET | `/appointments?page&size` | any | scoped: patient→own, doctor→assigned, `APPOINTMENT_ADMIN`→all |
| GET | `/appointments/{id}` | participant/admin | 404 otherwise |
| POST | `/appointments` | `APPOINTMENT_BOOK` | `{doctorId,startsAt,reason?}` → 201 REQUESTED; 409 `SLOT_UNAVAILABLE`/`SLOT_TAKEN` |
| PATCH | `/appointments/{id}` | `APPOINTMENT_BOOK` | `{startsAt}` reschedule (status resets to REQUESTED) |
| POST | `/appointments/{id}/confirm` `/reject` `/complete` | `APPOINTMENT_DOCTOR` + assigned doctor | |
| POST | `/appointments/{id}/cancel` | participant/admin | |

## Medical records

| Method | Path | Notes |
|---|---|---|
| GET | `/medical-records?patientId` | patient: own only; doctor: requires active grant or confirmed/completed appointment |
| GET | `/medical-records/{id}` | audited |
| POST | `/medical-records` | `{patientId?,recordType,title,body?,amendsId?}`; patients: `HISTORY`/`DOCUMENT`; clinicians: `CLINICAL_NOTE`/`PRESCRIPTION`/`TEST_REPORT`/`DISCHARGE_SUMMARY`; amendments create a new row, original author only |
| POST | `/medical-records/{id}/documents` | multipart `file`; PDF/PNG/JPEG by magic bytes, ≤ 10 MB |
| GET | `/medical-records/{id}/documents/{docId}` | attachment, `nosniff`, `no-store` |

## Medications

`GET/POST /medications`, `GET/POST /medication-reminders`, `PATCH /medication-reminders/{id}`
(`{active?,timeOfDay?,endDate?}`), `POST /medication-reminders/{id}/adherence` (`{outcome: TAKEN|SKIPPED}`).
Reminders carry an IANA `timezone`; `nextOccurrence` is computed server-side in that zone.

## Emergency

| Method | Path | Permission | Notes |
|---|---|---|---|
| POST | `/emergencies` | `EMERGENCY_CREATE` | **Header `Idempotency-Key` required.** Body `{demo?,triggerSource?,description?,latitude?,longitude?,accuracyMeters?}`. Returns 201 with `status:"SUBMITTED"`; a retry with the same key returns the same event with `duplicateRequest:true`. |
| GET | `/emergencies?status&limit` | any | patient: own; staff/admin: queue (hospital-scoped); doctor: assigned only |
| GET | `/emergencies/{id}` | owner / authorised staff | patient name/phone only shown to staff |
| POST | `/emergencies/{id}/acknowledge` | `EMERGENCY_MANAGE` | SUBMITTED → ACKNOWLEDGED |
| POST | `/emergencies/{id}/assign` | `EMERGENCY_MANAGE` | `{responderId}`; ACKNOWLEDGED → RESPONDER_ASSIGNED |
| POST | `/emergencies/{id}/status` | `EMERGENCY_MANAGE` | `{status: RESPONDER_EN_ROUTE|ARRIVED|RESOLVED|REJECTED, note?}` |
| POST | `/emergencies/{id}/cancel` | owner / manager | false alarm or staff cancel |
| GET | `/emergencies/responders` | `EMERGENCY_MANAGE` | id, name, role only |

## Sensors, AI, notifications

| Method | Path | Notes |
|---|---|---|
| POST | `/sensor-events` | candidate-incident evidence (≤ 200 readings); response `assessment` is only `POSSIBLE_INCIDENT` / `NOT_SIGNIFICANT` |
| POST | `/ai/triage` | `{symptoms}` → `{urgency, matchedRules, guidance, emergencyActionRecommended, followUpQuestions, disclaimer}` |
| POST | `/ai/medical-summary` | `{patientId?}` → structured summary + `sources`, `provider`, `languageModel:false`, `notice` |
| POST | `/ai/document-extraction` | multipart `.txt` only → `fields[{name,value,evidence,confidence}]`; images/PDF → 422 `OCR_NOT_CONFIGURED` |
| GET | `/notifications` | `{items, unread}` |
| POST | `/notifications/{id}/read` | 204 |
| POST/DELETE | `/devices/register`, `/devices/{id}` | push token registry |

## Administration

| Method | Path | Permission |
|---|---|---|
| GET | `/admin/users?q&page&size` | `USER_ADMIN` |
| PATCH | `/admin/users/{id}/status` | `USER_ADMIN` (ACTIVE/SUSPENDED/DEACTIVATED; revokes sessions) |
| POST | `/admin/users/{id}/roles` | `USER_ADMIN` (replaces role; revokes sessions) |
| POST | `/admin/doctors/{id}/verification` | `DOCTOR_VERIFY` |
| GET | `/admin/audit-logs?action&outcome&page&size` | `AUDIT_VIEW` |
| GET | `/admin/overview` | `EMERGENCY_QUEUE_VIEW` (real aggregates) |
| GET | `/system/settings` · PUT `/admin/settings/{key}` | any · `SETTINGS_MANAGE` |

## Example

```http
POST /api/v1/emergencies
Authorization: Bearer eyJ...
Idempotency-Key: 6f1c1c52-0c7c-4f6a-9d38-5d1c9a3d0a11
Content-Type: application/json

{ "demo": true, "latitude": 11.56, "longitude": 104.93, "accuracyMeters": 12 }
```
```json
{ "id": "…", "status": "SUBMITTED", "demo": true, "duplicateRequest": false,
  "history": [ {"toStatus":"CREATED"}, {"fromStatus":"CREATED","toStatus":"SUBMITTED"} ],
  "disclaimer": "Demonstration response workflow inside this app. It is not a real emergency dispatch network. …" }
```

## Management & consent

| Method | Path | Permission |
|---|---|---|
| POST/PATCH | `/admin/hospitals`, `/admin/hospitals/{id}` | `DIRECTORY_MANAGE` |
| POST | `/admin/hospitals/{id}/departments` | `DIRECTORY_MANAGE` |
| DELETE | `/admin/departments/{id}` | `DIRECTORY_MANAGE` |
| GET | `/admin/doctors` | `DOCTOR_VERIFY` or `DIRECTORY_MANAGE` |
| POST | `/admin/doctors/{id}/affiliation` | `DIRECTORY_MANAGE` |
| PATCH | `/doctors/me` (changing the licence number resets VERIFIED → PENDING) | `APPOINTMENT_DOCTOR` |
| GET/PUT | `/doctors/me/availability` (weekly windows, replaces schedule) | `APPOINTMENT_DOCTOR` |
| POST/GET | `/consents` (append-only; GET returns latest decision per purpose) | any |

Not implemented (listed for transparency): email verification, WebSocket/SSE streams.
