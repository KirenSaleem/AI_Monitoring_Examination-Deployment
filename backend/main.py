from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from routes.auth import router as auth_router
from routes.classroom import router as classroom_router
from routes.exam_session import router as exam_router
from routes.exam_history import router as exam_history_router
from routes.monitoring import router as monitoring_router
from routes.user import router as user_router

app = FastAPI(title="ExamGuard Backend")

app.include_router(auth_router)
app.include_router(user_router)
app.include_router(classroom_router)
app.include_router(exam_router)
app.include_router(exam_history_router)
app.include_router(monitoring_router)

alerts_dir = Path(__file__).resolve().parent / "storage" / "alerts"
alerts_dir.mkdir(parents=True, exist_ok=True)
app.mount("/alerts", StaticFiles(directory=str(alerts_dir)), name="alerts")


@app.get("/")
def root():
    return {"message": "ExamGuard Backend Running"}
