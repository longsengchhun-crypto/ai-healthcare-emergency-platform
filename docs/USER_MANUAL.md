# User Manual

> This is a demonstration application. It is not a medical device and not a replacement for your local emergency
> number or a clinician.

## Patients (mobile)

1. **Create an account** — Sign in screen → *Create an account*. Use a password of 10+ characters and accept the
   privacy notice.
2. **Complete your profile** — Profile → *Health profile*. All fields are optional. Add up to 5 *Emergency contacts*.
   Note: contacts are stored for responders; the app does **not** text or call them automatically.
3. **Find care** — *Discover* → search doctors or hospitals. Unverified or sample records are labelled. Open a doctor,
   pick a day and a free time, add an optional reason (do not include detailed medical information), *Send request*.
4. **Appointments** — status moves REQUESTED → CONFIRMED (by the doctor) → COMPLETED. Cancel from the card.
5. **Records** — Profile → *Medical records* → *Add note*. Notes you add are labelled as yours; clinician records are
   read-only. Attach PDF/PNG/JPEG (≤ 10 MB) with the paperclip.
6. **Medications** — Profile → *Medications & reminders*. Add a medication as entered by you, then *Add reminder*
   (grant notification permission). Reminders can be delayed by Android power saving.
7. **Emergency** — *Emergency* tab. **Press and hold** the red button until the ring completes (TalkBack users:
   double-tap to open a confirmation dialog). You will see:
   * *SUBMITTED* — saved and waiting for staff; this does **not** mean help is on the way;
   * *ACKNOWLEDGED / RESPONDER ASSIGNED / EN ROUTE / ARRIVED* — only after staff recorded it;
   * *Request NOT confirmed* — nothing was sent: call your local emergency number, then *Retry*.
   Tap *I am safe — cancel request* for a false alarm. The *Demonstration event* switch marks practice requests.
8. **Health assistant** — *Symptoms* (guidance, never a diagnosis; red flags tell you to use Emergency),
   *Summary* (what your records literally say), *Document* (plain-text files only).
9. **Safety sensors** — Profile → *Safety sensors*. Off by default. Turning on monitoring reads motion sensors while
   the app is open. A separate switch controls whether an expired countdown sends a request. Use *Simulate a possible
   incident* to try the flow safely.
10. **Privacy** — Profile → *Privacy & data* explains what is stored and lets you deactivate your account.

## Doctors (mobile)

Schedule shows requests assigned to you: *Confirm*, *Decline*, *Mark completed*. Emergency tab lists incidents staff
assigned to you.

## Hospital staff / administrators (dashboard)

* **Emergency queue** — list auto-refreshes every 5 s; open an event to *Acknowledge*, *Assign responder*, then
  advance (*en route → arrived → resolved*) or *Reject*. Actions are audited.
* **Overview** — live counts from the backend.
* **Appointments**, **Users & roles** (admins), **Audit log**, **System status** (integration honesty panel and
  settings such as `emergency.local_number`).
* Staff cannot read patients' medical records.
