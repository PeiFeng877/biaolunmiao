import logging
from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, Response

from app.api.rpc import rpc_router
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.responses import error_response

settings = get_settings()
app = FastAPI(title=settings.app_name, version="0.1.0")
logger = logging.getLogger(__name__)


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or str(uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    return response


@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return error_response(
        code=exc.code,
        message=exc.message,
        request_id=request.state.request_id,
        status_code=exc.status_code,
        details=exc.details,
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return error_response(
        code=ErrorCode.VALIDATION_ERROR,
        message="请求参数校验失败",
        request_id=request.state.request_id,
        status_code=422,
        details={"errors": exc.errors()},
    )


@app.exception_handler(Exception)
async def fallback_exception_handler(request: Request, exc: Exception):
    logger.exception(
        "Unhandled exception on %s %s request_id=%s",
        request.method,
        request.url.path,
        getattr(request.state, "request_id", "-"),
        exc_info=exc,
    )
    return error_response(
        code="INTERNAL_SERVER_ERROR",
        message="服务内部错误",
        request_id=request.state.request_id,
        status_code=500,
    )


@app.get("/healthz")
def healthz():
    return {"ok": True}


def _local_upload_path(object_path: str) -> Path:
    if not object_path or ".." in object_path.split("/"):
        raise AppException(ErrorCode.NOT_FOUND, "文件不存在", 404)
    root = Path(settings.local_media_root).resolve()
    target = (root / object_path).resolve()
    if target != root and root not in target.parents:
        raise AppException(ErrorCode.NOT_FOUND, "文件不存在", 404)
    return target


@app.put("/uploads/{object_path:path}")
async def put_local_upload(object_path: str, request: Request):
    if settings.media_backend != "local":
        raise AppException(ErrorCode.NOT_FOUND, "文件不存在", 404)
    target = _local_upload_path(object_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(await request.body())
    return Response(status_code=200)


@app.get("/uploads/{object_path:path}")
def get_local_upload(object_path: str):
    if settings.media_backend != "local":
        raise AppException(ErrorCode.NOT_FOUND, "文件不存在", 404)
    target = _local_upload_path(object_path)
    if not target.exists() or not target.is_file():
        raise AppException(ErrorCode.NOT_FOUND, "文件不存在", 404)
    return FileResponse(target)


app.include_router(rpc_router)
app.include_router(api_router, prefix=settings.api_v1_prefix)
