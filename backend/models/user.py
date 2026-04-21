from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class UserProfile(BaseModel):
    firebase_uid: str
    name: str
    email: str
    role: str
    roll_no: Optional[str] = None
    profile_image: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
