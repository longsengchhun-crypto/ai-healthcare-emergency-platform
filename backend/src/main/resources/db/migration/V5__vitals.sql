-- Self-reported health measurements (blood pressure, heart rate, glucose, weight, temperature, SpO2).
-- Entered by the patient; the server only validates plausibility and flags values outside typical adult ranges.
-- value2 is used for the diastolic pressure only.
CREATE TABLE vital_readings (
    id          UUID PRIMARY KEY,
    patient_id  UUID NOT NULL REFERENCES patient_profiles (id),
    type        VARCHAR(30) NOT NULL,
    value1      NUMERIC(7, 2) NOT NULL,
    value2      NUMERIC(7, 2),
    note        VARCHAR(300),
    measured_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_vitals_patient_type_time ON vital_readings (patient_id, type, measured_at DESC);
