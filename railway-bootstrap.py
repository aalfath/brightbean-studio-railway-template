"""Migrate the database and create the first admin, under a Postgres lock.

Runs on every start. The advisory lock keeps two deployments that start at the
same time (for example right after a redeploy) from migrating at once. The admin
is created from ADMIN_EMAIL / ADMIN_PASSWORD only when the database has no
superuser yet, so a password changed in the app is never overwritten.
"""
import os
import sys
import time

sys.path.insert(0, "/app")

import django  # noqa: E402

django.setup()

from django.contrib.auth import get_user_model  # noqa: E402
from django.core.management import call_command  # noqa: E402
from django.db import OperationalError, connection  # noqa: E402
from django.utils import timezone  # noqa: E402

LOCK_ID = 2581_0001

for attempt in range(1, 61):
    try:
        connection.ensure_connection()
        break
    except OperationalError as exc:
        if attempt == 60:
            sys.exit(f"railway-bootstrap: database not reachable: {exc}")
        print(f"railway-bootstrap: waiting for the database ({attempt}/60)", flush=True)
        time.sleep(5)

with connection.cursor() as cur:
    cur.execute("SELECT pg_advisory_lock(%s)", [LOCK_ID])
try:
    # migrate also fires the post_migrate hooks that register the recurring jobs.
    call_command("migrate", interactive=False, verbosity=1)

    email = os.environ.get("ADMIN_EMAIL", "").strip()
    password = os.environ.get("ADMIN_PASSWORD", "")
    User = get_user_model()
    if User.objects.filter(is_superuser=True).exists():
        print("railway-bootstrap: an admin already exists, nothing to do")
    elif not email or not password:
        print("railway-bootstrap: ADMIN_EMAIL or ADMIN_PASSWORD not set, no admin created")
    elif User.objects.filter(email__iexact=email).exists():
        user = User.objects.get(email__iexact=email)
        user.is_staff = True
        user.is_superuser = True
        user.save(update_fields=["is_staff", "is_superuser"])
        print(f"railway-bootstrap: made existing user {email} an admin")
    else:
        User.objects.create_superuser(email=email, password=password, tos_accepted_at=timezone.now())
        print(f"railway-bootstrap: created admin {email}")
finally:
    with connection.cursor() as cur:
        cur.execute("SELECT pg_advisory_unlock(%s)", [LOCK_ID])
