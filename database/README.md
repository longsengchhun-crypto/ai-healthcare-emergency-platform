# Database

Migrations are owned by the backend (Flyway) so schema and code version together:

* `backend/src/main/resources/db/migration/V1__core_schema.sql` — 36 tables, constraints, indexes
* `backend/src/main/resources/db/migration/V2__roles_permissions.sql` — roles, permissions, mapping, settings

Documentation: [ERD](../docs/DATABASE_ERD.md) · [schema](../docs/DATABASE_SCHEMA.md).

Demo data is created by `DemoDataSeeder` (backend), not by SQL, so that no credentials ever live in a script.
`erd/`, `schema/`, `seeds/`, `migrations/` placeholders are intentionally empty to avoid duplicating the source of truth.
