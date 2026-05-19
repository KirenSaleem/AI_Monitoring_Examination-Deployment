from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from utils.datetime_utils import now


class ExamSession(BaseModel):
    session_id: str
    classroom_id: str
    exam_name: str
    started_by: str
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str = "active"
    monitored_students: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=now)


class StartExamRequest(BaseModel):
    classroom_id: str
    exam_name: str
    started_by: str


class EndExamRequest(BaseModel):
    session_id: str
    ended_by: str
