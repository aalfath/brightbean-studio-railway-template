# Changelog

Newest first. Breaking changes are listed first in each entry.

## 2026-11-18: BrightBean Studio at upstream commit 14b92fc

- First version of the template.
- Builds BrightBean Studio from upstream commit `14b92fc18549de47d42e62054215b38b4d994449` (2026-11-17) on `python:3.12.16-slim@sha256:5e2bdb1b…` and `node:20.20.2-trixie-slim@sha256:abfbe12c…`.
- One service runs the web app and the background worker, with uploads on a volume at `/app/media` and data in Railway Postgres.
- First admin created from `ADMIN_EMAIL` / `ADMIN_PASSWORD`; sign-up is invite-only by default.
