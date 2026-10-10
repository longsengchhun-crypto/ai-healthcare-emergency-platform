# Push, SMS and Email — setup guide

The code for all three channels is implemented and tested (with fakes and a local mock HTTP server). **You only
supply credentials.** Nothing is sent, and nothing is claimed as sent, until you do. Never commit the values; put them
in `.env` (git-ignored) or your host's secret manager.

| Channel | Used for | Provider | Cost |
|---|---|---|---|
| Push | appointment / emergency status notifications | Firebase Cloud Messaging | free |
| SMS | alert emergency contacts (opt-in, real events only) | Twilio (REST) | trial credit, then paid |
| Email | password-reset code | any SMTP server | free options exist |

## 1. Push notifications (Firebase Cloud Messaging)

**A. Create the Firebase project (about 10 minutes)**
1. Go to https://console.firebase.google.com → **Add project** → name it → continue (Analytics can be off).
2. Project overview → **Add app → Android**. Package name: `com.sengchhun.healthresponse`. Register app
   (you can skip the "download google-services.json" step — this project does not use that file).
3. Project settings (gear) → **General** → under *Your apps* copy: **App ID** (`1:1234…:android:abcd…`),
   **Project ID**, and under *Cloud Messaging* the **Sender ID** (project number). Also copy the **Web API key**
   from the same General page (shown as "Web API Key").

**B. Server key**
1. Project settings → **Service accounts** → **Generate new private key** → a `.json` file downloads.
2. Save it somewhere private, e.g. `secrets/firebase-service-account.json` (the `secrets/` folder is git-ignored).
3. Set in `.env`: `FCM_SERVICE_ACCOUNT_FILE=/run/secrets/firebase.json` and mount the file into the container
   (see compose comment), or for a local jar run: `FCM_SERVICE_ACCOUNT_FILE=D:\path\to\firebase-service-account.json`.

**C. App build**
```
flutter build apk --release ^
  --dart-define=API_BASE_URL=https://<your-api> ^
  --dart-define=FIREBASE_API_KEY=<web api key> ^
  --dart-define=FIREBASE_APP_ID=<app id> ^
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender id> ^
  --dart-define=FIREBASE_PROJECT_ID=<project id>
```
On sign-in the app asks for notification permission and registers its token with `POST /devices/register`.
The backend then delivers through the outbox (retry with back-off; statuses `SENT`, `FAILED`, or `NOT_CONFIGURED`).

## 2. SMS to emergency contacts (Twilio)

1. Sign up at https://www.twilio.com/try-twilio (trial gives credit; trial accounts can only text **verified**
   numbers — add each contact under *Verified Caller IDs* while testing).
2. From the console copy **Account SID** and **Auth Token**, and get a **phone number** (Phone Numbers → Buy).
3. Set: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` (e.g. `+15551234567`).
4. In the app: Profile → Emergency contacts → turn on *Text my contacts…* (stored as consent purpose
   `EMERGENCY_CONTACT_SMS`).

Rules enforced by the server: real (non-demo) events only; patient consent required; text contains the patient's
name and a map link if location was shared — no medical data; each result is written to the emergency history
(`SMS sent to …` / `FAILED after retries`). Check local regulations and Twilio's country rules (sender registration is
required in some countries) before real use.

## 3. Email (SMTP)

Set `MAIL_HOST`, `MAIL_PORT` (587), `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`.

Free option: a Gmail account with 2-Step Verification → https://myaccount.google.com/apppasswords → create an app
password → `MAIL_HOST=smtp.gmail.com`, `MAIL_USERNAME=<your gmail>`, `MAIL_PASSWORD=<app password>`,
`MAIL_FROM=<your gmail>`. (For production use a transactional provider such as Brevo/Mailgun/SES.)

Used for the password-reset code today. Email verification of new accounts is **not** implemented.

## 4. Verify it works

| Check | How |
|---|---|
| Backend sees providers | System status page in the dashboard / logs show no "not configured" outcomes |
| Push | Book an appointment as patient, confirm as doctor → phone receives "Appointment confirmed" |
| SMS | Enable consent, add a verified contact, send a **non-demo** emergency → contact receives text; history shows `SMS sent` |
| Email | Mobile → Forgot password → email arrives with the code |

## 5. Environment variable reference

| Variable | Meaning |
|---|---|
| `FCM_SERVICE_ACCOUNT_FILE` | path to Firebase service-account JSON (enables push) |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM` | enable SMS |
| `MAIL_HOST` `MAIL_PORT` `MAIL_USERNAME` `MAIL_PASSWORD` `MAIL_FROM` | enable email |
| `DEV_LOG_RESET_TOKENS` | dev only: log reset codes when email is not configured |
