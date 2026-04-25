from fastapi import APIRouter, File, Form, HTTPException, UploadFile
import traceback

from services.monitoring_service import check_monitoring_frame, get_session_alerts

router = APIRouter(prefix="/monitoring", tags=["monitoring"])


@router.post("/check-frame")
async def check_frame(
    frame: UploadFile = File(...),
    classroom_id: str = Form(...),
    session_id: str = Form(...),
):
    if not classroom_id.strip() or not session_id.strip():
        raise HTTPException(status_code=400, detail="classroom_id and session_id are required.")

    print("POST /monitoring/check-frame called")
    frame_bytes = await frame.read()
    if not frame_bytes:
        raise HTTPException(status_code=400, detail="Empty frame uploaded.")

    try:
        result = check_monitoring_frame(
            frame_bytes=frame_bytes,
            classroom_id=classroom_id.strip(),
            session_id=session_id.strip(),
        )
        return result
    except RuntimeError as exc:
        print("Runtime error in monitoring route.")
        traceback.print_exc()
        return {
            "success": False,
            "cheating_detected": False,
            "alert_type": None,
            "confidence": 0.0,
            "message": "Runtime failure in monitoring pipeline.",
            "error": str(exc),
        }
    except Exception as exc:
        print("Unhandled exception in monitoring route.")
        traceback.print_exc()
        return {
            "success": False,
            "cheating_detected": False,
            "alert_type": None,
            "confidence": 0.0,
            "message": "Frame analysis failed.",
            "error": str(exc),
        }


@router.get("/alerts/{session_id}")
def session_alerts(session_id: str):
    alerts = get_session_alerts(session_id.strip())
    return {"alerts": alerts}
