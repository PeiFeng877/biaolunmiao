from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Match, MatchRoster, Team, TeamMember, TournamentParticipant, User


def user_out(user: User) -> dict:
    return {
        "id": user.id,
        "publicId": user.public_id,
        "nickname": user.nickname,
        "avatarUrl": user.avatar_url,
        "status": user.status,
    }


def team_members_out(db: Session, team_id: str) -> list[dict]:
    members = db.scalars(
        select(TeamMember).where(TeamMember.team_id == team_id, TeamMember.status == 0)
    ).all()
    items: list[dict] = []
    for member in members:
        user = db.scalar(select(User).where(User.id == member.user_id))
        if not user:
            continue
        items.append(
            {
                "id": member.id,
                "teamId": member.team_id,
                "userId": member.user_id,
                "role": member.role,
                "joinTime": member.join_time,
                "displayName": (member.display_name or user.nickname).strip(),
                "nickname": user.nickname,
                "publicId": user.public_id,
            }
        )
    return items


def team_out(db: Session, team: Team, include_members: bool = True) -> dict:
    payload = {
        "id": team.id,
        "publicId": team.public_id,
        "name": team.name,
        "intro": team.intro,
        "avatarUrl": team.avatar_url,
        "ownerId": team.owner_id,
        "status": team.status,
        "createdAt": team.created_at,
        "members": [],
    }
    if include_members:
        payload["members"] = team_members_out(db, team.id)
    return payload


def tournament_participants_out(db: Session, tournament_id: str) -> list[dict]:
    participants = db.scalars(
        select(TournamentParticipant).where(TournamentParticipant.tournament_id == tournament_id)
    ).all()
    return [
        {
            "id": p.id,
            "tournamentId": p.tournament_id,
            "teamId": p.team_id,
            "status": p.status,
            "seed": p.seed,
        }
        for p in participants
    ]


def match_rosters_out(db: Session, match_id: str) -> list[dict]:
    rosters = db.scalars(select(MatchRoster).where(MatchRoster.match_id == match_id)).all()
    return [
        {
            "id": r.id,
            "matchId": r.match_id,
            "teamId": r.team_id,
            "userId": r.user_id,
            "position": r.position,
            "status": r.status,
        }
        for r in rosters
    ]


def match_out(db: Session, match: Match) -> dict:
    return {
        "id": match.id,
        "tournamentId": match.tournament_id,
        "name": match.name,
        "topic": match.topic,
        "startTime": match.start_time,
        "endTime": match.end_time,
        "location": match.location,
        "opponentTeamName": match.opponent_team_name,
        "teamAId": match.team_a_id,
        "teamBId": match.team_b_id,
        "format": match.format,
        "status": match.status,
        "winnerTeamId": match.winner_team_id,
        "teamAScore": match.team_a_score,
        "teamBScore": match.team_b_score,
        "resultRecordedAt": match.result_recorded_at,
        "resultNote": match.result_note,
        "bestDebaterPosition": match.best_debater_position,
        "rosters": match_rosters_out(db, match.id),
    }
