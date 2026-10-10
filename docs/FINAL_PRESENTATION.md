# Final Presentation Outline (≈ 15 min)

1. **Title & framing (1 min)** — HealthTech capstone; "honest by design" principle.
2. **Problem (1 min)** — fragmented care, slow help requests, opaque status.
3. **Solution overview (2 min)** — three apps + API; architecture diagram (SYSTEM_ARCHITECTURE §1).
4. **Live demo (5 min)** — follow DEMO_SCRIPT: book → confirm → emergency → acknowledge/assign → audit log.
5. **Engineering highlights (3 min)**
   * Emergency state machine + idempotency key + append-only history
   * DB-level double-booking guard (`slot_key`)
   * Refresh-token rotation with reuse detection
   * Staff cannot read medical records; object-level 404 + audited denials
   * Found a real PostgreSQL-only bug through the dual H2/PostgreSQL test strategy
6. **AI (1.5 min)** — what it is and is not; evaluation numbers and why they are optimistic.
7. **Quality evidence (1 min)** — 41 backend + 14 mobile + 2 dashboard tests, contract test, builds.
8. **Limitations & next steps (1.5 min)** — KNOWN_ISSUES highlights: no real dispatch/push/SMS, unverified on a
   physical device, AAB signed only with a local key and not uploaded.
9. **Q&A.**

Backup slides: ER diagram, permission matrix, security controls table, Play Store checklist.
