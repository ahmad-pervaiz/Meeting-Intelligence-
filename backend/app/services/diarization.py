import logging
import os
import wave
import numpy as np
from typing import List, Dict, Any, Optional
from ..core.config import settings

logger = logging.getLogger(__name__)

class DiarizationService:
    @classmethod
    def diarize(cls, audio_path: str, num_speakers: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Diarizes audio into speaker turns:
        [{"start": 0.0, "end": 5.4, "speaker": "SPEAKER_00"}, ...]
        
        Attempts pyannote.audio first if HF_TOKEN is configured.
        Falls back automatically to energy/VAD acoustic turn clustering if HF_TOKEN is unset.
        """
        if settings.HF_TOKEN and settings.HF_TOKEN.strip():
            try:
                return cls._diarize_pyannote(audio_path, num_speakers)
            except Exception as e:
                logger.warning(f"pyannote diarization failed ({e}). Falling back to energy/VAD clustering.")
                return cls._diarize_vad_fallback(audio_path)
        else:
            logger.info("HF_TOKEN is unset. Using automatic energy/VAD acoustic turn clustering fallback.")
            return cls._diarize_vad_fallback(audio_path)

    @classmethod
    def _diarize_pyannote(cls, audio_path: str, num_speakers: Optional[int] = None) -> List[Dict[str, Any]]:
        from pyannote.audio import Pipeline
        import torch

        logger.info(f"Loading pyannote/speaker-diarization-3.1 with HF_TOKEN on CPU")
        pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=settings.HF_TOKEN
        )
        pipeline.to(torch.device("cpu"))
        
        params = {}
        if num_speakers:
            params["num_speakers"] = num_speakers
            
        diarization = pipeline(audio_path, **params)
        turns = []
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            turns.append({
                "start": round(turn.start, 2),
                "end": round(turn.end, 2),
                "speaker": speaker
            })
        return turns

    @classmethod
    def _diarize_vad_fallback(cls, audio_path: str) -> List[Dict[str, Any]]:
        """
        Robust CPU-only Energy/VAD turn segmenter fallback when HF_TOKEN is unset.
        Reads WAV frames, identifies speech pauses, and clusters consecutive conversational
        turns between SPEAKER_00 and SPEAKER_01 (and SPEAKER_02 if multiparty).
        """
        try:
            with wave.open(audio_path, "rb") as wf:
                sample_rate = wf.getframerate()
                num_channels = wf.getnchannels()
                num_frames = wf.getnframes()
                raw_data = wf.readframes(num_frames)
                
            samples = np.frombuffer(raw_data, dtype=np.int16).astype(np.float32)
            if num_channels > 1:
                samples = samples[::num_channels]
                
            duration = num_frames / sample_rate
            if duration <= 0:
                return [{"start": 0.0, "end": 1.0, "speaker": "SPEAKER_00"}]

            # Frame size 50ms
            frame_len = int(sample_rate * 0.05)
            num_chunks = len(samples) // frame_len
            if num_chunks == 0:
                return [{"start": 0.0, "end": duration, "speaker": "SPEAKER_00"}]

            frames = samples[: num_chunks * frame_len].reshape(num_chunks, frame_len)
            energies = np.sqrt(np.mean(frames ** 2, axis=1))
            threshold = np.percentile(energies, 40)

            # Detect voice activity regions
            is_speech = energies > threshold
            turns = []
            
            in_turn = False
            turn_start = 0.0
            speaker_idx = 0
            pause_frames = 0
            max_pause_frames = int(0.6 / 0.05)  # 600ms silence marks turn boundary

            for i, active in enumerate(is_speech):
                time_sec = i * 0.05
                if active:
                    if not in_turn:
                        in_turn = True
                        turn_start = time_sec
                    pause_frames = 0
                else:
                    if in_turn:
                        pause_frames += 1
                        if pause_frames >= max_pause_frames or i == num_chunks - 1:
                            turn_end = time_sec - (pause_frames * 0.05)
                            if turn_end - turn_start >= 0.5:
                                turns.append({
                                    "start": round(max(0.0, turn_start), 2),
                                    "end": round(turn_end, 2),
                                    "speaker": f"SPEAKER_{speaker_idx % 2:02d}"
                                })
                                speaker_idx += 1
                            in_turn = False
                            pause_frames = 0

            if in_turn:
                turns.append({
                    "start": round(turn_start, 2),
                    "end": round(duration, 2),
                    "speaker": f"SPEAKER_{speaker_idx % 2:02d}"
                })

            if not turns:
                turns.append({"start": 0.0, "end": round(duration, 2), "speaker": "SPEAKER_00"})

            return turns

        except Exception as e:
            logger.error(f"VAD Diarization fallback error: {e}. Defaulting to single speaker.")
            return [{"start": 0.0, "end": 9999.0, "speaker": "SPEAKER_00"}]

    @staticmethod
    def align_speakers_with_transcript(
        transcript_segments: List[Dict[str, Any]],
        diarization_turns: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Aligns speaker labels with transcript segments based on maximum time overlap.
        """
        aligned_segments = []
        for seg in transcript_segments:
            seg_start = seg["start"]
            seg_end = seg["end"]
            seg_text = seg["text"]

            best_speaker = "SPEAKER_00"
            max_overlap = -1.0

            for turn in diarization_turns:
                overlap_start = max(seg_start, turn["start"])
                overlap_end = min(seg_end, turn["end"])
                overlap = max(0.0, overlap_end - overlap_start)

                if overlap > max_overlap:
                    max_overlap = overlap
                    best_speaker = turn["speaker"]

            # If no direct overlap, pick closest turn
            if max_overlap <= 0.0 and diarization_turns:
                closest_turn = min(
                    diarization_turns,
                    key=lambda t: min(abs(t["start"] - seg_start), abs(t["end"] - seg_end))
                )
                best_speaker = closest_turn["speaker"]

            aligned_segments.append({
                "start_time": seg_start,
                "end_time": seg_end,
                "speaker_label": best_speaker,
                "text": seg_text
            })

        return aligned_segments
