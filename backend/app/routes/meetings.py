import os
import json
import logging
import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..core.config import settings
from ..models.database import Meeting, Participant, TranscriptSegment
from ..models.schemas import (
    MeetingResponse,
    SpeakerMappingRequest,
    AskQuestionRequest,
    AskQuestionResponse,
    DistributeRequest,
    DistributeResponse,
)
from ..services.audio_processor import AudioProcessor
from ..services.transcription import TranscriptionService
from ..services.diarization import DiarizationService
from ..services.vector_store import VectorStoreService
from ..services.llm_synthesis import LLMSynthesisService
from ..services.pdf_generator import PDFGeneratorService
from ..services.rag_qa import RAGQAService
from ..services.email_dispatcher import EmailDispatcherService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/meetings", tags=["Meetings"])

def process_meeting_pipeline(meeting_id: str, raw_audio_path: str):
    """
    Background worker that runs the full end-to-end AI pipeline:
    1. Standardization (FFmpeg)
    2. Transcription (faster-whisper CPU int8)
    3. Diarization & Alignment
    4. RAG Indexing (ChromaDB)
    5. Cross-Lingual English LLM Synthesis (Groq/Gemini/Fallback)
    6. WeasyPrint English PDF Generation
    """
    from ..core.database import SessionLocal
    db = SessionLocal()
    try:
        meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
        if not meeting:
            logger.error(f"Meeting {meeting_id} not found in background pipeline.")
            return

        clean_wav_path = os.path.join(settings.STORAGE_DIR, f"clean_{meeting_id}.wav")
        AudioProcessor.standardize_audio(raw_audio_path, clean_wav_path)
        meeting.audio_path = clean_wav_path
        meeting.audio_url = f"/api/meetings/{meeting_id}/audio"
        db.commit()

        # Step 2: Speech-to-Text via faster-whisper
        raw_segments = TranscriptionService.transcribe(clean_wav_path)

        # Step 3: Diarization & Alignment
        turns = DiarizationService.diarize(clean_wav_path)
        aligned_segments = DiarizationService.align_speakers_with_transcript(raw_segments, turns)

        # Persist segments to DB
        for seg in aligned_segments:
            db_seg = TranscriptSegment(
                id=str(uuid.uuid4()),
                meeting_id=meeting_id,
                speaker_label=seg["speaker_label"],
                start_time=seg["start_time"],
                end_time=seg["end_time"],
                text=seg["text"]
            )
            db.add(db_seg)
        db.commit()

        # Step 4: RAG Vector Indexing
        VectorStoreService.index_transcript(meeting_id, aligned_segments)

        # Step 5: Cross-Lingual English Synthesis
        participants_data = [
            {"name": p.name, "email": p.email, "status": p.status, "speaker_label": p.speaker_label}
            for p in meeting.participants
        ]
        summary_model = LLMSynthesisService.synthesize_meeting(aligned_segments, participants_data)
        meeting.summary_json = summary_model.model_dump()
        db.commit()

        # Step 6: PDF Generation
        pdf_path = PDFGeneratorService.generate_mom_pdf(
            meeting_id=meeting.id,
            title=meeting.title,
            date_str=meeting.created_at.strftime("%B %d, %Y - %I:%M %p"),
            summary=meeting.summary_json,
            participants=participants_data
        )
        meeting.pdf_path = pdf_path
        meeting.pdf_url = f"/api/meetings/{meeting_id}/pdf"
        meeting.status = "ready"
        db.commit()
        logger.info(f"Pipeline completed successfully for meeting {meeting_id}")

    except Exception as e:
        logger.error(f"Error in background pipeline for meeting {meeting_id}: {e}", exc_info=True)
        if meeting:
            meeting.status = "failed"
            db.commit()
    finally:
        db.close()


