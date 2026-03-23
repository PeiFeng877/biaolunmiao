from __future__ import annotations

import os
from uuid import uuid4

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import AdminUser


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def reset_admin_from_env() -> str:
    email = _normalize_email(os.environ["ADMIN_BOOTSTRAP_EMAIL"])
    password = os.environ["ADMIN_BOOTSTRAP_PASSWORD"]
    display_name = os.environ.get("ADMIN_BOOTSTRAP_DISPLAY_NAME", "正式管理员").strip() or "正式管理员"
    role = os.environ.get("ADMIN_BOOTSTRAP_ROLE", "super_admin").strip() or "super_admin"

    db = SessionLocal()
    try:
        admin = db.scalar(select(AdminUser).where(AdminUser.email == email))
        if admin is None:
            admin = AdminUser(
                id=str(uuid4()),
                email=email,
                password_hash=hash_password(password),
                display_name=display_name,
                role=role,
                status=0,
            )
            db.add(admin)
            action = "created"
        else:
            admin.password_hash = hash_password(password)
            admin.display_name = display_name
            admin.role = role
            admin.status = 0
            db.add(admin)
            action = "updated"
        db.commit()
        return action
    finally:
        db.close()


if __name__ == "__main__":
    result = reset_admin_from_env()
    print(f"admin bootstrap {result}")
