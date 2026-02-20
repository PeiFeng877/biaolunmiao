from argparse import ArgumentParser

from sqlalchemy import delete, select

from app.db.session import SessionLocal
from app.models import (
    Match,
    MatchRoster,
    Message,
    RefreshToken,
    ScheduleSource,
    Team,
    TeamJoinRequest,
    TeamMember,
    Tournament,
    TournamentParticipant,
    User,
    UserMessageStatus,
)
from app.services.common import generate_public_id

RESET_ORDER = [
    UserMessageStatus,
    Message,
    ScheduleSource,
    MatchRoster,
    Match,
    TournamentParticipant,
    Tournament,
    TeamJoinRequest,
    TeamMember,
    Team,
    RefreshToken,
    User,
]


def reset_data() -> None:
    db = SessionLocal()
    try:
        for model in RESET_ORDER:
            db.execute(delete(model))
        db.commit()
        print("reset finished")
    finally:
        db.close()


def seed_data() -> None:
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


def run() -> None:
    parser = ArgumentParser(description="Seed or reset backend data")
    parser.add_argument(
        "--mode",
        choices=["seed", "reset", "reset-seed"],
        default="seed",
        help="seed=写入种子, reset=清空数据, reset-seed=先清空再写种子",
    )
    args = parser.parse_args()

    if args.mode in {"reset", "reset-seed"}:
        reset_data()
    if args.mode in {"seed", "reset-seed"}:
        seed_data()


if __name__ == "__main__":
    run()
