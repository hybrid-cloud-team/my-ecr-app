import os
import uuid
from datetime import datetime
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import boto3
from botocore.config import Config

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

@app.get("/healthz")
def healthz():
    return {"ok": True, "ts": datetime.utcnow().isoformat()}

@app.post("/upload")
async def upload(file: UploadFile = File(...)):
    filename = file.filename or "upload.bin"
    ext = os.path.splitext(filename)[1].lower()

    allowed = {".mp4", ".mkv", ".mov", ".avi", ".m4v", ".webm"}
    if ext and ext not in allowed:
        raise HTTPException(status_code=400, detail=f"Unsupported extension: {ext}")

    key = f"{PREFIX}/{uuid.uuid4().hex}{ext}"

    try:
        body = await file.read()
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=body,
            ContentType=file.content_type or "application/octet-stream",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"S3 upload failed: {e}")

    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=PRESIGN_EXPIRE,
    )

    return JSONResponse({
        "bucket": BUCKET,
        "key": key,
        "url": url,
        "expires_in": PRESIGN_EXPIRE
    })

@app.get("/presign")
def presign(key: str):
    if not key:
        raise HTTPException(status_code=400, detail="key is required")

    url = s3.generate_presigned_url(
        ClientMethod="put_object",     # ✅ 업로드용
        "get_object",
        Params={"Bucket": BUCKET, "Key": key},
        HttpMethod="PUT",              # ✅ PUT로 서명 강제
    )
    return {"url": url, "expires_in": PRESIGN_EXPIRE}