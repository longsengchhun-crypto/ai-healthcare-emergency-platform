# User Flows

## Emergency (patient)

```mermaid
flowchart TD
  A[Emergency tab] --> B{Hold button 1.8 s<br/>or dialog confirm}
  B -- released early --> A
  B --> C[Get location<br/>permission prompt if needed]
  C -- no fix --> D[Continue without location<br/>and say so]
  C -- fix --> E
  D --> E[POST /emergencies<br/>Idempotency-Key]
  E -- 201 --> F[Show server status SUBMITTED<br/>poll every 5 s]
  E -- offline / 5xx --> G[Request NOT confirmed<br/>call shortcut + Retry same key]
  G --> E
  F --> H{status}
  H -- ACKNOWLEDGED..ARRIVED --> F
  H -- RESOLVED/CANCELLED/REJECTED --> I[Done]
  F -- user: I am safe --> J[POST cancel] --> I
```

## Appointment

```mermaid
sequenceDiagram
  participant P as Patient app
  participant API
  participant D as Doctor
  P->>API: GET slots
  P->>API: POST /appointments
  API-->>P: 201 REQUESTED (or 409 SLOT_TAKEN)
  API-->>D: notification
  D->>API: POST confirm
  API-->>P: notification CONFIRMED
```

## Possible-incident (sensors)

`monitoring on → impact ≥ 22 m/s² → rotation ≥ 3 rad/s within 3 s → ≥ 5 s stillness → "Are you OK?" countdown →`
`I'm OK (record) | I need help (create emergency) | expiry (create only if auto-dispatch opted in)`

## Screen inventory (mobile)

Splash · Onboarding · Login · Register · Reset password · Home · Discover (Doctors/Hospitals) · Doctor detail +
booking · Hospital detail · Appointments · Emergency · Safety check · Profile · Health profile · Emergency contacts ·
Safety sensors · Privacy & data · Records · Medications & reminders · Health assistant (Symptoms/Summary/Document) ·
Notifications.

Dashboard: Login · Overview · Emergency queue + event dialog · Appointments · Users & roles · Audit log · System status.
