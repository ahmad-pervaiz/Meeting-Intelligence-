import os
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    HOST: str = "0.0.0.0"
    PORT: int = 8000
    ENVIRONMENT: str = "development"
    BASE_URL: str = "http://localhost:8000"

    # AI Model Configuration (CPU Only, 16GB RAM)
    WHISPER_MODEL_NAME: str = "large-v3-turbo"
    DEVICE: str = "cpu"
    COMPUTE_TYPE: str = "int8"
    CPU_THREADS: int = 4
    EMBEDDING_MODEL_NAME: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"

    # HF Token (Optional)
    HF_TOKEN: Optional[str] = None

    # Cloud LLM Free Tiers
    GROQ_API_KEY: Optional[str] = None
    GEMINI_API_KEY: Optional[str] = None
    LLM_PROVIDER: str = "groq"
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    GEMINI_MODEL: str = "gemini-2.5-flash"

    # Email
    RESEND_API_KEY: Optional[str] = None
    EMAIL_FROM: str = "Meeting Intelligence <onboarding@resend.dev>"
    SMTP_SERVER: Optional[str] = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_USE_TLS: bool = True

    # Storage & DB
    DATABASE_URL: str = "sqlite:///./meeting_intelligence.db"
    STORAGE_DIR: str = "./uploads"
    PDF_STORAGE_DIR: str = "./generated_pdfs"

settings = Settings()

# Ensure directories exist
os.makedirs(settings.STORAGE_DIR, exist_ok=True)
os.makedirs(settings.PDF_STORAGE_DIR, exist_ok=True)
