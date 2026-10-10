# Deployment Guide

> Status: the Docker/Compose path (section 3) was **verified locally**: image build, PostgreSQL + backend health,
> and an emergency create/acknowledge flow. Sections 4-6 (cloud host, TLS proxy, managed DB) were **not** exercised
> because no cloud account exists; treat them as a starting point.

## 1. Environments

| Env | DB | Seed | Notes |
|---|---|---|---|
| dev | H2 in-memory or compose PostgreSQL | `SEED_DEMO_DATA=true` ok | Swagger UI on |
| staging | managed PostgreSQL | demo seed only with fictional data | production-like TLS |
| production | managed PostgreSQL | **never** | secrets from a secret manager |

## 2. Configuration (environment variables)

| Variable | Required | Meaning |
|---|---|---|
| `DB_URL`, `DB_USER`, `DB_PASSWORD` | yes | JDBC connection (`jdbc:postgresql://host:5432/healthplatform`) |
| `JWT_SECRET` | yes | ≥ 32 bytes; app refuses to start otherwise |
| `CORS_ALLOWED_ORIGINS` | yes (dashboard) | comma-separated exact origins |
| `STORAGE_ROOT` | yes | private document directory (mounted volume) |
| `SEED_DEMO_DATA`, `SEED_DEMO_PASSWORD` | dev only | fictional demo accounts |
| `AI_PROVIDER` | no | only `deterministic-demo` exists |
| `DEV_LOG_RESET_TOKENS` | dev only | logs reset tokens; never in production |
| `PORT` | no | default 8080 |

## 3. Docker Compose (development)

```bash
cp .env.example .env            # set DB_PASSWORD, JWT_SECRET
docker compose -f infrastructure/docker-compose.yml --env-file .env up --build
curl http://localhost:8080/actuator/health
```

The compose file binds PostgreSQL and the API to `127.0.0.1` only and persists data in named volumes.

## 4. Production outline

1. Provision PostgreSQL 16 (managed), create a **migration role** (DDL) and a **runtime role** (DML only); point
   Flyway at the migration role in a pre-deploy job and the app at the runtime role.
2. Build and push the image: `docker build -t registry/healthresponse-api:1.0.0 backend`.
3. Run behind an HTTPS reverse proxy (nginx/Caddy/cloud LB) with TLS 1.2+, HSTS, request size limit 12 MB, and
   forwarded headers (`server.forward-headers-strategy=framework`) so rate limiting sees client IPs.
4. Mount an encrypted volume at `STORAGE_ROOT`; back it up with the database.
5. Set an administrator-verified `emergency.local_number` via `PUT /api/v1/admin/settings/emergency.local_number`.
6. Create the first administrator out of band (no default admin exists): register a user, then promote it with SQL
   in a controlled session, e.g.
   `INSERT INTO user_roles SELECT u.id, r.id FROM users u, roles r WHERE u.email='…' AND r.name='SYSTEM_ADMIN';`
   then delete the PATIENT row for that user and have them sign in again.
7. Health/monitoring: `/actuator/health/liveness|readiness`; ship stdout JSON/text logs to your log platform; alert on
   5xx rate, emergency events stuck in `SUBMITTED` (see `/admin/overview`), and `notification_delivery_attempts` in
   `FAILED`.
8. Dashboard: `flutter build web --release --dart-define=API_BASE_URL=https://api.<host>`; serve the `build/web`
   directory from static hosting; add that origin to `CORS_ALLOWED_ORIGINS`.

## 5. CI/CD

`.github/workflows/ci.yml` runs backend `mvn verify`, mobile analyze/test/debug APK, and compose validation on PRs and
`main`. It performs **no deployment**; add a manually-approved deploy job per environment. Not yet executed.

## 6. Rollback

Roll back the application image; Flyway migrations are forward-only — write a compensating migration rather than
editing applied ones.
