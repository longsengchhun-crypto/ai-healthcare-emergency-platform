# Project Proposal — AI Healthcare & Emergency Response Platform

**Course:** Advanced Flutter Application Development · **Industry:** HealthTech
(Note: the supplied course PDF labels this concept "Project 5"; Project 7 is the retail concept — this repository
implements the healthcare project.)

## Problem
Coordinating appointments, health records and medication is fragmented, and asking for help quickly (with a location)
and tracking that request is hard. Hospitals need an auditable queue rather than ad-hoc calls.

## Solution
A Flutter mobile app (patients, doctors), a Spring Boot + PostgreSQL API, and a Flutter Web operations dashboard:
discovery and booking, patient-controlled records, medication reminders, an emergency request workflow with a
backend-authoritative state machine, an opt-in sensor safety check, and clearly labelled AI assistance.

## Scope (delivered)
Authentication with rotating sessions; RBAC with least-privilege roles; directory and booking with DB-level
double-booking protection; records with authorship/amendment rules and grants; reminders; emergency workflow with
idempotency and audit; deterministic triage/summary/extraction; dashboard; Docker/CI definitions; Android debug and
(locally signed) release bundle; test suites on H2 and real PostgreSQL.

## Out of scope / future work
Real dispatch integrations, SMS/push providers, a language-model/OCR provider, mobile availability editor, maps, offline cache, real-time sockets, localisation (Khmer), clinical validation, regulatory assessment.

## Success criteria and measured status
| Criterion | Result |
|---|---|
| Core flows work end to end through the real API | ✅ contract + integration tests |
| Authorisation boundaries enforced and tested | ✅ 41 backend tests incl. PostgreSQL |
| Emergency never reports false success | ✅ by design + tests |
| AI never presented as diagnosis; evaluation reported honestly | ✅ AI_DOCUMENTATION |
| Release-ready Android build | 🟡 signed AAB builds (local upload key, placeholder API URL); Play Console steps documented, not performed |

## Risks
Medical safety (mitigated by labelling + deterministic red flags), privacy (data minimisation, audit), unverified
device behaviour (see TESTING_REPORT), and the absence of any real emergency integration (explicitly disclosed).
