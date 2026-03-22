from pydantic import BaseModel, ConfigDict, Field


class RpcRequestIn(BaseModel):
    model_config = ConfigDict(extra="ignore")

    action: str = Field(min_length=1)
    params: dict[str, object] = Field(default_factory=dict)
    request_id: str | None = Field(default=None, alias="request_id")
