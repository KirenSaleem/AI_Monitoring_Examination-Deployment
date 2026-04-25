import secrets
import string
from datetime import datetime
from typing import Any, Dict, List
from uuid import uuid4

from db.database import classrooms_collection, users_collection
from models.classroom import Classroom


def _serialize_classroom(classroom_doc: Dict[str, Any]) -> Dict[str, Any]:
    classroom_doc.pop("_id", None)
    created_at = classroom_doc.get("created_at")
    if isinstance(created_at, datetime):
        classroom_doc["created_at"] = created_at.isoformat()
    classroom_doc = _attach_member_details(classroom_doc)
    return classroom_doc


def _generate_unique_code(length: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    while True:
        code = "".join(secrets.choice(alphabet) for _ in range(length))
        existing = classrooms_collection.find_one({"classroom_code": code})
        if not existing:
            return code


def _attach_member_details(classroom_doc: Dict[str, Any]) -> Dict[str, Any]:
    teachers: List[str] = classroom_doc.get("teachers", [])
    students: List[str] = classroom_doc.get("students", [])
    all_uids = list(set(teachers + students))
    users_cursor = users_collection.find(
        {"firebase_uid": {"$in": all_uids}},
        {"_id": 0, "firebase_uid": 1, "name": 1, "roll_no": 1, "profile_image": 1, "role": 1},
    )
    user_map = {doc.get("firebase_uid"): doc for doc in users_cursor}

    classroom_doc["teachers_details"] = [
        user_map[uid] for uid in teachers if uid in user_map
    ]
    classroom_doc["students_details"] = [
        user_map[uid] for uid in students if uid in user_map
    ]
    return classroom_doc


def create_classroom(classroom_name: str, created_by: str) -> Dict[str, Any]:
    classroom = Classroom(
        classroom_id=str(uuid4()),
        classroom_name=classroom_name,
        created_by=created_by,
        classroom_code=_generate_unique_code(),
        teachers=[created_by],
        students=[],
    )
    classroom_dict = classroom.model_dump()
    classrooms_collection.insert_one(classroom_dict)
    return _serialize_classroom(classroom_dict)


def join_classroom(firebase_uid: str, classroom_code: str) -> Dict[str, Any]:
    user_doc = users_collection.find_one({"firebase_uid": firebase_uid})
    if not user_doc:
        raise ValueError("User profile not found. Please complete profile setup first.")

    user_role = (user_doc.get("role") or "").lower()
    if user_role not in {"student", "teacher"}:
        raise ValueError("Invalid user role. Allowed roles are student and teacher.")

    normalized_code = classroom_code.upper()
    classroom_doc = classrooms_collection.find_one({"classroom_code": normalized_code})
    if not classroom_doc:
        raise ValueError("Invalid classroom code.")

    students: List[str] = classroom_doc.get("students", [])
    teachers: List[str] = classroom_doc.get("teachers", [])
    if firebase_uid in students or firebase_uid in teachers:
        return _serialize_classroom(classroom_doc)

    target_field = "teachers" if user_role == "teacher" else "students"
    classrooms_collection.update_one(
        {"classroom_code": normalized_code},
        {"$addToSet": {target_field: firebase_uid}},
    )
    updated_doc = classrooms_collection.find_one({"classroom_code": normalized_code})
    return _serialize_classroom(updated_doc) if updated_doc else _serialize_classroom(classroom_doc)


def get_teacher_classrooms(firebase_uid: str) -> List[Dict[str, Any]]:
    classrooms = classrooms_collection.find({"teachers": firebase_uid})
    return [_serialize_classroom(doc) for doc in classrooms]


def get_student_classrooms(firebase_uid: str) -> List[Dict[str, Any]]:
    classrooms = classrooms_collection.find({"students": firebase_uid})
    return [_serialize_classroom(doc) for doc in classrooms]
