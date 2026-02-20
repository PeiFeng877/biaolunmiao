from datetime import datetime

from pydantic import BaseModel


class UploadTokenOut(BaseModel):
    objectKey: str
    uploadUrl: str
    expiresAt: datetime
    method: str = "PUT"
    uploadHeaders: dict[str, str]
    publicUrl: str
    provider: str = "oss"
