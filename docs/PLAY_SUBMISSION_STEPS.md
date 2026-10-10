# Google Play — step-by-step submission (prepared, NOT submitted)

Everything that can be prepared in the repository is ready: signed-bundle build, icon, feature graphic, listing text,
data-safety answers, privacy and account-deletion pages. These steps are the ones only you can do.

## Part 1 — Host the privacy policy (free, 5 minutes)

Play requires a public privacy-policy URL and an account-deletion URL.

1. Merge the work into `main`: on GitHub open a **Pull request** from `feat/initial-platform` → `main` and merge it.
2. Repository **Settings → Pages**. Source: *Deploy from a branch*. Branch: `main`, folder: `/docs`. Save.
3. Wait ~1 minute. Your pages will be:
   * `https://longsengchhun-crypto.github.io/ai-healthcare-emergency-platform/privacy.html`
   * `https://longsengchhun-crypto.github.io/ai-healthcare-emergency-platform/account-deletion.html`
4. Edit both files and replace `[operator email address]` with a public support email you control, commit, push.

## Part 2 — A real backend on the internet (required)

The app needs an HTTPS API; `localhost` will not work for testers. Options (all need an account you create):
a small VPS or a platform such as Render/Railway/Fly.io running `backend/Dockerfile` with a managed PostgreSQL.
Follow `docs/DEPLOYMENT_GUIDE.md` §4. Do **not** set `SEED_DEMO_DATA=true` on a public server except for a
reviewer test account on a separate staging server. Then create your first administrator (deployment guide step 6).

## Part 3 — Build the release bundle with real values

```
subst M: "D:\SENG CHHUN\9- All Demo System\7- AI HEALTHCARE & EMERGENCY - APP\apps\mobile"
cd /d M:\
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-api-host> ^
  [--dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... ^
   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...]
```
Output: `build\app\outputs\bundle\release\app-release.aab` (signed with `secrets/upload-keystore.jks`).
Before every new upload increase the number after `+` in `apps/mobile/pubspec.yaml` `version:`.

## Part 4 — Play Console (one-time US$25 developer fee)

1. https://play.google.com/console → create a developer account (identity verification may take days).
   New *personal* accounts must run a **closed test with 12+ testers for 14 days** before production access.
2. **Create app**: name `HealthResponse`, default language, App, Free, accept declarations.
3. **Set up your app** checklist:
   * Privacy policy → paste the Pages URL.
   * App access → "All or some functionality is restricted" → provide a reviewer account on a **staging** server.
   * Ads → No. Content rating → fill the questionnaire (medical app, no violence). Target audience → 18+.
   * Data safety → use `store/DATA_SAFETY_ANSWERS.md`.
   * Health apps → declare truthfully (see that file). Government apps → No.
   * Account deletion → paste the `account-deletion.html` URL.
   * Store listing → copy from `store/LISTING.md`; upload `icon-512.png`, `feature-graphic-1024x500.png`, screenshots.
4. **Testing → Internal testing** → Create release → upload the `.aab` → add testers (emails) → roll out.
   Accept Play App Signing when asked (recommended).
5. After closed testing succeeds → **Production** → Create release → review → submit.

## Part 5 — Screenshots (needs a phone or emulator)

Run the app with fictional demo data and capture 4–8 screens: Home, Discover, Doctor booking, Emergency, Records,
Medications, Health assistant. Do not show real names, numbers or locations.

## Checklist before pressing "Submit"

- [ ] Real HTTPS API URL in the build; app opens and logs in
- [ ] Privacy-policy and deletion URLs open publicly with your email filled in
- [ ] Data-safety form matches the build (re-check if SMS/Firebase/SMTP enabled)
- [ ] `emergency.local_number` configured and verified by a human (see deployment guide)
- [ ] Keystore backed up in two places
- [ ] Store listing contains no claims of diagnosis, cure or official emergency-service integration
