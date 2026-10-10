# Android Build & Google Play Preparation

> **Submission pack:** step-by-step in [PLAY_SUBMISSION_STEPS.md](PLAY_SUBMISSION_STEPS.md); listing text and data-safety answers in `store/`.

> **Status: not submitted.** A release bundle is built and signed with a *locally generated* upload key
> (`secrets/upload-keystore.jks`, git-ignored; credentials in `apps/mobile/android/key.properties`). It is built
> against a placeholder API URL, so rebuild with your real HTTPS URL before uploading. Back the key up — losing it
> blocks updates unless Play App Signing key reset is available. No Play Console account, privacy-policy URL, production API URL or
> company identity exists in this repository and none have been invented.

## 1. Build facts (verified)

| Item | Value |
|---|---|
| Application ID / namespace | `com.sengchhun.healthresponse` (change before first upload if you own a different domain — it is permanent after publishing) |
| Version | `1.0.0+1` from `apps/mobile/pubspec.yaml` (`versionName+versionCode`) |
| Flutter / Dart | 3.47.7 / 3.13.5 |
| Android Gradle Plugin / Gradle | 9.1.0 / 9.3.1 |
| compile/target SDK | Flutter defaults (`flutter.compileSdkVersion`, `flutter.targetSdkVersion`) — **re-check against Google Play's current target-API requirement at submission time** |
| Release shrinking | R8 minify + resource shrink on |
| Artifacts built | `artifacts/healthresponse-debug.apk`, `artifacts/healthresponse-release-signed.aab` 53.9 MB (**signed**, placeholder API URL) |

## 2. Release procedure

1. An upload keystore already exists locally (`secrets/upload-keystore.jks`, alias `upload`). To use your own:
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. `apps/mobile/android/key.properties` points at the keystore (template: `key.properties.example`). Both are
   git-ignored. Without them the release build is intentionally **unsigned**.
3. Bump `version:` in `pubspec.yaml` (build number must increase on every upload).
4. Build with your real HTTPS API URL (a release build with an empty/`localhost`/non-HTTPS URL shows a configuration
   error screen instead of running):
   `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.<your-host>`
5. Verify: `jarsigner -verify -verbose build/app/outputs/bundle/release/app-release.aab` (must list your certificate),
   inspect with `bundletool`, and install via `bundletool build-apks` on a device.
6. Upload to an **Internal testing** track first; then Closed testing; only then Production.
7. Enrol in Play App Signing (recommended).

On Windows, if the repo path contains `&`, build from a `subst` drive (see README).

## 3. Permissions and justification

| Permission | Why | Notes |
|---|---|---|
| `INTERNET` | talk to the backend | |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | attach position to an emergency request, sort hospitals by distance | requested only on user action; **no background location** |
| `POST_NOTIFICATIONS` | medication reminders (Android 13+) | runtime prompt when the first reminder is created |
| `RECEIVE_BOOT_COMPLETED` | local notification plugin re-registers scheduled reminders after reboot | |

Not requested: `CALL_PHONE` (the app opens the dialler with `tel:` and never dials automatically), background
location, exact-alarm permissions, contacts, SMS, camera, storage (file picker uses the system picker).
Motion sensors need no runtime permission and are read only while the app is open and monitoring is enabled.

## 4. Store listing draft

* **Title:** HealthResponse (working title)
* **Short description:** Book doctors, keep health records and reminders, and request help with your location.
* **Full description (draft):** HealthResponse is a demonstration healthcare companion: find doctors and hospitals,
  request appointments, keep your own health notes, set medication reminders and send an emergency request with your
  location to a hospital response queue. AI features give informational guidance only. This app is not a medical
  device, does not diagnose, and does not replace local emergency services.
* **Category:** Medical (or Health & Fitness). **Tags:** health, appointments, reminders.
* **Graphics needed:** 512×512 icon, 1024×500 feature graphic, ≥ 2 phone screenshots (use fictional demo data only).
  The launcher icon is still the Flutter default and must be replaced.

## 5. Policy / declaration checklist (to be completed by the publisher)

- [ ] Privacy policy at a public URL ([PRIVACY_POLICY.md](PRIVACY_POLICY.md) is a draft, not legal advice)
- [ ] Data safety form: collects personal info (name, email, phone), health info, precise location (only on user
      action), app activity/diagnostics = none; data encrypted in transit; account deletion path = in-app
      deactivation + request process (a web deletion URL is required by Play and does not exist yet)
- [ ] Health apps declaration (Play Console → App content): select functionality; state not a medical device
- [ ] Medical-claims review: no diagnostic claims; AI disclosures present in-app
- [ ] Emergency-feature review: describe that it is an in-app queue and does not contact emergency services
- [ ] Content rating questionnaire; target audience 18+
- [ ] App access instructions for reviewers: provide a test account on a staging backend with fictional data
- [ ] Ads: none. Government/financial declarations: n/a
- [ ] Target API level meets current Play requirement; 64-bit support (Flutter provides)
- [ ] Replace launcher icon, add splash branding
- [ ] Pre-launch report reviewed

## 6. Known limitations to disclose

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md): no real dispatch, no push/SMS, unverified on a physical device.
