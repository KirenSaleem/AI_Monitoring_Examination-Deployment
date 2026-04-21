from fastapi import APIRouter, HTTPException

from models.user import UserProfile
from services.user_service import create_user, get_user_by_uid

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/create")
def create_user_profile(user_data: UserProfile):
    try:
        if not user_data.firebase_uid or not user_data.email or not user_data.name or not user_data.role:
            raise HTTPException(status_code=400, detail="firebase_uid, email, name and role are required.")

        role = user_data.role.lower()
        if role not in {"teacher", "student"}:
            raise HTTPException(status_code=400, detail="role must be teacher or student.")

        if role == "student":
            if not user_data.roll_no:
                raise HTTPException(status_code=400, detail="roll_no is required for students.")
            if not user_data.profile_image:
                raise HTTPException(status_code=400, detail="profile_image is required for students.")

        result = create_user(user_data)
        if result["status"] == "exists":
            return {"message": "User profile already exists"}
        return {"message": "User profile created successfully"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/{firebase_uid}")
def get_user_profile(firebase_uid: str):
    user = get_user_by_uid(firebase_uid)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"success": True, "user": user}
