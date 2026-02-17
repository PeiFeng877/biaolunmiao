from fastapi import APIRouter

from app.api.v1 import auth, media, messages, schedule, teams, tournaments, users

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(teams.router)
api_router.include_router(tournaments.router)
api_router.include_router(schedule.router)
api_router.include_router(messages.router)
api_router.include_router(media.router)
