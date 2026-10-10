# Security Report

Scope: backend, mobile app, dashboard as implemented in this repository. This is a developer self-review, not a
penetration test or third-party audit. **No legal/regulatory compliance (HIPAA, GDPR, Cambodian law, etc.) is
claimed**; qualified review is required before any real patient data is handled.

## 1. Controls implemented and how they were verified

| Control | Implementation | Verified by |
|---|---|---|
| Password storage | BCrypt cost 12; no plaintext anywhere | code review |
| Constant-ish login timing / enumeration | one hash check even for unknown email; identical 401 text; duplicate registration generic 409 | `invalidLoginUsesGenericMessage` |
| Lockout | 5 failures ⇒ 15 min lock | code review (not unit tested) |
| Access tokens | HS256 JWT, 15 min, only user id inside; roles/permissions reloaded from DB each request | `protectedEndpointRequiresToken` |
| Refresh tokens | opaque, SHA-256 hashed at rest, rotation, reuse ⇒ family revoked, atomic claim | `refreshRotatesAndReuseRevokesFamily` |
| Rate limiting | 10/min/IP on auth endpoints (in-memory) | code review (test profile raises limit) |
| RBAC | permissions per role in DB; `@PreAuthorize` + service ownership checks | `hospitalStaffCannotReadMedicalRecordsOrUseAdminEndpoints`, `patientCannotReachAdminOrClinicalEndpoints` |
| IDOR | object access returns 404 for non-owners and is audited | `recordIsolationBetweenPatientsAndDoctorAccessRules`, `appointmentBooking…` |
| Medical-record authorship | no update endpoint; amendments are new rows by original author; patients cannot amend clinician rows | `clinicianAuthoredRecordsCannotBeAltered…` |
| Upload safety | magic-byte sniffing (client type ignored), 10 MB cap, sanitised name, random storage key outside web root, `nosniff`, `no-store` | `uploadRejectsDisguisedFilesAndAcceptsRealPdf` |
| SQL injection | parameterised `JdbcClient` throughout; no string-built user input | code review |
| Emergency idempotency | unique `(patient_id, idempotency_key)` | `emergencyLifecycleWithIdempotencyAndAuthorization` |
| Double booking | unique `slot_key` | `appointmentBookingConfirmationAndDoubleBookingGuard` |
| Audit | RECORD_*, EMERGENCY_*, APPOINTMENT_*, AUTH_*, ADMIN actions; denied attempts persisted | audit assertions in tests |
| Error hygiene | central handler, no stack traces, `server.error.include-*` disabled | code review |
| CORS | allow-list from `CORS_ALLOWED_ORIGINS`, no wildcard | code review |
| Secrets | JWT secret required from env (≥ 32 bytes, startup fails otherwise); `.env`, keystores git-ignored; `.env.example` has no values | `JwtService` startup check |
| Transport | `usesCleartextTraffic=false` in main manifest; release build refuses non-HTTPS/localhost API URL | code review; AAB built |
| Mobile storage | tokens in Keystore-backed `flutter_secure_storage`; `allowBackup=false` | code review |
| Notification content | generic text, no medical details | code review |
| Dashboard | tokens in memory only | code review |

## 2. Hospital-operator data minimisation

`HOSPITAL_STAFF` has no record permissions. Emergency detail shows patient name/phone and shared location only;
allergies/conditions are **not** included. Staff only see events routed to their hospital or unrouted events.

## 3. Known weaknesses / not done (see KNOWN_ISSUES)

* Rate limiter is per-instance, keyed on `remoteAddr` (set `FORWARD_HEADERS=framework` behind a proxy, or move to Redis).
* No email verification; password-reset token delivery needs an email provider.
* No account-level MFA.
* Documents are not encrypted at the application layer; rely on volume/disk encryption.
* Retention: `RetentionJob` removes finished-event locations (90 d), sensor readings (30 d), expired/revoked sessions (30 d) and old reset tokens (7 d) daily; windows are defaults pending legal review. Audit logs are kept indefinitely.
* No database-level immutability for audit/history tables; the DB account used by the app is not least-privilege by
  default (create a separate migration role in production).
* No dependency vulnerability scan has been run; no SAST/DAST.
* JWT is symmetric (HS256); rotating the secret logs everyone out. No key rotation procedure beyond that.
* Static analysis of the Android release (obfuscation is R8 shrink only; no certificate pinning).
* `SEED_DEMO_DATA` must never be enabled in production; nothing prevents it technically other than discipline.

## 4. Encryption & key management requirements (for production)

TLS 1.2+ at the edge; PostgreSQL volume and backups encrypted at rest; document volume encrypted; secrets from a
secret manager (not env files on disk); upload keystore kept offline with a documented recovery path; rotate
`JWT_SECRET` on suspected leak.

## 5. Secret-leakage check

Test-only values exist in `backend/src/test/resources/application-test.yml` (test JWT secret, demo password for the
in-memory test DB). No production secret, keystore, `google-services.json`, or API key is present in the repository
(`.gitignore` excludes them). Re-run a scanner such as `gitleaks` before publishing.
