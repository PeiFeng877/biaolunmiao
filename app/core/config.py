from functools import lru_cache

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
    enable_test_phone_login: bool = False
    allow_insecure_apple_token_validation: bool = True
    apple_client_id: str | None = None
    apple_keys_cache_ttl_seconds: int = 3600

    oss_bucket: str | None = None
    oss_endpoint: str | None = None
    oss_access_key_id: str | None = None
    oss_access_key_secret: str | None = None
    oss_public_base_url: str | None = None
    oss_env_prefix: str = "stg"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
