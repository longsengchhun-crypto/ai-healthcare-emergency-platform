# Database Schema

Authoritative DDL: [`V1__core_schema.sql`](../backend/src/main/resources/db/migration/V1__core_schema.sql) and
[`V2__roles_permissions.sql`](../backend/src/main/resources/db/migration/V2__roles_permissions.sql). Flyway applies them
on startup to an empty database. They were verified on real PostgreSQL (embedded 16.x binaries in the test suite) and on
H2 in PostgreSQL mode.

## Tables (36)

| Group | Tables |
|---|---|
| Identity & access | `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `refresh_token_sessions`, `password_reset_tokens` |
| Patients | `patient_profiles`, `emergency_contacts`, `record_access_grants` |
| Directory | `hospitals`, `hospital_departments`, `hospital_staff`, `doctor_profiles`, `doctor_verification_records`, `doctor_hospital_affiliations`, `doctor_availability` |
| Appointments | `appointments` |
| Records | `medical_records`, `medical_record_documents` |
| Medication | `medications`, `medication_reminders`, `medication_adherence_events` |
| Emergency | `emergency_events`, `emergency_event_locations`, `emergency_event_history`, `responder_assignments` |
| Sensors | `accident_detection_events`, `sensor_readings` |
| Notifications | `device_tokens`, `notifications`, `notification_delivery_attempts` |
| Governance | `consent_records`, `audit_logs`, `ai_processing_records`, `system_settings` |

## Indexes

`ix_refresh_user`, `ix_refresh_family`, `ix_ec_patient`, `ix_appt_patient (patient_id, starts_at)`,
`ix_appt_doctor (doctor_id, starts_at)`, `ix_record_patient`, `ix_grant_patient`, `ix_emergency_status
(status, created_at)`, `ix_emergency_patient`, `ix_emergency_history (event_id, created_at)`, `ix_notif_user`,
`ix_delivery_pending (status, next_attempt_at)`, `ix_consent_user`, `ix_audit_created`, `ix_audit_actor`.

## Reference data (V2)

Roles: `PATIENT`, `DOCTOR`, `HOSPITAL_STAFF`, `SYSTEM_ADMIN`. 15 permissions mapped per role. Note that
`HOSPITAL_STAFF` and `SYSTEM_ADMIN` deliberately have **no** `RECORD_VIEW_OWN` / `RECORD_WRITE_CLINICAL`.

## Seed data

`DemoDataSeeder` (backend code, not SQL) creates two fictional hospitals, three departments, two doctors with
Mon–Fri 09:00–12:00 availability, one patient, one staff user and one administrator. It runs only when
`SEED_DEMO_DATA=true` **and** `SEED_DEMO_PASSWORD` (≥ 10 chars) is provided; no password exists in source control.

## Unused / reserved

`consent_records` is created and indexed but no endpoint writes to it yet. `ai_processing_records` stores metadata
only (feature, provider, status, latency) — never prompts or outputs.

## Backup and restore (PostgreSQL)

```bash
pg_dump -Fc -h <host> -U healthapp healthplatform > healthplatform_$(date +%F).dump
pg_restore -h <host> -U healthapp -d healthplatform_restored --clean --if-exists healthplatform_YYYY-MM-DD.dump
```

Back up the private document volume (`/data/private-documents`) together with the database; document rows reference
files by `storage_key`. Test restores before relying on them. Encrypt backups at rest.
