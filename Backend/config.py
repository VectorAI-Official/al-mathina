"""
Configuration management for the FastAPI application.
Loads environment variables and provides typed configuration objects.
"""
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # FastAPI Server
    host: str = Field(default="127.0.0.1", alias="HOST")
    port: int = Field(default=8000, alias="PORT")
    reload: bool = Field(default=True, alias="RELOAD")
    
    # Supabase Configuration (PostgreSQL + Auth)
    supabase_url: str = Field(..., alias="SUPABASE_URL")
    supabase_anon_key: str = Field(..., alias="SUPABASE_ANON_KEY")
    supabase_service_key: Optional[str] = Field(None, alias="SUPABASE_SERVICE_KEY")
    supabase_api_url: str = Field(default="http://127.0.0.1:54321", alias="SUPABASE_API_URL")
    
    # MongoDB Configuration
    mongo_uri: str = Field(..., alias="MONGO_URI")
    mongo_db_name: str = Field(default="al_madhina_catalog", alias="MONGO_DB_NAME")
    
    # Application Settings
    debug: bool = Field(default=True, alias="DEBUG")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    
    # JWT Configuration (for custom auth if needed)
    jwt_secret_key: str = Field(..., alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(default=30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# Global settings instance
settings = Settings()
