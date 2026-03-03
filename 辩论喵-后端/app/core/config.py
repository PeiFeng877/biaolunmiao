from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "辩论喵后端"
    app_env: str = "local"
    api_v1_prefix: str = "/api/v1"

    secret_key: str = "change-me"
    access_token_expire_minutes: int = 120
    refresh_token_expire_minutes: int = 43200

    database_url: str = "postgresql+psycopg2://postgres:postgres@localhost:5432/bianlunmiao"

    enable_debug_token: bool = True
    apple_allowed_audiences: str = "com.wenwan.BianLunMiao"
    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    apple_jwks_fallback_json: str | None = None
    allow_insecure_apple_token_validation: bool = False

    oss_bucket: str | None = None
    oss_endpoint: str | None = None
    oss_access_key_id: str | None = None
    oss_access_key_secret: str | None = None
    oss_public_base_url: str | None = None
    oss_env_prefix: str = "stg"

    @field_validator("apple_allowed_audiences")
    @classmethod
    def validate_apple_allowed_audiences(cls, value: str) -> str:
        normalized = ",".join(
            item.strip() for item in value.split(",") if item.strip()
        )
        if not normalized:
            raise ValueError("apple_allowed_audiences 不能为空")
        return normalized

    @property
    def apple_allowed_audience_list(self) -> list[str]:
        return [item.strip() for item in self.apple_allowed_audiences.split(",") if item.strip()]

    @property
    def is_prod(self) -> bool:
        return self.app_env.strip().lower() == "prod"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
