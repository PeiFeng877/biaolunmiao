from sqlalchemy import select

from app.db.session import SessionLocal
from app.models import Team, TeamMember, User
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

        db.commit()
        print("seed finished")
    finally:
        db.close()


if __name__ == "__main__":
    run()
