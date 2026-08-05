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

    class Config:
        env_file = ".env"


settings = Settings()
