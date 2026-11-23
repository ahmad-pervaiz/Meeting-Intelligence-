import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .core.config import settings
from .core.database import Base, engine
from .routes import health, meetings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

# Create tables in SQLite / PostgreSQL
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Bilingual Meeting Intelligence & Follow-Up API",
    description="End-to-End Free-Tier Backend for Urdu & English Speech Recognition, Cross-Lingual English Summarization, WeasyPrint PDF Generation, and Email/Share Distribution.",
    version="1.0.0"
)

# Enable CORS for Flutter Mobile Client and Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static folders for local assets
app.mount("/static/uploads", StaticFiles(directory=settings.STORAGE_DIR), name="uploads")
app.mount("/static/pdfs", StaticFiles(directory=settings.PDF_STORAGE_DIR), name="pdfs")

# Register API Routers
app.include_router(health.router)
app.include_router(meetings.router)

@app.get("/")
def root():
    return {
        "service": "Bilingual Meeting Intelligence & Automated Follow-Up System",
        "docs_url": "/docs",
        "status": "online",
        "supported_languages": ["Urdu", "English", "Urdu-English Code-Switching"],
        "target_output": "100% Professional English PDF & Action Summaries"
    }
