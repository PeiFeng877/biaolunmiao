from datetime import datetime

from pydantic import BaseModel


class UploadTokenOut(BaseModel):
    objectKey: str
    uploadUrl: str
    expiresAt: datetime
    provider: str = "oss"
