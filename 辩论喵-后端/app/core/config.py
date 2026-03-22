from functools import lru_cache

from pydantic import field_validator, model_validator
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
    sms_auth_provider: str = "mock"
    aliyun_sms_auth_access_key_id: str | None = None
    aliyun_sms_auth_access_key_secret: str | None = None
    aliyun_sms_auth_sign_name: str | None = None
    aliyun_sms_auth_template_code: str | None = None
    aliyun_sms_auth_scheme_name: str | None = None
    aliyun_sms_auth_code_ttl_seconds: int = 300
    aliyun_sms_auth_resend_interval_seconds: int = 60
    aliyun_sms_auth_max_attempts: int = 5

    media_backend: str = "local"
    local_media_root: str = ".data/uploads"
    oss_bucket: str | None = None
    oss_endpoint: str | None = None
    oss_access_key_id: str | None = None
    oss_access_key_secret: str | None = None
    oss_security_token: str | None = None
    oss_public_base_url: str | None = None
    oss_env_prefix: str = "prod"

    @field_validator("apple_allowed_audiences")
    @classmethod
    def validate_apple_allowed_audiences(cls, value: str) -> str:
        normalized = ",".join(
            item.strip() for item in value.split(",") if item.strip()
        )
        if not normalized:
            raise ValueError("apple_allowed_audiences 不能为空")
        return normalized

    @field_validator("media_backend")
    @classmethod
    def validate_media_backend(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"local", "oss"}:
            raise ValueError("media_backend 仅支持 local 或 oss")
        return normalized

    @field_validator("sms_auth_provider")
    @classmethod
    def validate_sms_auth_provider(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {"mock", "aliyun"}:
            raise ValueError("sms_auth_provider 仅支持 mock 或 aliyun")
        return normalized

    @model_validator(mode="after")
    def validate_sms_auth_configuration(self) -> "Settings":
        if self.is_prod and self.sms_auth_provider == "mock":
            raise ValueError("生产环境禁止使用 mock 短信认证 provider")
        if self.sms_auth_provider == "aliyun":
            required = {
                "aliyun_sms_auth_access_key_id": self.aliyun_sms_auth_access_key_id,
                "aliyun_sms_auth_access_key_secret": self.aliyun_sms_auth_access_key_secret,
                "aliyun_sms_auth_sign_name": self.aliyun_sms_auth_sign_name,
                "aliyun_sms_auth_template_code": self.aliyun_sms_auth_template_code,
            }
            missing = [name for name, value in required.items() if not value or not value.strip()]
            if missing:
                raise ValueError(f"aliyun 短信认证配置缺失: {', '.join(missing)}")
        return self

    @property
    def apple_allowed_audience_list(self) -> list[str]:
        return [item.strip() for item in self.apple_allowed_audiences.split(",") if item.strip()]

    @property
    def is_prod(self) -> bool:
        return self.app_env.strip().lower() == "prod"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
