# Repeatable End-to-End Demonstration

All data is fictional. Replace `<pw>` with the `SEED_DEMO_PASSWORD` you chose.

## 0. Start the system

```bash
cd backend
export JWT_SECRET="$(openssl rand -base64 48)" SEED_DEMO_DATA=true SEED_DEMO_PASSWORD='<pw>'
export DB_URL='jdbc:h2:mem:demo;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1' DB_USER=sa DB_PASSWORD=
mvn spring-boot:run
```
(or `docker compose …` for PostgreSQL). Dashboard: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080`.
Mobile: `flutter run` on an emulator.

## 1. Patient journey (mobile, `patient@demo.test`)

1. Sign in → Profile → Health profile: set date of birth / blood group; add an emergency contact.
2. Discover → *Dr. Demo Cardiologist* (labelled unverified/sample) → pick tomorrow or the next weekday → request.
3. Appointments shows **REQUESTED**.

## 2. Doctor confirms (`doctor@demo.test`)

4. Sign in on a second emulator/profile (or sign out) → Schedule → *Confirm*.
5. Back as patient: pull to refresh → **CONFIRMED**; Notifications shows the confirmation.

## 3. Records, medication, AI

6. Records → *Add note* with lines `Allergy: pollen`, `Medication: Vitamin D`, `Diagnosis: demo condition`.
7. Medications → add *Vitamin D* → *Add reminder* (08:00).
8. Health assistant → *Summary* → *Summarise my records* (see labelled deterministic output with sources);
   *Symptoms* → "severe chest pain and shortness of breath" → emergency guidance.

## 4. Emergency

9. Emergency tab → leave *Demonstration event* on → press and hold. Status **SUBMITTED**.
10. Dashboard (`staff@demo.test`) → Emergency queue → open event → *Acknowledge* → *Assign responder*
    (Dr. Demo Cardiologist) → *Mark responder en route* → *arrived* → *resolved*.
11. Phone shows each status within ~5 s, with timeline entries and "last confirmed by server" time.
12. Dashboard (`admin@demo.test`) → Audit log: `EMERGENCY_CREATE`, `EMERGENCY_VIEW_STAFF`,
    `EMERGENCY_ACKNOWLEDGE`, `EMERGENCY_ASSIGN`, `EMERGENCY_STATUS_*`.

## 5. Sensors (demonstration mode)

13. Profile → Safety sensors → *Simulate a possible incident* → "Are you OK?" with DEMONSTRATION label → *I'm OK*.

## 6. Tests and build

```bash
cd backend && mvn verify
cd apps/mobile && flutter test && LIVE_API_URL=http://localhost:8080 flutter test test/live_backend_test.dart
cd apps/mobile && flutter build apk --debug
```
