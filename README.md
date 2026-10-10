# AI Healthcare & Emergency Response Platform

Capstone project for *Advanced Flutter Application Development* — a HealthTech platform with a Flutter patient/doctor
app, a Spring Boot + PostgreSQL backend, and a Flutter Web operations dashboard.

> **Honesty notice.** This is a demonstration platform. It is **not** a medical device, it does **not** dispatch real
> ambulances, and its "AI" is a deterministic rule-based demonstration provider (not a language model). See
> [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for exactly what is and is not implemented or verified.

## Repository layout

| Path | Contents |
|---|---|
| `backend/` | Spring Boot 3.5 / Java 21 REST API, Flyway migrations, tests |
| `apps/mobile/` | Flutter app (Android primary): patient + doctor experience |
| `apps/dashboard/` | Flutter Web dashboard for hospital staff / administrators |
| `infrastructure/` | `docker-compose.yml` (PostgreSQL + backend) |
| `database/` | ERD / schema pointers (migrations live in `backend/src/main/resources/db/migration`) |
| `docs/` | Academic submission package |
| `.github/workflows/ci.yml` | CI definition (not yet executed on GitHub) |

## Quick start (no Docker required)

Prerequisites: JDK 21, Maven 3.9, Flutter 3.47+ (Dart 3.13), Android SDK 35 (for APK/AAB).

```bash
# 1. Backend on an in-memory database with fictional demo data
cd backend
export JWT_SECRET="$(openssl rand -base64 48)"
export SEED_DEMO_DATA=true SEED_DEMO_PASSWORD='choose-a-demo-password'
export DB_URL='jdbc:h2:mem:dev;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1' DB_USER=sa DB_PASSWORD=
mvn spring-boot:run            # http://localhost:8080  (Swagger UI: /swagger-ui.html)

# 2. Mobile app (Android emulator reaches the host at 10.0.2.2)
cd apps/mobile && flutter pub get && flutter run

# 3. Dashboard
cd apps/dashboard && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Demo accounts (created only when `SEED_DEMO_DATA=true`; password = your `SEED_DEMO_PASSWORD`):

| Role | Email |
|---|---|
| Patient | `patient.demo@example.test` |
| Doctor | `doctor.demo@example.test`, `doctor2.demo@example.test` |
| Hospital staff | `staff.demo@example.test` |
| Administrator | `admin.demo@example.test` |

All demo records are flagged `is_demo` and use the reserved `.test` domain. **Never enable seeding in production.**

### With Docker Compose (PostgreSQL)

```bash
cp .env.example .env     # fill DB_PASSWORD and JWT_SECRET
docker compose -f infrastructure/docker-compose.yml --env-file .env up --build
```

> Windows note: `gradlew.bat` breaks when the project path contains `&` (this repo's parent folder does). Build the
> Android app from a path without it, e.g. `subst M: "<path>\apps\mobile"` then build from `M:\`.

## Build and test

```bash
cd backend && mvn verify                       # 45 tests, H2 + embedded real PostgreSQL
cd apps/mobile && flutter analyze && flutter test
cd apps/dashboard && flutter analyze && flutter test
cd apps/mobile && flutter build apk --debug
cd apps/mobile && flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-api-host>
```

Live contract test (mobile client ↔ running backend):
`LIVE_API_URL=http://localhost:8080 flutter test test/live_backend_test.dart`

## Documentation

Push / SMS / email setup: [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md). Start at [docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md). Release steps:
[docs/PLAY_STORE_RELEASE.md](docs/PLAY_STORE_RELEASE.md). Verified results:
[docs/TESTING_REPORT.md](docs/TESTING_REPORT.md).
