import os

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import AdminUser, Team, TeamMember, User
from app.services.common import generate_public_id


def run() -> None:
    db = SessionLocal()
    try:
        me = db.scalar(select(User).where(User.public_id == "U9527"))
        if me is None:
            me = User(public_id="U9527", nickname="培风", status=0)
            db.add(me)
            db.flush()

        team = db.scalar(select(Team).where(Team.name == "复仇者辩论队"))
        if team is None:
            team = Team(
                public_id=generate_public_id(),
                name="复仇者辩论队",
                intro="种子数据队伍",
                owner_id=me.id,
                status=0,
            )
            db.add(team)
            db.flush()
            db.add(TeamMember(team_id=team.id, user_id=me.id, role=2, status=0))

        admin_email = os.getenv("SEED_ADMIN_EMAIL", "admin@bianlunmiao.local")
        admin_password = os.getenv("SEED_ADMIN_PASSWORD", "Admin123456")
        admin = db.scalar(select(AdminUser).where(AdminUser.email == admin_email))
        if admin is None:
            db.add(
                AdminUser(
                    email=admin_email,
                    password_hash=hash_password(admin_password),
                    display_name="本地管理员",
                    role="super_admin",
                    status=0,
                )
            )

        db.commit()
        print("seed finished")
    finally:
        db.close()


if __name__ == "__main__":
    run()
