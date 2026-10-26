import os
from pathlib import Path
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "Yuno Music API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    SECRET_KEY: str = os.getenv("SECRET_KEY", "yuno-jwt-secret-key-change-in-prod-7c3aed")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days
    
    DATABASE_URL: str = os.getenv("DATABASE_URL", f"sqlite+aiosqlite:///{BASE_DIR}/yuno.db")
    CACHE_DIR: str = os.getenv("CACHE_DIR", str(BASE_DIR / "cache"))
    
    # Soundcloud & external settings
    SOUNDCLOUD_CLIENT_ID: str = os.getenv("SOUNDCLOUD_CLIENT_ID", "")

    def get_database_url(self) -> str:
        url = self.DATABASE_URL
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif url.startswith("postgresql://") and "+asyncpg" not in url:
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url

    class Config:
        env_file = ".env"
        extra = "allow"

settings = Settings()
os.makedirs(settings.CACHE_DIR, exist_ok=True)
