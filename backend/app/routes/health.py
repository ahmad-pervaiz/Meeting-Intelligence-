from fastapi import APIRouter
from ..core.config import settings

router = APIRouter()

@router.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "Bilingual Meeting Intelligence & Follow-Up API",
        "device": settings.DEVICE,
        "whisper_model": settings.WHISPER_MODEL_NAME,
        "llm_provider": settings.LLM_PROVIDER,
        "environment": settings.ENVIRONMENT
    }
