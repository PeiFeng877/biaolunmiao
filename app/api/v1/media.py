from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.models import User
from app.schemas.media import UploadTokenOut

router = APIRouter(prefix="/media", tags=["media"])


def _make_upload_token(path_prefix: str) -> UploadTokenOut:
    settings = get_settings()
    now = datetime.now(UTC)
    object_key = f"{path_prefix}/{uuid4()}.jpg"
    endpoint = settings.oss_endpoint or "https://oss-cn-hangzhou.aliyuncs.com"
    bucket = settings.oss_bucket or "bianlunmiao-mvp"
    upload_url = f"{endpoint}/{bucket}/{object_key}?mockPresign=true"
    return UploadTokenOut(
        objectKey=object_key, uploadUrl=upload_url, expiresAt=now + timedelta(minutes=30)
    )


@router.post("/avatar-upload-token", response_model=UploadTokenOut)
def avatar_upload_token(_: User = Depends(get_current_user)):
    return _make_upload_token("avatars")


@router.post("/cover-upload-token", response_model=UploadTokenOut)
def cover_upload_token(_: User = Depends(get_current_user)):
    return _make_upload_token("covers")
