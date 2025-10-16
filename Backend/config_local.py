"""
Simplified Configuration for Local MongoDB Only
No Supabase required - works with local MongoDB for development
"""
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional


class Settings(BaseSettings):
    """Application settings for local MongoDB setup."""
    
    # FastAPI Server
    host: str = Field(default="127.0.0.1", alias="HOST")
    port: int = Field(default=8000, alias="PORT")
    reload: bool = Field(default=True, alias="RELOAD")
    debug: bool = Field(default=True, alias="DEBUG")
    
    # MongoDB Configuration (Local)
    mongo_uri: str = Field(default="mongodb://localhost:27017", alias="MONGO_URI")
    mongo_db_name: str = Field(default="almadhinadb", alias="MONGO_DB_NAME")
    
    # Application Settings
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False
        # Allow extra fields (ignore Supabase vars if present)
        extra = "ignore"


# Create settings instance
settings = Settings()
