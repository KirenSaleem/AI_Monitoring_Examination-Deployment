from datetime import datetime
from typing import List

from pydantic import BaseModel, Field


class ClassroomCreateRequest(BaseModel):
    classroom_name: str
    created_by: str


class ClassroomJoinRequest(BaseModel):
    firebase_uid: str
    classroom_code: str


class Classroom(BaseModel):
    classroom_id: str
    classroom_name: str
    created_by: str
    classroom_code: str
    teachers: List[str] = Field(default_factory=list)
    students: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.utcnow)
