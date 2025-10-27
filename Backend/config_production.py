"""
Production Configuration for Fly.io Deployment
Uses MongoDB Atlas and Cloudinary
"""
from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional
import os


class Settings(BaseSettings):
    """Application settings for production deployment."""
    
    # FastAPI Server
    host: str = Field(default="0.0.0.0", alias="HOST")
    port: int = Field(default=8080, alias="PORT")
    reload: bool = Field(default=False, alias="RELOAD")
    debug: bool = Field(default=False, alias="DEBUG")
    
    # MongoDB Atlas Configuration (Cloud)
    mongo_password: str = Field(..., alias="MONGO_PASSWORD")
    mongo_db_name: str = Field(default="almadhinadb", alias="MONGO_DB_NAME")
    
    @property
    def mongo_uri(self) -> str:
        """Construct MongoDB Atlas URI with password"""
        return f"mongodb+srv://vectoraiautomations_db_user:{self.mongo_password}@al-mathina.9xt8cbd.mongodb.net/"
    
    # Cloudinary Configuration (Image Storage)
    cloudinary_cloud_name: str = Field(..., alias="CLOUDINARY_CLOUD_NAME")
    cloudinary_api_key: str = Field(..., alias="CLOUDINARY_API_KEY")
    cloudinary_api_secret: str = Field(..., alias="CLOUDINARY_API_SECRET")
    
    # Application Settings
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    
    # JWT Configuration
    jwt_secret_key: str = Field(default="change_in_production", alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(default=30, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    
    class Config:
        env_file = ".env.production"
        env_file_encoding = "utf-8"
        case_sensitive = False
        extra = "ignore"


# Create settings instance
settings = Settings()
