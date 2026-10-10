# Known Issues, Gaps and Limitations

Honest register of what is **not** done or **not** verified. Severity: H = blocks real-world use, M = notable gap,
L = polish.

## Not implemented (specified in the brief)

| # | Gap | Sev |
|---|---|---|
| 1 | Real emergency dispatch, SMS/voice to emergency contacts (no provider; history records "contacts NOT notified") | H |
| 2 | Firebase Cloud Messaging: `PushGateway` boundary + outbox/retry exist; no FCM client, no `google-services.json`; deliveries end `NOT_CONFIGURED` | H |
| 3 | Email provider for password-reset / verification; email verification flow | H |
| 4 | Real AI provider / OCR (only deterministic demonstration provider) | M |
| 5 | ~~Hospital/department/doctor management~~ **Done**: `/admin/hospitals`, departments, affiliations, `/doctors/me*`; dashboard Hospitals & Doctors pages. Doctor availability has an API but no mobile editor UI | L |
| 6 | Google Maps embedding / routes (uses `geo:` intent and distance sort only) | M |
| 7 | WebSocket/SSE real-time updates (5 s polling instead) | M |
| 8 | Redis (rate limiting is in-memory; no caching) | M |
| 9 | Offline read cache; local queue for non-critical operations | M |
| 10 | ~~Retention & consent~~ **Done**: `RetentionJob` (daily) and `/consents`; mobile records privacy-notice and sensor consent. Retention windows are defaults, not legally reviewed | L |
| 11 | ~~Reschedule UI~~ **Done** (date picker + slot dialog); not UI-tested | L |
| 12 | `freezed`/`json_serializable` models (hand-written `fromJson` used) | L |
| 13 | Background location / background sensor monitoring (intentionally none: monitoring only while app is open) | — |
| 14 | Khmer localisation | M |
| 15 | Patient picker for doctors on mobile (doctors read records via `patientId` API; no UI) | M |

## Not verified

| # | Item |
|---|---|
| 16 | ~~Docker build/compose/health~~ **Verified 2026-10-10**: image builds, PostgreSQL 16 + backend start, both healthy, emergency create + staff acknowledge succeed over HTTP. Image not scanned; production topology (TLS proxy, managed DB) untested |
| 17 | ~~GitHub Actions execution~~ **Verified**: run #2 (manual dispatch on commit 9b458fd) passed backend, mobile and compose-validate. The dashboard is not part of the CI workflow |
| 18 | Any run on an Android emulator/device (UI polish, permissions, GPS, sensors, notifications, call/map intents) |
| 19 | Play-signing/upload and Play Console pre-launch report (AAB is signed with a local upload key) |
| 20 | Accessibility (TalkBack, contrast, large-text) |
| 21 | Performance/load |

## Defects / design caveats

| # | Issue | Sev |
|---|---|---|
| 22 | Rate limiter is per-instance and keyed on `remoteAddr`; set `FORWARD_HEADERS=framework` behind a proxy (now configurable) | L |
| 23 | ~~Seeder not atomic~~ **Fixed** (runs in a `TransactionTemplate`) | — |
| 24 | ~~`doctor(id)` inefficiency~~ **Fixed** (direct query) | — |
| 25 | Reminder timezone is hard-coded to `Asia/Phnom_Penh` in the mobile client | L |
| 26 | Accident detector thresholds are untuned heuristics; expect false positives/negatives; requires both accelerometer and gyroscope | M |
| 27 | Medication reminders use inexact alarms (can be delayed) and are lost on force-stop/reboot until the app reopens | M |
| 28 | Debug APK is 177 MB (all ABIs, debug); release AAB 53.9 MB | L |
| 29 | Hospital routing picks the nearest hospital record by distance (not capacity/specialty aware) | M |
| 30 | `emergency.local_number` defaults to `UNCONFIGURED`; an administrator must set a verified number | — |
| 31 | The Windows path containing `&` breaks `gradlew.bat` (workaround: `subst`) | L |
