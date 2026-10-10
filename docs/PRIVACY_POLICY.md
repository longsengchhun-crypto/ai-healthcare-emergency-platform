# Privacy Policy — DRAFT for review

> Draft describing what the **current code** collects. It is not legal advice, names no company, and must be
> reviewed by a qualified professional and hosted at a public URL before any store submission.

**Data collected:** account (name, email, optional phone, password hash); optional health profile (date of birth,
blood group, allergies, conditions, address); emergency contacts you enter; appointments; medical notes/documents you
or authorised clinicians add; medications and reminders; emergency events (status history and, if you allow it, the
coordinates captured at that moment); optional sensor evidence for a possible-incident check; notification inbox and
device tokens; security/audit events (who accessed what, when); AI request metadata (type, status, duration — not
content).

**Purposes:** provide the features above; keep the service secure; investigate misuse.

**Location:** requested only when you ask for help or press *Check location*; never in the background; coordinates
are stored with the emergency event.

**Sharing:** emergency details are visible to authorised hospital staff of the receiving queue; clinicians see your
records only where you granted access or have a confirmed/completed appointment. No advertising or analytics SDKs
are included. AI features run inside the backend; no third-party AI provider is called by this build.

**Retention:** *not yet automated* — records persist until account deactivation; deactivation disables the account
and removes push tokens, but data deletion/anonymisation procedures must be defined by the operator.

**Your choices:** edit profile data, remove contacts, revoke clinician access, turn sensors off, deactivate your
account in-app.

**Security:** TLS in production, hashed passwords, short-lived tokens, access auditing — see SECURITY_REPORT.md for
limits.

**Not a medical device:** the app does not diagnose and is not certified for clinical use.

**Contact:** *<to be supplied by the operator>*