@router.post("/upload")
async def upload_meeting(
    background_tasks: BackgroundTasks,
    title: str = Form(...),
    participants: str = Form(default="[]"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Accepts multipart audio, meeting metadata, and participant JSON roster.
    Triggers background pipeline for transcription, diarization, synthesis, and PDF compilation.
    """
    meeting_id = str(uuid.uuid4())
    filename = file.filename or "recording.wav"
    raw_path = os.path.join(settings.STORAGE_DIR, f"raw_{meeting_id}_{filename}")

    # Save audio upload
    content = await file.read()
    with open(raw_path, "wb") as f:
        f.write(content)

    # Create meeting
    new_meeting = Meeting(
        id=meeting_id,
        title=title,
        status="processing",
        audio_path=raw_path
    )
    db.add(new_meeting)

    # Parse and add participants
    try:
        roster = json.loads(participants)
        for p in roster:
            db_p = Participant(
                id=str(uuid.uuid4()),
                meeting_id=meeting_id,
                name=p.get("name", "Unnamed"),
                email=p.get("email", ""),
                status=p.get("status", "Attended"),
                speaker_label=p.get("speaker_label", None)
            )
            db.add(db_p)
    except Exception as e:
        logger.warning(f"Could not parse participants JSON: {e}")

    db.commit()
    db.refresh(new_meeting)

    # Launch background task
    background_tasks.add_task(process_meeting_pipeline, meeting_id, raw_path)

    return {
        "id": meeting_id,
        "title": title,
        "status": "processing",
        "message": "Meeting audio uploaded. AI transcription and synthesis started in background."
    }


@router.get("", response_model=List[MeetingResponse])
def list_meetings(db: Session = Depends(get_db)):
    """
    Returns list of all meetings ordered by creation date.
    """
    meetings = db.query(Meeting).order_by(Meeting.created_at.desc()).all()
    return meetings


@router.get("/{meeting_id}", response_model=MeetingResponse)
def get_meeting(meeting_id: str, db: Session = Depends(get_db)):
    """
    Returns job status, speaker-aligned transcript, structured English summary JSON, and PDF URL.
    """
    meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return meeting


@router.get("/{meeting_id}/audio")
def get_meeting_audio(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
    if not meeting or not meeting.audio_path or not os.path.exists(meeting.audio_path):
        raise HTTPException(status_code=404, detail="Audio file not found")
    return FileResponse(meeting.audio_path, media_type="audio/wav")


@router.get("/{meeting_id}/pdf")
def get_meeting_pdf(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
    if not meeting or not meeting.pdf_path or not os.path.exists(meeting.pdf_path):
        raise HTTPException(status_code=404, detail="PDF not found or not yet generated")
    return FileResponse(
        meeting.pdf_path,
        media_type="application/pdf",
        filename=f"Minutes_of_Meeting_{meeting_id}.pdf"
    )


@router.patch("/{meeting_id}/speakers", response_model=MeetingResponse)
def map_speakers(meeting_id: str, req: SpeakerMappingRequest, db: Session = Depends(get_db)):
    """
    Human-in-the-Loop review: Maps anonymous diarization tags (SPEAKER_00)
    to verified participant names and regenerates the English PDF prior to distribution.
    """
    meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")

    mapping = req.mapping  # e.g. {"SPEAKER_00": "Ali Khan", "SPEAKER_01": "Fatima Ahmed"}

    # Update transcript segments
    for seg in meeting.segments:
        if seg.speaker_label in mapping:
            seg.speaker_label = mapping[seg.speaker_label]

    # Update participant speaker labels
    for p in meeting.participants:
        for label, name in mapping.items():
            if p.name.lower() == name.lower():
                p.speaker_label = label

    db.commit()

    # Re-index in vector store with updated speaker names
    aligned_segments = [
        {"start_time": s.start_time, "end_time": s.end_time, "speaker_label": s.speaker_label, "text": s.text}
        for s in meeting.segments
    ]
    VectorStoreService.index_transcript(meeting_id, aligned_segments)

    # Regenerate English PDF
    participants_data = [
        {"name": p.name, "email": p.email, "status": p.status, "speaker_label": p.speaker_label}
        for p in meeting.participants
    ]
    if meeting.summary_json:
        pdf_path = PDFGeneratorService.generate_mom_pdf(
            meeting_id=meeting.id,
            title=meeting.title,
            date_str=meeting.created_at.strftime("%B %d, %Y - %I:%M %p"),
            summary=meeting.summary_json,
            participants=participants_data,
            speaker_mapping=mapping
        )
        meeting.pdf_path = pdf_path
        meeting.pdf_url = f"/api/meetings/{meeting_id}/pdf"
        db.commit()

    db.refresh(meeting)
    return meeting


@router.post("/{meeting_id}/ask", response_model=AskQuestionResponse)
def ask_question(meeting_id: str, req: AskQuestionRequest, db: Session = Depends(get_db)):
    """
    RAG Q&A Endpoint: Answers user questions in 100% professional English with citations and timestamps.
    """
    meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")

    return RAGQAService.answer_question(meeting_id, req.question)


@router.post("/{meeting_id}/distribute", response_model=DistributeResponse)
def distribute_mom(meeting_id: str, req: DistributeRequest, db: Session = Depends(get_db)):
    """
    Dispatches customized English emails (Attended vs Absent) with attached MoM PDF to all participants.
    """
    meeting = db.query(Meeting).filter(Meeting.id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")

    if not meeting.pdf_path or not os.path.exists(meeting.pdf_path):
        raise HTTPException(status_code=400, detail="PDF has not been generated yet. Please wait until meeting status is 'ready'.")

    participants_data = [
        {"name": p.name, "email": p.email, "status": p.status}
        for p in meeting.participants
    ]

    result = EmailDispatcherService.distribute_meeting_mom(
        meeting_title=meeting.title,
        summary=meeting.summary_json or {},
        participants=participants_data,
        pdf_path=meeting.pdf_path,
        custom_message=req.custom_message
    )

    meeting.status = "sent"
    db.commit()

    return DistributeResponse(
        status=result["status"],
        recipients_count=result["recipients_count"],
        attended_sent=result["attended_sent"],
        absent_sent=result["absent_sent"],
        details=result["details"]
    )
