-- SMS alerts to a patient's emergency contacts. One row per (event, contact); processed by an outbox dispatcher
-- with retries. Only created when the patient opted in (consent purpose EMERGENCY_CONTACT_SMS) and the event is
-- not a demonstration event.
CREATE TABLE contact_alert_attempts (
    id              UUID PRIMARY KEY,
    event_id        UUID NOT NULL REFERENCES emergency_events (id),
    contact_id      UUID,
    contact_name    VARCHAR(150) NOT NULL,
    phone           VARCHAR(32) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    attempts        INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMP WITH TIME ZONE,
    last_error      VARCHAR(300),
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_contact_alert_status CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'NOT_CONFIGURED'))
);
CREATE INDEX ix_contact_alert_pending ON contact_alert_attempts (status, next_attempt_at);
CREATE INDEX ix_contact_alert_event ON contact_alert_attempts (event_id);
