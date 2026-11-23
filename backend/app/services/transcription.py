import logging
from typing import List, Dict, Any, Optional
from ..core.config import settings

logger = logging.getLogger(__name__)

class TranscriptionService:
    _model_instance = None

    @classmethod
    def get_model(cls):
        """
        Lazy-loads the faster-whisper model on CPU with int8 quantization.
        Keeps RAM usage <= 1.6GB.
        """
        if cls._model_instance is None:
            try:
                from faster_whisper import WhisperModel
                logger.info(f"Loading faster-whisper model: {settings.WHISPER_MODEL_NAME} (device={settings.DEVICE}, compute_type={settings.COMPUTE_TYPE}, cpu_threads={settings.CPU_THREADS})")
                cls._model_instance = WhisperModel(
                    settings.WHISPER_MODEL_NAME,
                    device=settings.DEVICE,
                    compute_type=settings.COMPUTE_TYPE,
                    cpu_threads=settings.CPU_THREADS,
                    download_root=None  # will auto-cache to ~/.cache/huggingface/hub
                )
                logger.info("faster-whisper model successfully loaded.")
            except Exception as e:
                logger.error(f"Failed to load faster-whisper: {e}")
                raise e
        return cls._model_instance

    @classmethod
    def transcribe(
        cls,
        audio_path: str,
        language: Optional[str] = None,
        initial_prompt: Optional[str] = "Urdu and English bilingual meeting discussion."
    ) -> List[Dict[str, Any]]:
        """
        Transcribes the normalized 16kHz mono audio.
        Returns a list of segment dictionaries:
        [{ "start": 0.0, "end": 4.2, "text": "..." }, ...]
        """
        try:
            model = cls.get_model()
            logger.info(f"Starting transcription for {audio_path}")
            
            # vad_filter=True removes silence and improves timestamp alignment
            # language=None allows auto-detection and handles bilingual code-switching
            segments_gen, info = model.transcribe(
                audio_path,
                language=language,
                vad_filter=True,
                initial_prompt=initial_prompt,
                beam_size=5
            )
            
            logger.info(f"Transcription language detected: {info.language} (probability: {info.language_probability:.2f})")
            
            results = []
            for segment in segments_gen:
                clean_text = segment.text.strip()
                if clean_text:
                    results.append({
                        "start": round(segment.start, 2),
                        "end": round(segment.end, 2),
                        "text": clean_text
                    })
            
            logger.info(f"Generated {len(results)} transcript segments.")
            return results

        except Exception as e:
            logger.warning(f"Transcription execution error: {e}. Checking fallback.")
            raise e
