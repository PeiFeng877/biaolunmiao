import json
import ssl
from dataclasses import dataclass
from datetime import datetime
from time import monotonic
from urllib.request import HTTPSHandler, ProxyHandler, build_opener

from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode

from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_SUPPORTED_ALGORITHMS = {"RS256"}
APPLE_SUB_MAX_LENGTH = 128
APPLE_BUILTIN_FALLBACK_JWKS = {
    "keys": [
        {
            "kty": "RSA",
            "kid": "HvVI6EsZXJ",
            "use": "sig",
            "alg": "RS256",
            "n": (
                "2-Tekheu2L4lNkg6Df5IwEYcmcPHMamBYecFzxqjRmab5P4_myI46icPr_kmiDE1QR3nlEZCST9lL9Y310V7n-sFr-5B714q"
                "BqFEClLe92W3c4-MV7BvuGKoteHb4oPLIiRS-GfYcFs8yc6GyGcfw2jx7NNdV_3FQl7wQKLJYEkGK4rcQRsbxLyXo98Z2TeE"
                "-haP5ptXGcD7l1j02sROA6fSWrz4Eyxd7kMkZ9G0-c5U4WA4bpBvE3blJTI-o8VXIqBWV5ZwIQ_ZAKdFkbHKal-5Q11SjuiL"
                "B5vk_iuO7Q8rpfAJzdnGOWgZZQn4QOjWCNBmGzPcTx_ygwlu1MemEw"
            ),
            "e": "AQAB",
        },
        {
            "kty": "RSA",
            "kid": "5RFOSiNIUm",
            "use": "sig",
            "alg": "RS256",
            "n": (
                "qaLbQzOrRmIXwJkuWpRu7T6ApMcoBA_QxFUO4foV5A1JhEE_Gg4uOCQ8kDSPJHGhPl8RBZ0o4niyUWYkS3IIgjUq3pMAwSDx"
                "czqKq00Z82gCN6nYAwlI-_iMsepM5kk86XjB_MJMVdU3NGCHReITotsyXnZ0A7v0RU_LYLzdgoobsK1jh5y4XsgiDf25ZGIL"
                "iYjxVzYNcaJ5G01Rg9j0ydEJYMOC_dT9xcfQzy2LiOlhGn3rDpQIyhVuqprvUeLAJPEFQoH486VjcnDxKMLCs2L5aSlTj78B"
                "xgYNV24FRRTl8QAyhIMi4e0Ja_4i59OCOVZMbR4p1_o_cszhOGIlmw"
            ),
            "e": "AQAB",
        },
        {
            "kty": "RSA",
            "kid": "5iq33lJBYj",
            "use": "sig",
            "alg": "RS256",
            "n": (
                "vcDUGnc9ITh348cRCn6CENlcFzOm4X_sxDyPumPZrM3YhH_zXfjNhBCQnvTGNFqGzsqok87ufbWSEqYiYQDsh8DMTT_tx5bcu"
                "RJI-LmuX3CkLOKq0KXVUzijpj45mTvdGoC_dL2ei_nGs9yz0EJwilNpwPZxkGxNhWi7MWobOd4BjzBIkqDw_HqKZ_486EKHhy"
                "V0qgXfwQYgnKT9blBYc6ZNej9MPHyve5lZs084uEiY_UYjV0rlxfZdYa0g3scG7wc2dWMlqZ4QvbPMj0KTzMNtO-9cr3aruTT"
                "PQ2qDqFAThZDNrPaScJIXAcgrARvqy1CAMT_8gSYFbb4Ld0tRbQ"
            ),
            "e": "AQAB",
        },
        {
            "kty": "RSA",
            "kid": "YQrqdMD4bq",
            "use": "sig",
            "alg": "RS256",
            "n": (
                "4rTGSQSzAbwiFAeVuyeav4jwTt8usRCctN_yFincnPSmk78ufyBzHNwMb79FdJE8e79wUr54WlnUKOZtvyJt3eKXv2W85GPqx"
                "bgspHFr69aHmO-7HtKuxV1lpoMa8dwntWLA6aT06L3LOjJW39PL874fDvqBSFfhn5atwqVMlIW5BeBOONucLZelB-2Bt7lqw_"
                "rMt3XaK-2azCTQP-8Re0oZTSVrxpTNaJRj884_KUEAkLtJ1lcRovWlJ3dlGi3utBbob8hXpzD3wfU2X6pszSw0Dx9bAbbib71"
                "R1oQiGFBk8cztkBRMCi0sJ2hWN9S_UeQCReKGt9grb2fo6po2Ow"
            ),
            "e": "AQAB",
        },
        {
            "kty": "RSA",
            "kid": "aVeHFaWxAZ",
            "use": "sig",
            "alg": "RS256",
            "n": (
                "tswj__mH3rt7-PZAJ_YO4Q-oz1wcy7LrW_1Tny6rtSngpE5adpuXuJAl6OxOPWJxrRy3qjA2oKPajJUNCeMUQIwC2W6kgL43S"
                "E3mxm8hfzDbJOBLiuDxRRiRu1Md9h5V8hFLGjlUZ0X0IBZhyYSmB0opl3X8IZMql3FviHf8rjQBMfzSQDm35KuzpMivt0JsaZ"
                "2Gtdp2c4zYr5gR2pg0CGa_8g5RYcxhO2HDk_943xx_bQfTbGMnsxN6iiD23mFuIwAkYxxJ9G-vjViRc_a8HEAR1YvrZbgDQ5C"
                "pyb_9QQGmV4Tdc5EzdeKem9f_NvtDew6Ab4ljVNCwY2zI3DRLOQ"
            ),
            "e": "AQAB",
        },
        {
            "kty": "RSA",
            "kid": "1E6VioIaNI",
            "use": "sig",
            "alg": "RS256",
            "n": (
                "ttL4HNkWLS_Oh0GADZqA4lTM8Y8UyaCR2NfIcvxby6quhwIISI9o9iCw3ggMYnqEG-dfRHcpsWLp2MZH_CNC-2pB0l_tDKeLi"
                "1eytR0_3YUHQBBQlkDjDP-hlyS0xJD1ds0un4mOIhc-oPHK2xiYbSVbJcBTKYA6FPoAa7u_YbsKN1YnUqzoRf2iOpARBurhCk"
                "vmJKjXwcH6RNGM9iScOO-U9orB5-EQivCKdDnMiwsPaA6_Jx1DzKyaZI6UCV_CZV3k59XvbeYGV3JXJMtKjlwaIumX3i5ecT4"
                "lz_XUr7ZYf1tA1v4ewGnrb5TFr86U-NE6uhvEtpA-_uVWPMmy_Q"
            ),
            "e": "AQAB",
        },
    ]
}

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
        if matched := self._match_jwk(keys, kid):
            return matched

        refreshed_keys = self._load_jwks_payload(force_refresh=True)
        if matched := self._match_jwk(refreshed_keys, kid):
            return matched

        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "未找到匹配的 Apple 公钥", 401)

    def _load_jwks_payload(self, *, force_refresh: bool = False) -> list[dict]:
        now = monotonic()
        if not force_refresh and self._jwks_cache and now < self._jwks_cache_expires_at:
            return self._jwks_cache

        try:
            payload = self._fetch_remote_jwks_payload()
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

    def _fetch_remote_jwks_payload(self) -> dict:
        ssl_context = (
            ssl.create_default_context(cafile=certifi.where())
            if certifi is not None
            else ssl.create_default_context()
        )
        opener = build_opener(ProxyHandler({}), HTTPSHandler(context=ssl_context))
        with opener.open(self.settings.apple_jwks_url, timeout=5) as response:
            return json.loads(response.read().decode("utf-8"))

    def _load_fallback_jwks_payload(self) -> dict | None:
        merged_keys = self._merge_jwks_keys(APPLE_BUILTIN_FALLBACK_JWKS.get("keys"))
        raw_payload = self.settings.apple_jwks_fallback_json
        if raw_payload:
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
            merged_keys = self._merge_jwks_keys(merged_keys, payload.get("keys"))

        if not merged_keys:
            return None
        return {"keys": merged_keys}

    def _match_jwk(self, keys: list[dict], kid: str) -> dict | None:
        for item in keys:
            if item.get("kid") == kid:
                return item
        return None

    def _merge_jwks_keys(self, *groups: list[dict] | None) -> list[dict]:
        merged: dict[str, dict] = {}
        for group in groups:
            if not isinstance(group, list):
                continue
            for item in group:
                if not isinstance(item, dict):
                    continue
                kid = item.get("kid")
                if isinstance(kid, str) and kid:
                    merged[kid] = item
        return list(merged.values())

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
        if len(subject.strip()) > APPLE_SUB_MAX_LENGTH:
            raise AppException(
                ErrorCode.APPLE_TOKEN_INVALID,
                "Apple token sub 超出允许长度",
                401,
            )

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
