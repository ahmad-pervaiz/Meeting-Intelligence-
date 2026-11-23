import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, Float, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from ..core.database import Base

class Meeting(Base):
    __tablename__ = "meetings"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(255), nullable=False)
    status = Column(String(50), default="processing")  # processing, ready, failed, sent
    audio_path = Column(String(512), nullable=True)
    audio_url = Column(String(512), nullable=True)
    pdf_path = Column(String(512), nullable=True)
    pdf_url = Column(String(512), nullable=True)
    summary_json = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    participants = relationship("Participant", back_populates="meeting", cascade="all, delete-orphan")
    segments = relationship("TranscriptSegment", back_populates="meeting", cascade="all, delete-orphan")
    chunks = relationship("TranscriptChunk", back_populates="meeting", cascade="all, delete-orphan")


class Participant(Base):
    __tablename__ = "participants"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id = Column(String(36), ForeignKey("meetings.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=False)
    speaker_label = Column(String(50), nullable=True)  # e.g., "SPEAKER_00"
    status = Column(String(50), default="Attended")  # "Attended" or "Absent"

    meeting = relationship("Meeting", back_populates="participants")


class TranscriptSegment(Base):
    __tablename__ = "transcript_segments"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id = Column(String(36), ForeignKey("meetings.id", ondelete="CASCADE"), nullable=False)
    speaker_label = Column(String(50), default="SPEAKER_00")
    start_time = Column(Float, nullable=False)
    end_time = Column(Float, nullable=False)
    text = Column(Text, nullable=False)

    meeting = relationship("Meeting", back_populates="segments")


class TranscriptChunk(Base):
    __tablename__ = "transcript_chunks"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    meeting_id = Column(String(36), ForeignKey("meetings.id", ondelete="CASCADE"), nullable=False)
    chunk_text = Column(Text, nullable=False)
    timestamp_range = Column(String(100), nullable=False)
    embedding_id = Column(String(100), nullable=True)

    meeting = relationship("Meeting", back_populates="chunks")
