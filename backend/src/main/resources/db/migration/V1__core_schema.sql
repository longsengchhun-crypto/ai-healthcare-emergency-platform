-- AI Healthcare & Emergency Response Platform - core schema (PostgreSQL; also H2 in PostgreSQL mode for tests)
-- All timestamps are UTC.

-- ---------- Identity & access ----------
CREATE TABLE roles (
    id          UUID PRIMARY KEY,
    name        VARCHAR(40) NOT NULL UNIQUE,
    description VARCHAR(255)
);

CREATE TABLE permissions (
    id          UUID PRIMARY KEY,
    code        VARCHAR(80) NOT NULL UNIQUE,
    description VARCHAR(255)
);

CREATE TABLE role_permissions (
    role_id       UUID NOT NULL REFERENCES roles (id),
    permission_id UUID NOT NULL REFERENCES permissions (id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE users (
    id                UUID PRIMARY KEY,
    email             VARCHAR(255) NOT NULL,
    password_hash     VARCHAR(100) NOT NULL,
    full_name         VARCHAR(150) NOT NULL,
    phone             VARCHAR(32),
    status            VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    email_verified    BOOLEAN      NOT NULL DEFAULT FALSE,
    failed_logins     INT          NOT NULL DEFAULT 0,
    locked_until      TIMESTAMP WITH TIME ZONE,
    deleted_at        TIMESTAMP WITH TIME ZONE,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT ck_users_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DEACTIVATED'))
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users (id),
    role_id UUID NOT NULL REFERENCES roles (id),
    PRIMARY KEY (user_id, role_id)
);

-- Refresh-token sessions: only a SHA-256 hash of the token is stored, never the token itself.
CREATE TABLE refresh_token_sessions (
    id             UUID PRIMARY KEY,
    user_id        UUID NOT NULL REFERENCES users (id),
    family_id      UUID NOT NULL,
    token_hash     VARCHAR(64) NOT NULL,
    device_label   VARCHAR(120),
    expires_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at     TIMESTAMP WITH TIME ZONE,
    replaced_by_id UUID,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
);
CREATE INDEX ix_refresh_user ON refresh_token_sessions (user_id);
CREATE INDEX ix_refresh_family ON refresh_token_sessions (family_id);

CREATE TABLE password_reset_tokens (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users (id),
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at    TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- ---------- Patients ----------
CREATE TABLE patient_profiles (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL UNIQUE REFERENCES users (id),
    date_of_birth    DATE,
    gender           VARCHAR(20),
    blood_group      VARCHAR(5),
    allergies        VARCHAR(1000),
    conditions       VARCHAR(1000),
    address          VARCHAR(255),
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE emergency_contacts (
    id           UUID PRIMARY KEY,
    patient_id   UUID NOT NULL REFERENCES patient_profiles (id),
    name         VARCHAR(150) NOT NULL,
    relationship VARCHAR(60),
    phone        VARCHAR(32) NOT NULL,
    priority     INT NOT NULL DEFAULT 1,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_ec_patient ON emergency_contacts (patient_id);

-- ---------- Hospitals & doctors ----------
CREATE TABLE hospitals (
    id         UUID PRIMARY KEY,
    name       VARCHAR(200) NOT NULL,
    address    VARCHAR(255),
    city       VARCHAR(100),
    phone      VARCHAR(32),
    latitude   DOUBLE PRECISION,
    longitude  DOUBLE PRECISION,
    is_demo    BOOLEAN NOT NULL DEFAULT FALSE,
    active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE hospital_departments (
    id          UUID PRIMARY KEY,
    hospital_id UUID NOT NULL REFERENCES hospitals (id),
    name        VARCHAR(120) NOT NULL,
    CONSTRAINT uq_department UNIQUE (hospital_id, name)
);

CREATE TABLE doctor_profiles (
    id                  UUID PRIMARY KEY,
    user_id             UUID NOT NULL UNIQUE REFERENCES users (id),
    specialty           VARCHAR(120) NOT NULL,
    bio                 VARCHAR(1000),
    license_number      VARCHAR(60),
    verification_status VARCHAR(20) NOT NULL DEFAULT 'UNVERIFIED',
    is_demo             BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_doctor_verification CHECK (verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED'))
);

CREATE TABLE doctor_verification_records (
    id           UUID PRIMARY KEY,
    doctor_id    UUID NOT NULL REFERENCES doctor_profiles (id),
    status       VARCHAR(20) NOT NULL,
    reviewed_by  UUID REFERENCES users (id),
    note         VARCHAR(500),
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE doctor_hospital_affiliations (
    doctor_id   UUID NOT NULL REFERENCES doctor_profiles (id),
    hospital_id UUID NOT NULL REFERENCES hospitals (id),
    department_id UUID REFERENCES hospital_departments (id),
    PRIMARY KEY (doctor_id, hospital_id)
);

-- Hospital staff / responders belong to a hospital
CREATE TABLE hospital_staff (
    user_id     UUID NOT NULL REFERENCES users (id),
    hospital_id UUID NOT NULL REFERENCES hospitals (id),
    PRIMARY KEY (user_id, hospital_id)
);

CREATE TABLE doctor_availability (
    id          UUID PRIMARY KEY,
    doctor_id   UUID NOT NULL REFERENCES doctor_profiles (id),
    day_of_week INT NOT NULL,
    start_time  TIME NOT NULL,
    end_time    TIME NOT NULL,
    slot_minutes INT NOT NULL DEFAULT 30,
    CONSTRAINT ck_dow CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT ck_avail_range CHECK (end_time > start_time)
);

-- ---------- Appointments ----------
-- slot_key is populated only while the appointment holds its slot (REQUESTED / CONFIRMED).
-- A UNIQUE constraint on slot_key therefore prevents double booking at the database level
-- (NULLs are distinct, so cancelled/completed rows never block a slot).
CREATE TABLE appointments (
    id          UUID PRIMARY KEY,
    patient_id  UUID NOT NULL REFERENCES patient_profiles (id),
    doctor_id   UUID NOT NULL REFERENCES doctor_profiles (id),
    hospital_id UUID REFERENCES hospitals (id),
    starts_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    status      VARCHAR(20) NOT NULL,
    reason      VARCHAR(500),
    slot_key    VARCHAR(80),
    version     BIGINT NOT NULL DEFAULT 0,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_appointment_slot UNIQUE (slot_key),
    CONSTRAINT ck_appt_status CHECK (status IN ('REQUESTED', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'REJECTED')),
    CONSTRAINT ck_appt_range CHECK (ends_at > starts_at)
);
CREATE INDEX ix_appt_patient ON appointments (patient_id, starts_at);
CREATE INDEX ix_appt_doctor ON appointments (doctor_id, starts_at);

-- ---------- Medical records ----------
CREATE TABLE medical_records (
    id             UUID PRIMARY KEY,
    patient_id     UUID NOT NULL REFERENCES patient_profiles (id),
    author_user_id UUID NOT NULL REFERENCES users (id),
    author_kind    VARCHAR(20) NOT NULL,
    record_type    VARCHAR(30) NOT NULL,
    title          VARCHAR(200) NOT NULL,
    body           TEXT,
    amends_id      UUID REFERENCES medical_records (id),
    archived_at    TIMESTAMP WITH TIME ZONE,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_record_author CHECK (author_kind IN ('PATIENT', 'CLINICIAN')),
    CONSTRAINT ck_record_type CHECK (record_type IN ('CLINICAL_NOTE', 'PRESCRIPTION', 'TEST_REPORT', 'DISCHARGE_SUMMARY', 'DOCUMENT', 'HISTORY'))
);
CREATE INDEX ix_record_patient ON medical_records (patient_id, created_at);

CREATE TABLE medical_record_documents (
    id           UUID PRIMARY KEY,
    record_id    UUID NOT NULL REFERENCES medical_records (id),
    file_name    VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    size_bytes   BIGINT NOT NULL,
    storage_key  VARCHAR(255) NOT NULL,
    sha256       VARCHAR(64) NOT NULL,
    uploaded_by  UUID NOT NULL REFERENCES users (id),
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Grants: a patient explicitly authorises a doctor to view their records.
CREATE TABLE record_access_grants (
    id         UUID PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES patient_profiles (id),
    doctor_id  UUID NOT NULL REFERENCES doctor_profiles (id),
    expires_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_grant_patient ON record_access_grants (patient_id);

-- ---------- Medications ----------
CREATE TABLE medications (
    id           UUID PRIMARY KEY,
    patient_id   UUID NOT NULL REFERENCES patient_profiles (id),
    name         VARCHAR(150) NOT NULL,
    dosage       VARCHAR(100),
    instructions VARCHAR(500),
    source       VARCHAR(20) NOT NULL DEFAULT 'USER_ENTERED',
    record_id    UUID REFERENCES medical_records (id),
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_med_source CHECK (source IN ('USER_ENTERED', 'PRESCRIPTION'))
);

CREATE TABLE medication_reminders (
    id            UUID PRIMARY KEY,
    medication_id UUID NOT NULL REFERENCES medications (id),
    time_of_day   TIME NOT NULL,
    timezone      VARCHAR(60) NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_reminder_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE medication_adherence_events (
    id          UUID PRIMARY KEY,
    reminder_id UUID NOT NULL REFERENCES medication_reminders (id),
    outcome     VARCHAR(12) NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_adherence CHECK (outcome IN ('TAKEN', 'SKIPPED'))
);

-- ---------- Emergency ----------
CREATE TABLE emergency_events (
    id               UUID PRIMARY KEY,
    patient_id       UUID NOT NULL REFERENCES patient_profiles (id),
    hospital_id      UUID REFERENCES hospitals (id),
    status           VARCHAR(30) NOT NULL,
    trigger_source   VARCHAR(30) NOT NULL,
    description      VARCHAR(500),
    idempotency_key  VARCHAR(80) NOT NULL,
    is_demo          BOOLEAN NOT NULL DEFAULT FALSE,
    acknowledged_by  UUID REFERENCES users (id),
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    version          BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uq_emergency_idem UNIQUE (patient_id, idempotency_key),
    CONSTRAINT ck_emergency_status CHECK (status IN ('CREATED', 'SUBMITTED', 'ACKNOWLEDGED', 'RESPONDER_ASSIGNED',
        'RESPONDER_EN_ROUTE', 'ARRIVED', 'RESOLVED', 'CANCELLED', 'REJECTED', 'FAILED')),
    CONSTRAINT ck_emergency_trigger CHECK (trigger_source IN ('MANUAL', 'SENSOR_COUNTDOWN', 'DEMO'))
);
CREATE INDEX ix_emergency_status ON emergency_events (status, created_at);
CREATE INDEX ix_emergency_patient ON emergency_events (patient_id, created_at);

CREATE TABLE emergency_event_locations (
    id          UUID PRIMARY KEY,
    event_id    UUID NOT NULL REFERENCES emergency_events (id),
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    accuracy_m  DOUBLE PRECISION,
    captured_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT ck_lon CHECK (longitude BETWEEN -180 AND 180)
);

-- Append-only history: rows are only ever inserted.
CREATE TABLE emergency_event_history (
    id          UUID PRIMARY KEY,
    event_id    UUID NOT NULL REFERENCES emergency_events (id),
    from_status VARCHAR(30),
    to_status   VARCHAR(30) NOT NULL,
    actor_id    UUID REFERENCES users (id),
    note        VARCHAR(500),
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_emergency_history ON emergency_event_history (event_id, created_at);

CREATE TABLE responder_assignments (
    id           UUID PRIMARY KEY,
    event_id     UUID NOT NULL REFERENCES emergency_events (id),
    responder_id UUID NOT NULL REFERENCES users (id),
    assigned_by  UUID NOT NULL REFERENCES users (id),
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

-- ---------- Sensors ----------
-- A candidate incident is only ever a *possible* incident, never a confirmed accident.
CREATE TABLE accident_detection_events (
    id                 UUID PRIMARY KEY,
    user_id            UUID NOT NULL REFERENCES users (id),
    is_simulated       BOOLEAN NOT NULL DEFAULT FALSE,
    peak_acceleration  DOUBLE PRECISION,
    rotation_rate      DOUBLE PRECISION,
    inactivity_seconds INT,
    outcome            VARCHAR(30) NOT NULL,
    emergency_event_id UUID REFERENCES emergency_events (id),
    detected_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_detect_outcome CHECK (outcome IN ('PENDING', 'USER_SAFE', 'EMERGENCY_CREATED', 'COUNTDOWN_EXPIRED_NOT_ENABLED'))
);

CREATE TABLE sensor_readings (
    id          UUID PRIMARY KEY,
    detection_id UUID NOT NULL REFERENCES accident_detection_events (id),
    sensor      VARCHAR(20) NOT NULL,
    x           DOUBLE PRECISION NOT NULL,
    y           DOUBLE PRECISION NOT NULL,
    z           DOUBLE PRECISION NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_sensor CHECK (sensor IN ('ACCELEROMETER', 'GYROSCOPE'))
);

-- ---------- Notifications ----------
CREATE TABLE device_tokens (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users (id),
    token      VARCHAR(512) NOT NULL,
    platform   VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_device_token UNIQUE (token)
);

CREATE TABLE notifications (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users (id),
    category   VARCHAR(40) NOT NULL,
    title      VARCHAR(150) NOT NULL,
    body       VARCHAR(300) NOT NULL,
    ref_type   VARCHAR(40),
    ref_id     UUID,
    read_at    TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_notif_user ON notifications (user_id, created_at);

-- Delivery attempts double as the outbox: PENDING rows are picked up by the dispatcher and retried.
CREATE TABLE notification_delivery_attempts (
    id              UUID PRIMARY KEY,
    notification_id UUID NOT NULL REFERENCES notifications (id),
    channel         VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    attempts        INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP WITH TIME ZONE,
    last_error      VARCHAR(300),
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_delivery_status CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'NOT_CONFIGURED'))
);
CREATE INDEX ix_delivery_pending ON notification_delivery_attempts (status, next_attempt_at);

-- ---------- Privacy, audit, AI ----------
CREATE TABLE consent_records (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users (id),
    purpose    VARCHAR(60) NOT NULL,
    granted    BOOLEAN NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_consent_user ON consent_records (user_id, purpose, created_at);

CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY,
    actor_id    UUID,
    actor_role  VARCHAR(40),
    action      VARCHAR(80) NOT NULL,
    target_type VARCHAR(60),
    target_id   VARCHAR(64),
    outcome     VARCHAR(20) NOT NULL,
    detail      VARCHAR(500),
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_audit_created ON audit_logs (created_at);
CREATE INDEX ix_audit_actor ON audit_logs (actor_id, created_at);

-- AI processing records store metadata only - never the prompt, source text or model output.
CREATE TABLE ai_processing_records (
    id           UUID PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users (id),
    feature      VARCHAR(30) NOT NULL,
    provider     VARCHAR(40) NOT NULL,
    status       VARCHAR(20) NOT NULL,
    latency_ms   BIGINT,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE system_settings (
    setting_key   VARCHAR(80) PRIMARY KEY,
    setting_value VARCHAR(500) NOT NULL,
    updated_at    TIMESTAMP WITH TIME ZONE NOT NULL
);
