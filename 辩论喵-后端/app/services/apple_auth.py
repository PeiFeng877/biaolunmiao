import json
import ssl
from dataclasses import dataclass
from datetime import UTC, datetime
from time import monotonic
from urllib.request import HTTPSHandler, ProxyHandler, build_opener

from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode

from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_SUPPORTED_ALGORITHMS = {"RS256"}

try:
    import certifi
except ImportError:  # pragma: no cover - optional runtime dependency
    certifi = None


@dataclass(frozen=True)
class AppleIdentity:
    sub: str
    audience: str
    issuer: str
    expires_at: datetime


class AppleTokenValidator:
    _jwks_cache: list[dict] | None = None
    _jwks_cache_expires_at: float = 0.0
    _jwks_cache_ttl_seconds = 600

    def __init__(self) -> None:
        self.settings = get_settings()

    def validate(self, identity_token: str) -> AppleIdentity:
        claims = (
            self._decode_insecure(identity_token)
            if self._use_insecure_validation()
            else self._decode_verified(identity_token)
        )
        return self._identity_from_claims(claims)

    def _use_insecure_validation(self) -> bool:
        return self.settings.allow_insecure_apple_token_validation and not self.settings.is_prod

    def _decode_insecure(self, identity_token: str) -> dict:
        try:
            claims = jwt.get_unverified_claims(identity_token)
        except JWTError as exc:
            raise AppException(
                ErrorCode.APPLE_TOKEN_INVALID,
                "Apple identity token 结构无效",
                401,
            ) from exc
        self._validate_claims(claims)
        return claims

    def _decode_verified(self, identity_token: str) -> dict:
        try:
            header = jwt.get_unverified_header(identity_token)
            claims = jwt.get_unverified_claims(identity_token)
        except JWTError as exc:
            raise AppException(
                ErrorCode.APPLE_TOKEN_INVALID,
                "Apple identity token 结构无效",
                401,
            ) from exc

        algorithm = header.get("alg")
        if algorithm not in APPLE_SUPPORTED_ALGORITHMS:
            raise AppException(
                ErrorCode.APPLE_TOKEN_INVALID,
                f"不支持的 Apple token 算法: {algorithm}",
                401,
            )

        key = self._find_jwk(header)
        self._verify_signature(identity_token, key)
        self._validate_claims(claims)
        return claims

    def _find_jwk(self, header: dict) -> dict:
        kid = header.get("kid")
        if not kid:
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 缺少 kid", 401)

        keys = self._load_jwks_payload()
        for item in keys:
            if item.get("kid") == kid:
                return item

        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "未找到匹配的 Apple 公钥", 401)

    def _load_jwks_payload(self) -> list[dict]:
        now = monotonic()
        if self._jwks_cache and now < self._jwks_cache_expires_at:
            return self._jwks_cache

        try:
            ssl_context = (
                ssl.create_default_context(cafile=certifi.where())
                if certifi is not None
                else ssl.create_default_context()
            )
            opener = build_opener(ProxyHandler({}), HTTPSHandler(context=ssl_context))
            with opener.open(self.settings.apple_jwks_url, timeout=5) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except Exception as exc:
            payload = self._load_fallback_jwks_payload()
            if payload is None:
                raise AppException(
                    ErrorCode.APPLE_TOKEN_INVALID,
                    "无法获取 Apple 公钥",
                    401,
                ) from exc

        keys = payload.get("keys")
        if not isinstance(keys, list) or not keys:
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple 公钥列表为空", 401)
        self._jwks_cache = keys
        self._jwks_cache_expires_at = now + self._jwks_cache_ttl_seconds
        return keys

    def _load_fallback_jwks_payload(self) -> dict | None:
        raw_payload = self.settings.apple_jwks_fallback_json
        if not raw_payload:
            return None

        try:
            payload = json.loads(raw_payload)
        except json.JSONDecodeError as exc:
            raise AppException(
                ErrorCode.APPLE_TOKEN_INVALID,
                "Apple 公钥回退配置非法",
                401,
            ) from exc

        if not isinstance(payload, dict):
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple 公钥回退配置非法", 401)
        return payload

    def _verify_signature(self, identity_token: str, key_data: dict) -> None:
        try:
            signing_input, encoded_signature = identity_token.rsplit(".", 1)
            decoded_signature = base64url_decode(encoded_signature.encode("utf-8"))
            public_key = jwk.construct(key_data)
        except Exception as exc:
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 签名解析失败", 401) from exc

        if not public_key.verify(signing_input.encode("utf-8"), decoded_signature):
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 签名校验失败", 401)

    def _validate_claims(self, claims: dict) -> None:
        issuer = claims.get("iss")
        if issuer != APPLE_ISSUER:
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token issuer 非法", 401)

        subject = claims.get("sub")
        if not isinstance(subject, str) or not subject.strip():
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 缺少 sub", 401)

        audience = claims.get("aud")
        allowed_audiences = set(self.settings.apple_allowed_audience_list)
        if isinstance(audience, str):
            matched = audience in allowed_audiences
        elif isinstance(audience, list):
            matched = any(item in allowed_audiences for item in audience if isinstance(item, str))
        else:
            matched = False

        if not matched:
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token audience 非法", 401)

        exp = claims.get("exp")
        if not isinstance(exp, (int, float)):
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 缺少 exp", 401)

        expires_at = datetime.fromtimestamp(exp, tz=UTC)
        if expires_at <= datetime.now(UTC):
            raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 已过期", 401)

    def _identity_from_claims(self, claims: dict) -> AppleIdentity:
        exp = datetime.fromtimestamp(claims["exp"], tz=UTC)
        audience = claims["aud"]
        if isinstance(audience, list):
            audience = next(
                (
                    item
                    for item in audience
                    if isinstance(item, str) and item in self.settings.apple_allowed_audience_list
                ),
                "",
            )

        return AppleIdentity(
            sub=claims["sub"].strip(),
            audience=audience,
            issuer=claims["iss"],
            expires_at=exp,
        )


def validate_apple_identity_token(identity_token: str) -> AppleIdentity:
    return AppleTokenValidator().validate(identity_token)
