from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import List, Optional, Dict, Any
from datetime import datetime

# --- Participants ---
class ParticipantBase(BaseModel):
    name: str = Field(..., json_schema_extra={"example": "Ali Khan"})
    email: EmailStr = Field(..., json_schema_extra={"example": "ali.khan@example.com"})
    status: str = Field(default="Attended", json_schema_extra={"example": "Attended"})  # "Attended" or "Absent"
    speaker_label: Optional[str] = Field(default=None, json_schema_extra={"example": "SPEAKER_00"})

class ParticipantCreate(ParticipantBase):
    pass

class ParticipantResponse(ParticipantBase):
    model_config = ConfigDict(from_attributes=True)
    id: str
    meeting_id: str


# --- Transcript Segments ---
class TranscriptSegmentBase(BaseModel):
    speaker_label: str = Field(default="SPEAKER_00", json_schema_extra={"example": "SPEAKER_00"})
    start_time: float = Field(..., json_schema_extra={"example": 0.0})
    end_time: float = Field(..., json_schema_extra={"example": 3.45})
    text: str = Field(..., json_schema_extra={"example": "السلام علیکم، آج کی میٹنگ کا ایجنڈا ڈسکس کرتے ہیں۔"})

class TranscriptSegmentCreate(TranscriptSegmentBase):
    pass

class TranscriptSegmentResponse(TranscriptSegmentBase):
    model_config = ConfigDict(from_attributes=True)
    id: str
    meeting_id: str


# --- Structured English Synthesis ---
class DecisionItem(BaseModel):
    decision: str = Field(..., description="The decision made in the meeting")
    timestamp: str = Field(..., description="Audio timestamp range e.g. 02:15 - 02:45 or [01:20]")

class ActionItem(BaseModel):
    task: str = Field(..., description="Specific assigned action item")
    owner: str = Field(..., description="Name or speaker assigned, or 'Not specified'")
    deadline: str = Field(..., description="Deadline mentioned, or 'Not specified'")
    timestamp: str = Field(..., description="Audio timestamp range e.g. 03:10 or [03:10]")

class MeetingSummaryStructure(BaseModel):
    executive_summary: str = Field(..., description="High-level professional English executive summary of the meeting")
    topics_discussed: List[str] = Field(default_factory=list, description="Key topics covered during the meeting")
    decisions: List[DecisionItem] = Field(default_factory=list, description="Concrete decisions agreed upon")
    action_items: List[ActionItem] = Field(default_factory=list, description="Assigned action items with owners and deadlines")
    open_questions: List[str] = Field(default_factory=list, description="Unresolved topics or open questions")


# --- Meeting Requests & Responses ---
class MeetingCreate(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "Sprint Planning & Architecture Sync"})
    participants: List[ParticipantCreate] = Field(default_factory=list)

class MeetingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    title: str
    status: str
    audio_url: Optional[str] = None
    pdf_url: Optional[str] = None
    summary_json: Optional[MeetingSummaryStructure] = None
    created_at: datetime
    updated_at: datetime
    participants: List[ParticipantResponse] = Field(default_factory=list)
    segments: List[TranscriptSegmentResponse] = Field(default_factory=list)

class SpeakerMappingRequest(BaseModel):
    mapping: Dict[str, str] = Field(..., json_schema_extra={"example": {"SPEAKER_00": "Ali Khan", "SPEAKER_01": "Fatima Ahmed"}})

class AskQuestionRequest(BaseModel):
    question: str = Field(..., json_schema_extra={"example": "What was decided regarding the deployment deadline?"})

class Citation(BaseModel):
    speaker: str
    start_time: float
    end_time: float
    timestamp_str: str
    text: str

class AskQuestionResponse(BaseModel):
    answer: str
    citations: List[Citation] = Field(default_factory=list)

class DistributeRequest(BaseModel):
    custom_message: Optional[str] = None

class DistributeResponse(BaseModel):
    status: str
    recipients_count: int
    attended_sent: int
    absent_sent: int
    details: List[Dict[str, Any]] = Field(default_factory=list)
