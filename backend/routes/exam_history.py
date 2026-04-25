from fastapi import APIRouter, HTTPException

from services.exam_session_service import get_classroom_exam_history
from services.monitoring_service import get_session_alerts

router = APIRouter(tags=["exam-history"])


@router.get("/exam-history/{classroom_id}")
def exam_history(classroom_id: str):
    if not classroom_id.strip():
        raise HTTPException(status_code=400, detail="classroom_id is required.")
    history = get_classroom_exam_history(classroom_id.strip())
    return {"history": history}


@router.get("/exam-notifications/{session_id}")
def exam_notifications(session_id: str):
    if not session_id.strip():
        raise HTTPException(status_code=400, detail="session_id is required.")
    alerts = get_session_alerts(session_id.strip())
    return {"notifications": alerts}
