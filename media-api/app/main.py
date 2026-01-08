import os
import uuid
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse, FileResponse, HTMLResponse
import boto3
from botocore.config import Config
from fastapi.staticfiles import StaticFiles

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
BUCKET = os.getenv("S3_BUCKET", "")
PREFIX = os.getenv("S3_PREFIX", "uploads/raw")
PRESIGN_EXPIRE = int(os.getenv("PRESIGN_EXPIRE_SECONDS", "600"))

if not BUCKET:
    raise RuntimeError("S3_BUCKET env is required")

s3 = boto3.client(
    "s3",
    region_name=AWS_REGION,
    config=Config(signature_version="s3v4"),
)

app = FastAPI()

# ✅ Dockerfile: WORKDIR /app + COPY static ./static  → /app/static
STATIC_DIR = os.getenv("STATIC_DIR", "/app/static")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.get("/healthz")
def healthz():
    return {"ok": True, "ts": datetime.utcnow().isoformat()}


@app.get("/", response_class=HTMLResponse)
def home():
    upload_html = os.path.join(STATIC_DIR, "upload.html")
    if os.path.exists(upload_html):
        return FileResponse(upload_html, media_type="text/html; charset=utf-8")
    return HTMLResponse(
        content=f"upload.html not found<br>Expected file:<pre>{upload_html}</pre>",
        status_code=200,
    )


def _safe_key(key: str) -> str:
    if key.startswith("/"):
        key = key[1:]
    if ".." in key:
        raise HTTPException(status_code=400, detail="invalid key")
    return key


@app.get("/presign-put")
def presign_put(
    filename: str = Query(..., description="original filename, e.g. movie.mp4"),
    content_type: str = Query(..., alias="contentType", description="e.g. video/mp4"),
    key_prefix: Optional[str] = Query(None, description="override prefix (optional)"),
):
    ext = os.path.splitext(filename)[1].lower()
    allowed = {".mp4", ".mkv", ".mov", ".avi", ".m4v", ".webm", ".txt"}
    if ext and ext not in allowed:
        raise HTTPException(status_code=400, detail=f"Unsupported extension: {ext}")

    prefix = (key_prefix or PREFIX).rstrip("/")
    key = f"{prefix}/{uuid.uuid4().hex}{ext}"
    key = _safe_key(key)

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
    key = _safe_key(key)
    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=PRESIGN_EXPIRE,
    )
    return {"key": key, "url": url, "expires_in": PRESIGN_EXPIRE}


@app.post("/complete")
def complete(key: str = Query(...)):
    key = _safe_key(key)
    return {"ok": True, "key": key, "ts": datetime.utcnow().isoformat()}
