from datetime import datetime
from typing import Any, Dict, Optional

from db.database import users_collection
from models.user import UserProfile


def _serialize_user(user_doc: Dict[str, Any]) -> Dict[str, Any]:
    user_doc.pop("_id", None)
    created_at = user_doc.get("created_at")
    if isinstance(created_at, datetime):
        user_doc["created_at"] = created_at.isoformat()
    return user_doc


def get_user_by_uid(firebase_uid: str) -> Optional[Dict[str, Any]]:
    user_doc = users_collection.find_one({"firebase_uid": firebase_uid})
    if not user_doc:
        return None
    return _serialize_user(user_doc)


def create_user(user_data: UserProfile) -> Dict[str, Any]:
    existing_user = get_user_by_uid(user_data.firebase_uid)
    if existing_user:
        return {"status": "exists"}

    user_dict = user_data.model_dump()
    user_dict["created_at"] = datetime.utcnow()
    users_collection.insert_one(user_dict)
    return {"status": "created"}


def update_user(user_data: UserProfile) -> Dict[str, Any]:
    users_collection.update_one(
        {"firebase_uid": user_data.firebase_uid},
        {"$set": user_data.model_dump()},
        upsert=True,
    )
    updated_user = get_user_by_uid(user_data.firebase_uid)
    return updated_user if updated_user else user_data.model_dump()
