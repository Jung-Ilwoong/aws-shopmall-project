from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    db_host: str = "localhost"
    db_port: int = 3306
    db_user: str = "admin"
    db_password: str = "changeme"
    db_name: str = "shopmall"

    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24

    anthropic_api_key: str = ""

    aws_region: str = "ap-northeast-2"
    s3_uploads_bucket: str = ""
    uploads_cloudfront_domain: str = ""

    # 비어있으면(로컬 개발 등 SES 미설정 상태) 실제 발송 대신 콘솔 로그로 코드를 대체함
    ses_sender_email: str = ""

    class Config:
        env_file = ".env"


settings = Settings()
