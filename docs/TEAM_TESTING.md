# Team testing guide

Give this page to teammates together with the URL.

## Accounts (all share one password: the value of `SEED_DEMO_PASSWORD`, default `Health2026!`)

| Role | Email | Open |
|---|---|---|
| Patient | `patient@demo.test` | app `/` |
| Doctor (cardiology) | `doctor@demo.test` | app `/` |
| Doctor (general) | `doctor2@demo.test` … `doctor12@demo.test` | app `/` |
| Hospital staff | `staff@demo.test` | dashboard `/dashboard/` |
| Administrator | `admin@demo.test` | dashboard `/dashboard/` |

Tips: first load after idle can take up to a minute (free hosting wakes up). On a phone, use *Add to Home Screen*.
Toggle language with the **ខ្មែរ | EN** switch.

## Test script (≈10 minutes)

| # | Do this | Expect |
|---|---|---|
| 1 | Patient: sign in | Home with next appointment, doctors, medicines |
| 2 | Discover → pick a doctor → choose a day/time → **Book** | Appointment appears as *Waiting* |
| 3 | Doctor (other browser/phone): Appointments → **Confirm** | Patient sees *Confirmed*; a notification appears |
| 4 | Patient: Appointments → **Reschedule** → pick a new time | Status returns to *Waiting* |
| 5 | Patient: Profile → Health records → **Add note** → open it | Note shows as "By you" |
| 6 | Doctor: Appointments → **Patient records** → add a clinical note | Patient sees it as "From clinician"; cannot edit it |
| 7 | Patient: Medicines → add medicine → add reminder | Reminder listed (phone alarms work in the Android APK only) |
| 8 | Patient: Emergency → switch on **Practice request** → hold the red button | Status *SUBMITTED*, timeline shows steps |
| 9 | Staff (dashboard): Emergency queue → open event → **Acknowledge** → **Assign responder** → advance steps | Patient's screen updates within ~5 s |
| 10 | Patient: Health assistant → Symptoms → type "severe chest pain and shortness of breath" | "This may be an emergency" + Go to Emergency |
| 11 | Patient: Profile → Privacy & data | Doctors with access, and who looked at your data |
| 12 | Admin (dashboard): Audit log | Every action above is listed; denied attempts are marked |
| 13 | Stop the network (airplane mode) → Discover | Last saved doctor list with an offline notice |
| 14 | Patient: Emergency without internet | **"Request NOT confirmed"** with a call shortcut (never a fake success) |

## What is intentionally NOT real
Emergency requests go to an in-app demo queue (no ambulance). AI is rule-based. Doctors, hospitals and patients are
fictional and labelled "Sample / គំរូ". SMS/push/email only work if the host owner configured credentials.

## Report a problem
Send: what you did, what you expected, what happened, a screenshot, device + browser, time (so it can be found in the
audit log).
