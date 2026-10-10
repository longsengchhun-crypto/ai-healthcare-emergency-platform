# Original brief vs. what exists

Honest line-by-line check of the first build prompt (sections 1–28) against this repository.
✅ done and verified · 🟡 done but not fully verified or only partly · ❌ not done.

## 3. Technology stack

| Brief | Status | Notes |
|---|---|---|
| Flutter, Material 3, Riverpod, GoRouter, Dio, secure storage | ✅ | Riverpod 3, GoRouter 18 |
| Freezed / json_serializable | ❌ | hand-written `fromJson`; brief said "where appropriate" |
| Geolocation, sensors, local persistence | ✅ | geolocator, sensors_plus, shared_preferences |
| **Google Maps** | ❌ | replaced by **OpenStreetMap** (`flutter_map`, no key needed) on hospital detail; no routes |
| FCM | 🟡 | implemented end to end; server credentials validated; **real push to a phone not yet observed** |
| Spring Boot, OpenAPI, PostgreSQL, JWT, Flyway, validation, audit | ✅ | 49 tests on H2 + real PostgreSQL |
| **Redis** | ❌ | not used (in-memory rate limiter) |
| **WebSocket / SSE** | ❌ | 5-second polling |
| Structured (JSON) logging | ❌ | plain logs |
| Flutter Web dashboard | ✅ | |
| Docker, Compose, GitHub Actions, AAB, signing | ✅ | CI green; AAB signed with a local upload key |
| Cloud deployment performed | ❌ | documented only (no cloud account) |

## 4. Structure
Required folders exist. `infrastructure/nginx` and `monitoring` are empty placeholders. Mobile features use
screen + controller files, **not** strict presentation/domain/data layers per feature (🟡 pragmatic deviation).

## 5. UI / UX
| Requirement | Status |
|---|---|
| Distinct design system (palette tokens, type scale, spacing, line illustrations, custom nav) | ✅ `core/design/` |
| Khmer-first UI with EN switch, bundled Noto Sans Khmer | ✅ ~all screens; spelling not reviewed by a native speaker |
| Skeleton loaders, empty/error/offline states, hero + page transitions | ✅ |
| Light + dark theme | 🟡 implemented; dark not visually reviewed |
| Tablet / large-screen layout | 🟡 content max-width only; not tested on a tablet |
| Accessibility (touch targets, semantic hold-button alternative, text scaling) | 🟡 not audited with TalkBack |
| Emergency button prominent but protected | ✅ centre red tab + press-and-hold |
| Real photographs of doctors | ❌ illustrated avatars on purpose (see KNOWN_ISSUES #34) |

## 6–12 Roles and core features
Roles/permissions ✅ · doctor verification ✅ · hospital staff cannot read records ✅ · registration/login/refresh/reset ✅ ·
**email verification of new accounts ❌** · **session/device management screen ❌** · patient profile ✅ (profile photo ❌) ·
directory search/filters/distance ✅ · appointments + state machine ✅ · records + amendments + documents ✅
(**archive/delete endpoint ❌**, only local-disk storage, no object-storage abstraction) · medications + reminders ✅
(adherence has an API but **no UI** ❌).

## 13–15 Emergency, GPS, sensors
State machine, idempotency, history, staff actions ✅ · "request not confirmed" handling ✅ · call shortcut ✅ ·
SMS to contacts 🟡 (needs Twilio credentials; consent-gated) · map with marker ✅ (hospital only; **not live-tracking**) ·
no background location ✅ · sensor detector + countdown + demo mode ✅ (device behaviour unverified).

## 16 AI
Provider boundary + deterministic triage/summary/extraction ✅ (honestly labelled) · **real LLM ❌ · OCR ❌** ·
evaluation numbers reported with limits ✅ (`AI_DOCUMENTATION.md`).

## 17–23 Notifications, DB, API, dashboard, security, offline
Notification categories, inbox, outbox/retry ✅ · 36 tables with constraints ✅ · all listed endpoint groups ✅ ·
dashboard: overview, queue + detail, doctors, hospitals, appointments, users/roles, audit, system status ✅,
**"patient access workflows" page ❌** · security controls ✅ (self-review only) · least-privilege DB role 🟡 documented ·
offline: read cache for directories ✅, **queue for non-critical writes ❌**, emergencies never queued ✅.

## 24 Testing
Backend: 49 tests incl. security, IDOR, concurrency-by-constraint, retention, channels ✅.
Mobile: 14 unit/widget tests + contract test + render previews 🟡 (**no per-screen widget tests, no integration tests on a
device, no accessibility tests**). Dashboard: 2 tests 🟡. Rate-limit behaviour test ❌. Load/security scans ❌.

## 25–26 Delivery and Android
Dockerfile, Compose, CI ✅ (all run) · release signing ✅ (local key) · AAB ✅ · **branded native splash ❌** (default) ·
adaptive icon ❌ (legacy PNG icon) · target SDK = Flutter default, must be re-checked at submission 🟡 ·
Play Console steps documented ✅, **not submitted**.

## 27–28 Documents and demo
All listed documents exist ✅ (`docs/`). Demo script ✅. Phone preview verified by the owner on an iPhone browser 🟡;
**no native Android device run**.

## Summary
Core product, security model, emergency workflow, Khmer data and UI, integrations and delivery pipeline are in place and
tested. Open gaps that matter most: **real-device verification**, real LLM/OCR, WebSocket updates, Redis,
email verification, and several smaller UI/workflow items listed above.
