from datetime import datetime

from pydantic import BaseModel


class UploadTokenOut(BaseModel):
    objectKey: str
    uploadUrl: str
    expiresAt: datetime
    method: str = "PUT"
    uploadHeaders: dict[str, str]
    uploadFields: dict[str, str] | None = None
    uploadFileFieldName: str | None = None
    publicUrl: str
    provider: str = "local"
