import subprocess
import os
import json
import logging
from typing import Tuple

logger = logging.getLogger(__name__)

class AudioProcessor:
    @staticmethod
    def standardize_audio(input_path: str, output_path: str) -> Tuple[str, float]:
        """
        Converts any audio file (mp3, wav, m4a, ogg, webm) to 16kHz mono WAV via ffmpeg.
        Returns the output path and the duration in seconds.
        """
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # FFmpeg command: 16kHz, 1 channel (mono), 16-bit PCM
        cmd = [
            "ffmpeg",
            "-y",  # overwrite
            "-i", input_path,
            "-ar", "16000",
            "-ac", "1",
            "-c:a", "pcm_s16le",
            output_path
        ]
        
        logger.info(f"Normalizing audio: {' '.join(cmd)}")
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            logger.error(f"FFmpeg error: {result.stderr}")
            raise RuntimeError(f"FFmpeg standardization failed: {result.stderr}")
            
        duration = AudioProcessor.get_duration(output_path)
        logger.info(f"Standardized audio created: {output_path} (Duration: {duration:.2f}s)")
        return output_path, duration

    @staticmethod
    def get_duration(audio_path: str) -> float:
        """
        Gets audio duration using ffprobe.
        """
        cmd = [
            "ffprobe",
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            audio_path
        ]
        try:
            result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            return float(result.stdout.strip())
        except Exception as e:
            logger.warning(f"Could not read duration via ffprobe: {e}. Falling back to default.")
            return 0.0
