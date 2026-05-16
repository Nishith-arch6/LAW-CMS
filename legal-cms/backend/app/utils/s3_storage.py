import logging
from typing import BinaryIO

from app.core.config import settings

logger = logging.getLogger("legal_cms.s3")

s3_client = None

try:
    import boto3
    from botocore.config import Config as BotoConfig

    if settings.use_s3:
        s3_client = boto3.client(
            "s3",
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
            endpoint_url=settings.s3_endpoint or None,
            config=BotoConfig(
                connect_timeout=10,
                read_timeout=30,
                retries={"max_attempts": 3},
            ),
        )
        logger.info("S3 client initialized (bucket: %s)", settings.s3_bucket)
except Exception:
    logger.warning("boto3 not available or S3 not configured — using local storage")


async def upload_fileobj(fileobj: BinaryIO, key: str) -> str | None:
    if not s3_client:
        return None
    try:
        s3_client.upload_fileobj(fileobj, settings.s3_bucket, key)
        logger.info("Uploaded to S3: %s/%s", settings.s3_bucket, key)
        return key
    except Exception as e:
        logger.error("S3 upload failed: %s", e)
        return None


async def download_fileobj(key: str) -> bytes | None:
    if not s3_client:
        return None
    try:
        import io
        buf = io.BytesIO()
        s3_client.download_fileobj(settings.s3_bucket, key, buf)
        buf.seek(0)
        return buf.read()
    except Exception as e:
        logger.error("S3 download failed: %s", e)
        return None


async def delete_file(key: str) -> bool:
    if not s3_client:
        return False
    try:
        s3_client.delete_object(Bucket=settings.s3_bucket, Key=key)
        logger.info("Deleted from S3: %s/%s", settings.s3_bucket, key)
        return True
    except Exception as e:
        logger.error("S3 delete failed: %s", e)
        return False


def get_s3_url(key: str) -> str | None:
    if not s3_client:
        return None
    try:
        return s3_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.s3_bucket, "Key": key},
            ExpiresIn=3600,
        )
    except Exception as e:
        logger.error("S3 presigned URL failed: %s", e)
        return None
