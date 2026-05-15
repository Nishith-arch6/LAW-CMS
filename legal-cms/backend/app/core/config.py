from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    postgres_server: str = "localhost"
    postgres_port: int = 5432
    postgres_user: str = "postgres"
    postgres_password: str = "postgres"
    postgres_db: str = "legal_cms"

    secret_key: str = "change-me-to-a-random-secret-key-32-chars-min"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60

    tesseract_cmd: str = "/usr/bin/tesseract"
    upload_dir: str = "./uploads"
    max_upload_size_mb: int = 50

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_tls: bool = True
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "noreply@legalcms.local"

    app_name: str = "Legal CMS"
    debug: bool = True

    environment: str = "dev"

    cors_origins: str = "*"

    s3_bucket: str = ""
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_region: str = "us-east-1"
    s3_endpoint: str = ""

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_server}:{self.postgres_port}/{self.postgres_db}?ssl=prefer"
        )

    @property
    def sync_database_url(self) -> str:
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_server}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def is_production(self) -> bool:
        return self.environment == "prod"

    @property
    def effective_debug(self) -> bool:
        return self.debug and not self.is_production

    @property
    def effective_cors_origins(self) -> list[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",")]

    @property
    def use_s3(self) -> bool:
        return bool(self.s3_bucket and self.s3_access_key and self.s3_secret_key)

    model_config = {"env_file": ".env", "case_sensitive": False, "extra": "ignore"}


settings = Settings()
