"""Create the first admin from ADMIN_EMAIL / ADMIN_PASSWORD, once.

Runs on every start but only acts when the database has no superuser yet,
so changing the password in the app later is never overwritten.
"""
import os
import sys

sys.path.insert(0, "/app")

import django  # noqa: E402

django.setup()

from django.contrib.auth import get_user_model  # noqa: E402
from django.utils import timezone  # noqa: E402

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
