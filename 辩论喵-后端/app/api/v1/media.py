import base64
import hashlib
import hmac
from datetime import datetime, timedelta
from urllib.parse import quote, urlencode
from uuid import uuid4

from fastapi import APIRouter, Depends, Request

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC
from app.models import User
from app.schemas.media import UploadTokenOut

router = APIRouter(prefix="/media", tags=["media"])


def _request_public_base(request: Request) -> str:
    override = request.headers.get("x-blm-public-base-url")
    if override:
        return override.rstrip("/")
    return str(request.base_url).rstrip("/")


def _make_local_upload_token(path_prefix: str, request: Request) -> UploadTokenOut:
    settings = get_settings()
    now = datetime.now(UTC)
    expires_at = now + timedelta(minutes=30)
    env_prefix = settings.oss_env_prefix.strip("/") if settings.oss_env_prefix else "prod"
    object_key = f"{env_prefix}/{path_prefix}/{now:%Y/%m}/{uuid4()}.jpg"
    encoded_object_key = quote(object_key, safe="/")
    public_base = _request_public_base(request)
    upload_url = f"{public_base}/uploads/{encoded_object_key}"
    public_url = f"{public_base}/uploads/{encoded_object_key}"
    return UploadTokenOut(
        objectKey=object_key,
        uploadUrl=upload_url,
        expiresAt=expires_at,
        method="PUT",
        uploadHeaders={"Content-Type": "image/jpeg"},
        publicUrl=public_url,
        provider="local",
    )


def _make_oss_upload_token(path_prefix: str) -> UploadTokenOut:
    settings = get_settings()
    if path_prefix not in {"avatars", "covers"}:
        raise AppException(ErrorCode.MEDIA_PATH_INVALID, "不支持的上传目录", 400)

    if not settings.oss_bucket or not settings.oss_access_key_id or not settings.oss_access_key_secret:
        raise AppException(ErrorCode.MEDIA_STORAGE_NOT_CONFIGURED, "对象存储配置缺失", 500)

    now = datetime.now(UTC)
    expires_at = now + timedelta(minutes=30)
    expires_ts = int(expires_at.timestamp())
    endpoint = (settings.oss_endpoint or "oss-cn-hangzhou.aliyuncs.com").strip()
    endpoint = endpoint.replace("https://", "").replace("http://", "").strip("/")
    security_token = settings.oss_security_token.strip() if settings.oss_security_token else None
    env_prefix = settings.oss_env_prefix.strip("/") if settings.oss_env_prefix else "prod"
    object_key = f"{env_prefix}/{path_prefix}/{now:%Y/%m}/{uuid4()}.jpg"
    encoded_object_key = quote(object_key, safe="/")
    canonical_resource = f"/{settings.oss_bucket}/{object_key}"
    content_type = "image/jpeg"

    string_to_sign = f"PUT\n\n{content_type}\n{expires_ts}\n{canonical_resource}"
    try:
        digest = hmac.new(
            settings.oss_access_key_secret.encode("utf-8"),
            string_to_sign.encode("utf-8"),
            hashlib.sha1,
        ).digest()
        signature = base64.b64encode(digest).decode("utf-8")
    except Exception as exc:
        raise AppException(
            ErrorCode.MEDIA_UPLOAD_SIGN_FAILED,
            "上传签名失败",
            500,
            details={"reason": str(exc)},
        ) from exc

    query_items = {
        "OSSAccessKeyId": settings.oss_access_key_id,
        "Expires": str(expires_ts),
        "Signature": signature,
    }
    if security_token:
        query_items["security-token"] = security_token

    query = urlencode(query_items)
    upload_url = f"https://{settings.oss_bucket}.{endpoint}/{encoded_object_key}?{query}"
    public_base = settings.oss_public_base_url
    if public_base:
        public_base = public_base.rstrip("/")
    else:
        public_base = f"https://{settings.oss_bucket}.{endpoint}"
    public_url = f"{public_base}/{encoded_object_key}"

    return UploadTokenOut(
        objectKey=object_key,
        uploadUrl=upload_url,
        expiresAt=expires_at,
        method="PUT",
        uploadHeaders={"Content-Type": content_type},
        publicUrl=public_url,
        provider="oss",
    )


@router.post("/avatar-upload-token", response_model=UploadTokenOut)
def avatar_upload_token(request: Request, _: User = Depends(get_current_user)):
    settings = get_settings()
    if settings.media_backend == "local":
        return _make_local_upload_token("avatars", request)
    return _make_oss_upload_token("avatars")


@router.post("/cover-upload-token", response_model=UploadTokenOut)
def cover_upload_token(request: Request, _: User = Depends(get_current_user)):
    settings = get_settings()
    if settings.media_backend == "local":
        return _make_local_upload_token("covers", request)
    return _make_oss_upload_token("covers")
