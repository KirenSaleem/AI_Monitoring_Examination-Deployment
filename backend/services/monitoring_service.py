from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List
from uuid import uuid4
import traceback

from db.database import notifications_collection
from services.detection_service import analyze_frame
from utils.datetime_utils import now, now_iso

ALERTS_DIR = Path("storage/alerts")
ALERTS_URL_PREFIX = "/alerts"


def _serialize_notification(notification_doc: Dict[str, Any]) -> Dict[str, Any]:
    notification_doc.pop("_id", None)
    for key in ("created_at", "frame_captured_at"):
        value = notification_doc.get(key)
        if isinstance(value, datetime):
            notification_doc[key] = value.isoformat()
    frame_path = notification_doc.get("frame_path")
    if isinstance(frame_path, str) and frame_path:
        file_name = Path(frame_path).name
        notification_doc["evidence_image_url"] = f"{ALERTS_URL_PREFIX}/{file_name}"
    return notification_doc


def check_monitoring_frame(frame_bytes: bytes, classroom_id: str, session_id: str) -> Dict[str, Any]:
    captured_at = now()
    captured_iso = now_iso()
    result = analyze_frame(frame_bytes)

    base = {
        "success": result.get("success", True),
        "cheating_detected": bool(result.get("cheating_detected", False)),
        "alert_type": result.get("alert_type"),
        "confidence": float(result.get("confidence") or 0.0),
        "message": result.get("message", ""),
        "error": result.get("error"),
        "captured_at": captured_iso,
    }

    if not result.get("success", True):
        base["success"] = False
        base["message"] = "Frame processed but AI detection failed."
        base["error"] = result.get("error", "Unknown detection error")
        return base

    if not result.get("cheating_detected"):
        return base

    try:
        ALERTS_DIR.mkdir(parents=True, exist_ok=True)
        notification_id = str(uuid4())
        frame_name = f"{session_id}_{notification_id}.jpg"
        frame_path = ALERTS_DIR / frame_name
        evidence_bytes = result.get("annotated_image_bytes")
        if evidence_bytes:
            frame_path.write_bytes(evidence_bytes)

        notification = {
            "id": notification_id,
            "classroom_id": classroom_id,
            "session_id": session_id,
            "alert_type": result["alert_type"],
            "confidence": result["confidence"],
            "frame_path": str(frame_path),
            "status": "unread",
            "created_at": captured_at,
            "frame_captured_at": captured_at,
        }
        notifications_collection.insert_one(notification)
    except Exception as exc:
        print("Failed while saving suspicious frame or Mongo insert.")
        traceback.print_exc()
        base["success"] = False
        base["error"] = f"Failed to store suspicious frame/notification: {exc}"
        return base

    return base


def get_session_alerts(session_id: str) -> List[Dict[str, Any]]:
    docs = notifications_collection.find({"session_id": session_id}).sort("created_at", -1)
    return [_serialize_notification(doc) for doc in docs]
