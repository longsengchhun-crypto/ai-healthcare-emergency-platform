# Testing Report

All figures below come from commands actually run on 2026-10-10 on Windows 11 (JDK 21.0.12, Maven 3.9.9,
Flutter 3.47.7 / Dart 3.13.5). Nothing here is projected.

## Summary

| Suite | Command | Result |
|---|---|---|
| Backend (H2 + real PostgreSQL) | `cd backend && mvn verify` | **49 passed, 0 failed, 0 skipped** |
| Mobile static analysis | `flutter analyze` | No issues |
| Mobile tests | `flutter test` | **14 passed, 1 skipped** (live contract test needs `LIVE_API_URL`) |
| Mobile ↔ live backend contract test | `LIVE_API_URL=… flutter test test/live_backend_test.dart` | **passed** (run once against the packaged jar on H2) |
| Dashboard analysis / tests | `flutter analyze` / `flutter test` | No issues / **2 passed** |
| Dashboard build | `flutter build web --release` | built |
| Android debug APK | `flutter build apk --debug` | built |
| Android release AAB | `flutter build appbundle --release --dart-define=API_BASE_URL=…` | built (53.9 MB) and **signed** with a locally generated upload key (`jarsigner -verify`: jar verified); API URL was a placeholder |

## Backend tests (37)

| Class | Tests | Notes |
|---|---|---|
| `AuthIntegrationTest` + `AuthPostgresTest` | 6 + 6 | register/login/me, generic invalid-login message, 401 without token, refresh rotation + reuse revocation, duplicate registration 409, validation 422 |
| `FlowIntegrationTest` + `FlowPostgresTest` | 4 + 4 | booking → conflict → IDOR 404 → forbidden confirm → doctor confirm → invalid transition 409 → cancel frees slot; client-supplied status ignored; emergency create, idempotent retry, missing key 400, IDOR, role boundaries, skip-state 409, full lifecycle to RESOLVED, terminal cancel 409, patient cancel |
| `SecurityAndRecordsIntegrationTest` + `SecurityRecordsPostgresTest` | 8 + 8 | staff blocked from records/admin, patient blocked from admin/clinical types, record isolation + grant/revoke + audited denial, clinician authorship & amendments, upload sniffing/sanitising/authorisation, triage rules, AI summary labelled & verbatim, reminder lifecycle/timezone validation |
| `AiEvaluationTest` | 1 | measures triage rules, asserts zero missed emergencies on fixture |
| `NotificationChannelsTest` | 4 | SMS only with consent / never for demo events / retry then FAILED (no false "sent"); Twilio REST client against a local mock server (auth header, form body, error surfacing); push outbox with a fake gateway (SENT, back-off, FAILED, NOT_CONFIGURED) |
| `ManagementTest` | 4 | hospital/department CRUD permissions + validation, doctor availability self-service, admin doctor list, consent history, retention keeps active-event locations |

The `*PostgresTest` classes subclass the H2 tests and run them against embedded real PostgreSQL (zonky binaries
16.9). This caught a real defect during development: nullable `:param IS NULL` filters failed on PostgreSQL
("could not determine data type of parameter") while passing on H2; fixed with explicit `CAST`.

## Mobile tests

* `accident_detector_test.dart` (4): impact+rotation+stillness ⇒ candidate; impact without rotation ⇒ none;
  continued movement ⇒ none; normal walking ⇒ none.
* `widgets_test.dart` (10): form validators (3), hold-to-confirm ignores a quick tap / fires on sustained hold / inert
  when disabled, error view with retry, empty view, emergency wording ("submitted" never says help is on the way),
  terminal/cancel flags.
* `live_backend_test.dart`: real `ApiClient` + models against a running backend — login, `/users/me`, directory,
  booking, doctor confirmation, double-booking → `ErrorKind.conflict`, idempotent emergency create/retry, staff
  acknowledgement visible to patient, patient forbidden from staff action, triage red flag.

## Not run / not verified

* **Real providers**: FCM credentials were validated against Firebase (a fake device token was rejected as invalid, not unauthorised). SMTP: a real password-reset email was accepted by Gmail SMTP (no error logged; inbox delivery confirmed by the owner is pending). Twilio was only exercised against a local mock server.

* **Docker (verified later the same day)**: `docker compose config` passed; `docker compose up --build` built the
  backend image, started PostgreSQL 16 and the backend, both reported `healthy`; against that stack a demo patient
  created an emergency (`SUBMITTED`) and demo staff acknowledged it (`ACKNOWLEDGED`). Image vulnerability scan not run.
* **GitHub Actions**: run #2 (commit 9b458fd, manual dispatch) passed all three jobs: backend `mvn verify`, mobile analyze + test + debug APK, compose validation. The dashboard is not in the workflow.
* **On-device / emulator run**: no emulator or phone was available; the Android UI, runtime permission prompts,
  GPS, sensors, local notifications and tel:/geo: intents were **not exercised**. Only compilation, static analysis,
  unit/widget tests and the API contract test were run.
* **Reschedule UI, consent capture and the new dashboard pages** are compiled and analysed but have no UI tests.
* **Widget tests of full screens** (login, emergency, booking) with mocked providers are not written.
* **Concurrency**: no multi-threaded double-booking/idempotency race test; correctness rests on the DB constraints.
* **Load, accessibility audit (TalkBack), contrast audit, dashboard UI tests, rate-limit behaviour test**: not done.
* **Play-signing / upload**: the AAB is signed with a *locally generated* key that is not registered with Play.
* **Offline behaviour**: errors are surfaced; no offline cache exists to test.

## Reproduce

```bash
cd backend && mvn verify
cat backend/target/ai-evaluation.txt
cd apps/mobile && flutter analyze && flutter test
cd apps/dashboard && flutter analyze && flutter test
```
