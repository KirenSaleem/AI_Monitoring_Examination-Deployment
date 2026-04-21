from fastapi import APIRouter

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/test")
def auth_test():
    return {"message": "Auth route working"}

@router.get("/verify")
def verify():
    return {"message": "Firebase setup ready"}