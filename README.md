# BrightBean Studio on Railway

A one-click [Railway](https://railway.com) template for [BrightBean Studio](https://github.com/brightbeanxyz/brightbean-studio), the open-source, self-hostable social media management platform: plan, compose, schedule, approve, publish and monitor posts across Facebook, Instagram, LinkedIn, TikTok, YouTube, Pinterest, Threads, Bluesky, Google Business Profile, Mastodon and DEV.to.

## What it deploys

- **BrightBean Studio at upstream commit [`14b92fc`](https://github.com/brightbeanxyz/brightbean-studio/commit/14b92fc18549de47d42e62054215b38b4d994449)** (2026-11-17). Upstream publishes no releases, tags or Docker images, so the [`Dockerfile`](Dockerfile) downloads that exact commit and builds it on the official `python:3.12.16-slim` and `node:20.20.2-trixie-slim` images, both pinned by digest.
- **One app service** with a public HTTPS domain and a health check on `/health/`. [`railway-start.sh`](railway-start.sh) runs the database migrations, creates the first admin, then starts the web app (Gunicorn) **and** the background worker (`run_studio_worker`, which publishes scheduled posts and syncs inboxes and analytics) in the same container. Sharing one container means the worker can read the media you upload, without S3.
- **One volume at `/app/media`** for uploaded images and videos, so they survive redeploys and restarts.
- **Railway Postgres** for everything else.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `ADMIN_EMAIL` | prompt | Email of the first admin account (Django superuser). Used only on the first start. |
| `ADMIN_PASSWORD` | generated (`${{secret(24)}}`) | Password of that admin. Used only on the first start; change it in the app afterwards. |
| `SECRET_KEY` | generated | Django secret key. Also the root of the key that encrypts stored platform tokens, so **never change it** after the first start. |
| `ENCRYPTION_KEY_SALT` | generated | Salt for that encryption key and for API-key hashing. **Never change it** after the first start. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private connection to the bundled Postgres. |
| `PORT` | `8000` | Port the web app listens on; the Railway domain points at it. |

Set by `railway-start.sh` and overridable with a service variable:

- `APP_URL` defaults to `https://` plus the Railway domain. Set it when you add a custom domain: OAuth callbacks and links in emails use it.
- `ALLOWED_HOSTS` defaults to the Railway domains plus the `APP_URL` host (never `*`).
- `SIGNUP_MODE` defaults to `invite`: only people you invite can create an account. Use `open` to let anyone with the URL register, or `closed` for admin-created accounts only.
- `EMAIL_BACKEND_TYPE` is `console` (emails are written to the deploy logs) until you set `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` and `DEFAULT_FROM_EMAIL`; then it switches to SMTP.
- `STORAGE_BACKEND=local`, `MEDIA_ROOT=/app/media`, `MALLOC_ARENA_MAX=2`, `WEB_CONCURRENCY=1`, `GUNICORN_THREADS=4`.

Platform credentials (`PLATFORM_FACEBOOK_APP_ID`, `PLATFORM_LINKEDIN_PERSONAL_CLIENT_ID` and so on), S3 storage, Google sign-in and Unsplash are optional. See upstream's [`.env.example`](https://github.com/brightbeanxyz/brightbean-studio/blob/14b92fc18549de47d42e62054215b38b4d994449/.env.example) and README. Platform credentials can also be entered per organization in the Django admin at `/admin/` → **Credentials → Platform credentials**.

## After deploying

1. Open the app service's **Variables** tab and copy `ADMIN_PASSWORD`. Sign in at your Railway URL with `ADMIN_EMAIL` and that password, then change the password under your account settings.
2. Connect your social accounts. Each platform needs your own developer app credentials: set them as service variables, or in `/admin/` → **Credentials → Platform credentials**. Use `https://YOUR-DOMAIN/...` callback URLs as described in upstream's README.
3. Invite teammates and clients from the workspace's **Members** page. Without SMTP, the invitation email (with its link) appears in the deploy logs.

## Updates

This template builds from this repository. When upstream ships changes worth taking, we bump `BRIGHTBEAN_COMMIT` (and the base image digests when needed) in the `Dockerfile` and add a [`CHANGELOG.md`](CHANGELOG.md) entry. Railway then shows an "update available" notice on your project, and you choose when to apply it. Migrations run automatically on start; your media stays on the volume and your data in Postgres. Read the changelog first: breaking changes are listed at the top of each entry.

## Licence

BrightBean Studio is AGPL-3.0, by its authors at [brightbeanxyz/brightbean-studio](https://github.com/brightbeanxyz/brightbean-studio). This repository only holds the Railway packaging (same licence).
