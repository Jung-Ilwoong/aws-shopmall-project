import logging
import random

import boto3
from botocore.exceptions import ClientError

from app.config import settings

logger = logging.getLogger("shopmall.email")


def generate_verification_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def send_verification_email(to_email: str, code: str) -> None:
    if not settings.ses_sender_email:
        logger.warning("SES 미설정 — 콘솔 코드 대체: %s -> %s", to_email, code)
        return

    ses = boto3.client("ses", region_name=settings.aws_region)
    try:
        ses.send_email(
            Source=settings.ses_sender_email,
            Destination={"ToAddresses": [to_email]},
            Message={
                "Subject": {"Data": "[Shopmall] 이메일 인증 코드"},
                "Body": {"Text": {"Data": f"인증 코드: {code}\n5분 이내에 입력해주세요."}},
            },
        )
    except ClientError:
        logger.exception("SES 발송 실패 — 콘솔 코드 대체: %s -> %s", to_email, code)
