from fastapi import FastAPI

from routes.auth import router as auth_router
from routes.classroom import router as classroom_router
from routes.exam_session import router as exam_router
from routes.user import router as user_router

app = FastAPI(title="ExamGuard Backend")

app.include_router(auth_router)
app.include_router(user_router)
app.include_router(classroom_router)
app.include_router(exam_router)


@app.get("/")
def root():
    return {"message": "ExamGuard Backend Running"}
