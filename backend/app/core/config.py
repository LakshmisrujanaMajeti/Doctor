import os
from typing import List, Union, Optional
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "OPD Connect+"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"

    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # JWT Security
    SECRET_KEY: str = "super_secret_opd_connect_jwt_key_default_change_in_production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours (prevents token expired errors during clinical shifts)
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Authentication & Security Controls
    AUTH_METHOD: str = "both"  # "email", "phone", "both"
    OTP_PROVIDER: str = "none"  # "none", "twilio", "msg91", "mock"
    ENABLE_DEV_MOCK_OTP: bool = True
    MAX_FAILED_LOGIN_ATTEMPTS: int = 5
    ACCOUNT_LOCKOUT_MINUTES: int = 15
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 15
    OTP_EXPIRE_MINUTES: int = 5

    # Database
    DATABASE_URL: str = "sqlite:///./opd_connect.db"
    NEON_DATABASE_URL: Optional[str] = None
    POSTGRES_URL: Optional[str] = None

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def assemble_database_url(cls, v: Optional[str]) -> str:
        neon = os.getenv("NEON_DATABASE_URL") or os.getenv("POSTGRES_URL")
        url = neon or v or "sqlite:///./opd_connect.db"
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql://", 1)
        if ("neon.tech" in url or "supabase.co" in url) and "sslmode=" not in url:
            separator = "&" if "?" in url else "?"
            url = f"{url}{separator}sslmode=require"
        return url

    @property
    def effective_database_url(self) -> str:
        url = (
            self.NEON_DATABASE_URL
            or os.getenv("NEON_DATABASE_URL")
            or self.POSTGRES_URL
            or os.getenv("POSTGRES_URL")
            or self.DATABASE_URL
        )
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql://", 1)
        if ("neon.tech" in url or "supabase.co" in url) and "sslmode=" not in url:
            separator = "&" if "?" in url else "?"
            url = f"{url}{separator}sslmode=require"
        return url

    # Supabase Settings
    SUPABASE_URL: str = "https://xxwidqatsxzsrulaxxal.supabase.co"
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Document Storage
    STORAGE_BACKEND: str = "local"  # "local" or "supabase"
    STORAGE_LOCAL_DIR: str = "./storage/medical_documents"
    SUPABASE_STORAGE_BUCKET: str = "medical-documents"

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, list):
            return v
        return ["*"]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
