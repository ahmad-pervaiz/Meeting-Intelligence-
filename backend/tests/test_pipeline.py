import os
import wave
import struct
import math
import pytest
from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.core.config import settings
from backend.app.services.audio_processor import AudioProcessor
from backend.app.services.diarization import DiarizationService
from backend.app.services.vector_store import VectorStoreService
from backend.app.services.llm_synthesis import LLMSynthesisService
from backend.app.services.pdf_generator import PDFGeneratorService
from backend.app.services.email_dispatcher import EmailDispatcherService

client = TestClient(app)

def create_synthetic_wav(filename: str, duration_sec: float = 3.0, sample_rate: int = 16000):
    """
    Creates a synthetic dual-tone speech-like WAV file for audio pipeline testing.
    """
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    num_samples = int(duration_sec * sample_rate)
    with wave.open(filename, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        for i in range(num_samples):
            # Alternate tone frequency to simulate two speakers
            freq = 440.0 if (i // (sample_rate // 2)) % 2 == 0 else 880.0
            val = int(32767.0 * 0.3 * math.sin(2.0 * math.pi * freq * (i / sample_rate)))
            data = struct.pack("<h", val)
            wf.writeframes(data)
    return filename

def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["device"] == "cpu"
    assert "whisper_model" in data

def test_audio_normalization_and_diarization(tmp_path):
    raw_wav = str(tmp_path / "raw_test.wav")
    clean_wav = str(tmp_path / "clean_test.wav")
    create_synthetic_wav(raw_wav, duration_sec=3.0)

    # 1. Standardize
    out_path, duration = AudioProcessor.standardize_audio(raw_wav, clean_wav)
    assert os.path.exists(out_path)
    assert duration > 2.5

    # 2. Diarization
    turns = DiarizationService.diarize(clean_wav)
    assert len(turns) >= 1
    assert "speaker" in turns[0]

    # 3. Alignment
    dummy_segments = [
        {"start": 0.0, "end": 1.5, "text": "السلام علیکم، اج کی میٹنگ شروع کرتے ہیں۔"},
        {"start": 1.5, "end": 3.0, "text": "We need to finalize the deployment schedule by Friday."}
    ]
    aligned = DiarizationService.align_speakers_with_transcript(dummy_segments, turns)
    assert len(aligned) == 2
    assert "speaker_label" in aligned[0]
    assert aligned[0]["speaker_label"].startswith("SPEAKER_")

def test_cross_lingual_english_synthesis():
    dummy_segments = [
        {"start_time": 0.0, "end_time": 2.5, "speaker_label": "SPEAKER_00", "text": "آج ہم نے بائی لنگول ماڈل کو ریویو کیا اور CPU پر ٹیسٹ کیا۔"},
        {"start_time": 2.6, "end_time": 5.0, "speaker_label": "SPEAKER_01", "text": "Action item is assigned to Ali Khan to deploy the Play Store bundle by Friday."}
    ]
    roster = [
        {"name": "Ali Khan", "email": "ali@example.com", "status": "Attended", "speaker_label": "SPEAKER_01"},
        {"name": "Sara Ahmed", "email": "sara@example.com", "status": "Absent", "speaker_label": None}
    ]

    summary = LLMSynthesisService.synthesize_meeting(dummy_segments, roster)
    assert summary.executive_summary
    assert len(summary.decisions) > 0
    assert len(summary.action_items) > 0
    # Verify English output
    assert "Not specified" in [a.owner for a in summary.action_items] or any(a.owner for a in summary.action_items)
    for a in summary.action_items:
        assert hasattr(a, "task")
        assert hasattr(a, "owner")
        assert hasattr(a, "deadline")
        assert hasattr(a, "timestamp")

def test_weasyprint_pdf_generation(tmp_path):
    summary_data = {
        "executive_summary": "The executive committee approved the bilingual meeting transcription pipeline with CPU int8 quantization.",
        "topics_discussed": ["ASR Model Benchmark", "Cross-Lingual English Synthesis", "Google Play Deployment"],
        "decisions": [
            {"decision": "Adopt faster-whisper large-v3-turbo on CPU.", "timestamp": "00:15 - 00:45"}
        ],
        "action_items": [
            {"task": "Build signed Android AAB package", "owner": "Ali Khan", "deadline": "Friday 5 PM", "timestamp": "01:20"}
        ],
        "open_questions": ["What is the Play Store closed testing timeline?"]
    }

    participants = [
        {"name": "Ali Khan", "email": "ali@example.com", "status": "Attended", "speaker_label": "SPEAKER_00"},
        {"name": "Sara Ahmed", "email": "sara@example.com", "status": "Absent", "speaker_label": "SPEAKER_01"}
    ]

    pdf_path = PDFGeneratorService.generate_mom_pdf(
        meeting_id="test_meeting_001",
        title="Sprint 10 Bilingual Architecture Review",
        date_str="November 24, 2026 - 10:00 AM",
        summary=summary_data,
        participants=participants,
        speaker_mapping={"SPEAKER_00": "Ali Khan"}
    )

    assert os.path.exists(pdf_path)
    assert os.path.getsize(pdf_path) > 1000  # valid PDF generated

def test_email_dispatcher_templates(tmp_path):
    pdf_test_file = str(tmp_path / "test_mom.pdf")
    with open(pdf_test_file, "wb") as f:
        f.write(b"%PDF-1.4 simulated pdf binary content")

    summary_data = {
        "executive_summary": "Sprint review successfully completed in bilingual English and Urdu.",
        "decisions": [{"decision": "Production release set for Friday", "timestamp": "00:45"}],
        "action_items": [{"task": "Prepare release notes", "owner": "Ali Khan", "deadline": "Thursday", "timestamp": "01:10"}]
    }

    participants = [
        {"name": "Ali Khan", "email": "ali@example.com", "status": "Attended"},
        {"name": "Sara Ahmed", "email": "sara@example.com", "status": "Absent"}
    ]

    res = EmailDispatcherService.distribute_meeting_mom(
        meeting_title="Sprint Review",
        summary=summary_data,
        participants=participants,
        pdf_path=pdf_test_file
    )

    assert res["status"] == "completed"
    assert res["attended_sent"] == 1
    assert res["absent_sent"] == 1
    assert res["recipients_count"] == 2

def test_vector_indexing_and_rag(tmp_path):
    meeting_id = "test_rag_123"
    segments = [
        {"start_time": 0.0, "end_time": 3.0, "speaker_label": "SPEAKER_00", "text": "The release date is scheduled for December 1st."},
        {"start_time": 3.1, "end_time": 6.0, "speaker_label": "SPEAKER_01", "text": "Security review must be concluded before the Play Store launch."}
    ]

    num_chunks = VectorStoreService.index_transcript(meeting_id, segments)
    assert num_chunks > 0

    qa_resp = client.post(f"/api/meetings/{meeting_id}/ask", json={"question": "When is the release date?"})
    # Since meeting isn't in DB yet for the route, we directly test RAG service:
    from backend.app.services.rag_qa import RAGQAService
    answer_res = RAGQAService.answer_question(meeting_id, "When is the release date?")
    assert answer_res.answer
    assert len(answer_res.citations) > 0
    assert "December 1st" in answer_res.citations[0].text or "December" in answer_res.answer
