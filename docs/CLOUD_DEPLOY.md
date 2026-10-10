# Deploy to the cloud (always on, any network, PC can be off)

One container (`Dockerfile.cloud`) serves everything on a single HTTPS address:

| Path | What |
|---|---|
| `/` | mobile app (runs in any phone/computer browser, installable to the home screen) |
| `/dashboard/` | operations dashboard (staff / admin) |
| `/api/v1/**` | REST API · `/swagger-ui.html` API docs |

## Option A — Render (recommended, free, no server knowledge)

> Free-tier limits you should know: the service **sleeps after ~15 min idle** (the first visit afterwards takes
> ~30–60 s to wake), the free database is **deleted after 30 days** unless upgraded, and uploaded files are lost on
> every restart. That is fine for team testing, not for real patients.

1. **Merge the code to `main`** (done for you: branch `main` exists on GitHub).
2. Go to https://render.com → **Get started** → sign up with **GitHub**.
3. **New → Blueprint** → choose repository `longsengchhun-crypto/ai-healthcare-emergency-platform` → branch `main`
   → **Connect**. Render reads `render.yaml`.
4. It asks for the secret values marked "sync: false". Fill only:
   * `SEED_DEMO_PASSWORD` = `Health2026!` (or your own, 10+ characters) — this is the password of all demo accounts.
   * Leave the MAIL / TWILIO fields empty (optional, see `INTEGRATIONS.md`).
5. Click **Apply**. The first build takes **8–15 minutes** (it builds Flutter web twice and the backend).
6. When the service shows **Live**, open the URL Render shows, e.g. `https://healthresponse-xxxx.onrender.com`.
   * App: that URL
   * Dashboard: that URL + `/dashboard/`
7. Sign in with `patient@demo.test` / your `SEED_DEMO_PASSWORD`. Send the URL to your team: it works on any phone,
   on any network.

### If the build fails
Open the service → **Logs**. Send me the last 30 lines. Most common causes: out of memory on the free plan during
the Flutter step (retry once; the cache helps) or a typo in `SEED_DEMO_PASSWORD` (must be at least 10 characters).

## Option B — your own free Postgres (Neon / Supabase)

Skip Render's database (it expires in 30 days):
1. Create a Neon (or Supabase) project and copy its **connection string** (`postgres://…?sslmode=require`).
2. In Render → service → **Environment**, set `DATABASE_URL` to that string (delete the one linked to the Render DB).

## Other hosts
Any Docker host works with the same image: Koyeb, Fly.io, Railway, Google Cloud Run, a VPS. Required env vars:
`DATABASE_URL` (or `DB_URL`/`DB_USER`/`DB_PASSWORD`), `JWT_SECRET` (≥32 chars), `SEED_DEMO_DATA=true`,
`SEED_DEMO_PASSWORD`, `PORT` (set by the host).

## Android APK pointing at the cloud
After deploy, build an APK that talks to your cloud URL so teammates can install a real app (no browser):

```
cd apps/mobile
flutter build apk --release --dart-define=API_BASE_URL=https://healthresponse-xxxx.onrender.com
```
(sign with your keystore or use `--debug`). Upload `app-release.apk` to Google Drive and share the link.

## Security reminder
`SEED_DEMO_DATA=true` publishes fictional accounts with a shared password. That is correct for a demo and **must be
turned off** (delete the variable, wipe the database) before any real use.
