from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
import os

class Settings(BaseSettings):
    APP_NAME: str = "Smart Public Sanitation & Drinking Water Management System"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://postgres.lsoxfxycwqykjwjingen:H2011IQI2ySWQjQc@aws-0-ap-south-1.pooler.supabase.com:6543/postgres")
    USE_POSTGIS: bool = True
    
    # Supabase Configuration
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://lsoxfxycwqykjwjingen.supabase.co")
    SUPABASE_PUBLISHABLE_KEY: str = os.getenv("SUPABASE_PUBLISHABLE_KEY", "")
    SUPABASE_SECRET_KEY: str = os.getenv("SUPABASE_SECRET_KEY", "")
    SUPABASE_JWKS_URL: str = os.getenv("SUPABASE_JWKS_URL", "https://lsoxfxycwqykjwjingen.supabase.co/auth/v1/.well-known/jwks.json")
    
    # Security
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "dev-super-secret-key-civic-sanitation-2026-xyz-987")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # Twilio (SMS / Voice / Verify)
    TWILIO_ACCOUNT_SID: Optional[str] = os.getenv("TWILIO_ACCOUNT_SID", None)
    TWILIO_AUTH_TOKEN: Optional[str] = os.getenv("TWILIO_AUTH_TOKEN", None)
    TWILIO_PHONE_NUMBER: Optional[str] = os.getenv("TWILIO_PHONE_NUMBER", None)
    TWILIO_VERIFY_SERVICE_SID: Optional[str] = os.getenv("TWILIO_VERIFY_SERVICE_SID", None)
    
    # Firebase / Supabase Storage
    FIREBASE_CREDENTIALS_PATH: Optional[str] = os.getenv("FIREBASE_CREDENTIALS_PATH", None)
    FIREBASE_STORAGE_BUCKET: Optional[str] = os.getenv("FIREBASE_STORAGE_BUCKET", None)
    
    # SLA & Thresholds
    SLA_RESOLUTION_HOURS: int = 24
    GEO_FENCE_MAX_DISTANCE_METERS: float = 30.0
    RATING_COOLDOWN_HOURS: int = 24
    DUPLICATE_TIME_WINDOW_HOURS: int = 12
    
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
