#!/bin/bash
# Railway wrapper for BrightBean Studio: one container runs the web app
# (Gunicorn) and the background worker (run_studio_worker), so both see the
# uploads on the same volume at /app/media.
set -euo pipefail
cd /app

export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-config.settings.production}"
export PORT="${PORT:-8000}"
export STORAGE_BACKEND="${STORAGE_BACKEND:-local}"
export MEDIA_ROOT="${MEDIA_ROOT:-/app/media}"
# Invite-only by default: the admin below is created on first start, and
# everyone else joins through an invitation. Set SIGNUP_MODE=open to allow
# anyone with the URL to register.
export SIGNUP_MODE="${SIGNUP_MODE:-invite}"
# Returns freed memory to the OS (upstream's recommendation for small hosts).
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"

if [ -z "${APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
if [ -z "${ALLOWED_HOSTS:-}" ]; then
  hosts="localhost,127.0.0.1,healthcheck.railway.app"
  [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] && hosts="${hosts},${RAILWAY_PUBLIC_DOMAIN}"
  [ -n "${RAILWAY_PRIVATE_DOMAIN:-}" ] && hosts="${hosts},${RAILWAY_PRIVATE_DOMAIN}"
  app_host="$(python -c 'import os,urllib.parse;print(urllib.parse.urlparse(os.environ.get("APP_URL","")).hostname or "")')"
  [ -n "$app_host" ] && hosts="${hosts},${app_host}"
  export ALLOWED_HOSTS="$hosts"
fi
# Without SMTP settings, emails (invitations, password resets) go to the logs.
if [ -z "${EMAIL_BACKEND_TYPE:-}" ]; then
  if [ -n "${EMAIL_HOST:-}" ]; then export EMAIL_BACKEND_TYPE=smtp; else export EMAIL_BACKEND_TYPE=console; fi
fi

for v in SECRET_KEY ENCRYPTION_KEY_SALT DATABASE_URL; do
  if [ -z "${!v:-}" ]; then echo "railway-start: $v is not set" >&2; exit 1; fi
done

mkdir -p "$MEDIA_ROOT"

# Wait for Postgres, then migrate (this also registers the recurring jobs).
for i in $(seq 1 30); do
  if python manage.py migrate --noinput; then break; fi
  if [ "$i" = 30 ]; then echo "railway-start: migrate failed" >&2; exit 1; fi
  echo "railway-start: database not ready, retrying in 5 s ($i/30)"
  sleep 5
done

python /usr/local/bin/railway-bootstrap.py

python manage.py run_studio_worker &
worker=$!
gunicorn config.wsgi:application --bind "0.0.0.0:${PORT}" \
  --workers "${WEB_CONCURRENCY:-1}" --threads "${GUNICORN_THREADS:-4}" \
  --timeout "${GUNICORN_TIMEOUT:-120}" --access-logfile - &
web=$!

stop() { kill -TERM "$web" "$worker" 2>/dev/null || true; wait "$web" "$worker" 2>/dev/null || true; exit 0; }
trap stop TERM INT

# If either process exits, stop the other and let Railway restart the service.
set +e
wait -n "$web" "$worker"
code=$?
echo "railway-start: a process exited (code $code), stopping" >&2
kill -TERM "$web" "$worker" 2>/dev/null
wait
exit 1
