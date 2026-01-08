import os
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any

import boto3
from botocore.config import Config

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse, FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

# -----------------------------
# ENV
# -----------------------------
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
BUCKET = os.getenv("S3_BUCKET", "")
PREFIX = os.getenv("S3_PREFIX", "uploads/raw")  # e.g. uploads/raw
PRESIGN_EXPIRE = int(os.getenv("PRESIGN_EXPIRE_SECONDS", "600"))

if not BUCKET:
    raise RuntimeError("S3_BUCKET env is required")

# -----------------------------
# AWS S3 client
# -----------------------------
s3 = boto3.client(
    "s3",
    region_name=AWS_REGION,
    config=Config(signature_version="s3v4"),
)

# -----------------------------
# APP
# -----------------------------
app = FastAPI(title="media-api", version="1.0.0")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")

# 정적 파일 제공: /static/...
# - static 폴더가 없더라도 앱은 뜰 수 있지만, /static 접근은 실패할 수 있음
if os.path.isdir(STATIC_DIR):
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
else:
    # 폴더가 없으면 경고성 라우트로 안내 (배포 시 디버깅에 유용)
    @app.get("/static", response_class=JSONResponse)
    def static_missing():
        raise HTTPException(
            status_code=500,
            detail=f"Static directory not found: {STATIC_DIR}. Add static/upload.html into the image.",
        )


# -----------------------------
# Helpers
# -----------------------------
def _safe_key(key: str) -> str:
    # 최소한의 키 안전성 검증 (원하면 더 빡세게 가능)
    if key.startswith("/"):
        key = key[1:]
    if ".." in key:
        raise HTTPException(status_code=400, detail="invalid key")
    return key


def _upload_key(filename: str, key_prefix: str) -> str:
    ext = os.path.splitext(filename)[1].lower()

    # 필요하면 제한
    allowed = {".mp4", ".mkv", ".mov", ".avi", ".m4v", ".webm", ".txt"}
    if ext and ext not in allowed:
        raise HTTPException(status_code=400, detail=f"Unsupported extension: {ext}")

    prefix = (key_prefix or PREFIX).rstrip("/")
    key = f"{prefix}/{uuid.uuid4().hex}{ext}"
    return _safe_key(key)


# -----------------------------
# Basic
# -----------------------------
@app.get("/healthz")
def healthz():
    return {"ok": True, "ts": datetime.utcnow().isoformat()}


@app.get("/", response_class=HTMLResponse)
def home():
    """
    루트 접속 시 업로드 페이지 제공.
    - static/upload.html 이 이미지 안에 있어야 함.
    """
    upload_html = os.path.join(STATIC_DIR, "upload.html")

    if os.path.exists(upload_html):
        return FileResponse(upload_html, media_type="text/html; charset=utf-8")

    # 파일이 없을 때도 사용자에게 원인을 명확히 보여주기
    return HTMLResponse(
        content=f"""
        <html>
          <head><title>media-api</title></head>
          <body style="font-family: Arial, sans-serif;">
            <h2>upload.html not found</h2>
            <p>Expected file:</p>
            <pre>{upload_html}</pre>
            <p>Fix:</p>
            <ul>
              <li>Add <b>static/upload.html</b> into your Docker image.</li>
              <li>Or access API docs at <a href="/docs">/docs</a>.</li>
            </ul>
          </body>
        </html>
        """,
        status_code=200,
    )


# -----------------------------
# Presigned URL APIs
# -----------------------------
@app.get("/presign-put")
def presign_put(
    filename: str = Query(..., description="original filename, e.g. movie.mp4"),
    content_type: str = Query(..., alias="contentType", description="e.g. video/mp4"),
    key_prefix: Optional[str] = Query(None, description="override prefix (optional)"),
):
    """
    브라우저가 S3로 직접 PUT 업로드하기 위한 presigned URL 발급
    """
    key = _upload_key(filename=filename, key_prefix=(key_prefix or PREFIX))

    # presign에 ContentType을 포함하면
    # 클라이언트 PUT 때 Content-Type 헤더가 반드시 동일해야 함
    url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": BUCKET,
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=PRESIGN_EXPIRE,
    )

    return JSONResponse(
        {
            "bucket": BUCKET,
            "key": key,
            "url": url,
            "expires_in": PRESIGN_EXPIRE,
            "required_headers": {"Content-Type": content_type},
        }
    )


@app.get("/presign-get")
def presign_get(key: str = Query(...)):
    """
    S3 객체 다운로드/스트리밍을 위한 presigned GET URL 발급
    """
    key = _safe_key(key)

    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=PRESIGN_EXPIRE,
    )
    return {"bucket": BUCKET, "key": key, "url": url, "expires_in": PRESIGN_EXPIRE}


@app.post("/complete")
def complete(key: str = Query(..., description="S3 object key")):
    """
    (선택) 업로드 완료 후, 추후 DB 저장/메타 기록 등 확장용
    """
    key = _safe_key(key)
    return {"ok": True, "key": key, "ts": datetime.utcnow().isoformat()}


# -----------------------------
# Optional: List objects (useful for UI)
# -----------------------------
@app.get("/list")
def list_objects(
    prefix: str = Query(PREFIX, description="S3 prefix to list"),
    limit: int = Query(100, ge=1, le=1000),
):
    """
    prefix 아래 객체 목록을 간단히 조회
    (페이지네이션 필요하면 ContinuationToken 추가하면 됨)
    """
    prefix = prefix.rstrip("/") + "/"

    resp = s3.list_objects_v2(
        Bucket=BUCKET,
        Prefix=prefix,
        MaxKeys=limit,
    )

    items: List[Dict[str, Any]] = []
    for obj in resp.get("Contents", []):
        items.append(
            {
                "key": obj["Key"],
                "size": obj["Size"],
                "last_modified": obj["LastModified"].isoformat(),
            }
        )

    return {
        "bucket": BUCKET,
        "prefix": prefix,
        "count": len(items),
        "items": items,
        "is_truncated": resp.get("IsTruncated", False),
    }
