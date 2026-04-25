from __future__ import annotations

from io import BytesIO
from typing import Any, Dict, List, Optional
import traceback

from PIL import Image, ImageDraw

try:
    from transformers import pipeline
except ImportError:  # pragma: no cover - optional dependency
    pipeline = None

_detector = None

SUSPICIOUS_LABELS = {
    "cell phone": "mobile_detected",
    "mobile phone": "mobile_detected",
    "phone": "mobile_detected",
    "book": "book_detected",
}


def _get_detector():
    global _detector
    if _detector is not None:
        return _detector
    if pipeline is None:
        raise RuntimeError(
            "transformers is not installed. Install with: pip install transformers torch pillow"
        )
    print("Loading object detection model...")
    _detector = pipeline("object-detection", model="facebook/detr-resnet-50")
    print("Model loaded successfully.")
    return _detector


def _pick_best_suspicious(detections: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    best_match: Optional[Dict[str, Any]] = None
    for item in detections:
        label = str(item.get("label", "")).lower()
        score = float(item.get("score", 0.0))
        alert_type = SUSPICIOUS_LABELS.get(label)
        if not alert_type:
            continue
        if best_match is None or score > float(best_match.get("score", 0.0)):
            best_match = {"label": label, "score": score, "box": item.get("box"), "alert_type": alert_type}
    return best_match


def analyze_frame(frame_bytes: bytes) -> Dict[str, Any]:
    try:
        print("Frame received")
        print("Opening image...")
        image = Image.open(BytesIO(frame_bytes)).convert("RGB")
        print("Image opened successfully.")

        print("Running AI detection...")
        detector = _get_detector()
        detections = detector(image)
        print(f"Detection complete. Total detections: {len(detections)}")

        best = _pick_best_suspicious(detections)
        if not best:
            return {
                "success": True,
                "cheating_detected": False,
                "alert_type": None,
                "confidence": 0.0,
                "message": "No suspicious object detected.",
                "annotated_image_bytes": None,
                "error": None,
            }

        box = best.get("box") or {}
        x1 = int(box.get("xmin", 0))
        y1 = int(box.get("ymin", 0))
        x2 = int(box.get("xmax", 0))
        y2 = int(box.get("ymax", 0))

        draw = ImageDraw.Draw(image)
        draw.rectangle([(x1, y1), (x2, y2)], outline="red", width=4)
        draw.text((x1, max(0, y1 - 20)), f"{best['label']} {best['score']:.2f}", fill="red")

        output = BytesIO()
        image.save(output, format="JPEG")

        readable = "Mobile detected" if best["alert_type"] == "mobile_detected" else "Book/notes detected"
        return {
            "success": True,
            "cheating_detected": True,
            "alert_type": best["alert_type"],
            "confidence": round(float(best["score"]), 4),
            "message": readable,
            "annotated_image_bytes": output.getvalue(),
            "error": None,
        }
    except Exception as exc:
        print("AI detection failed.")
        traceback.print_exc()
        return {
            "success": False,
            "cheating_detected": False,
            "alert_type": None,
            "confidence": 0.0,
            "message": "Detection failed",
            "annotated_image_bytes": None,
            "error": str(exc),
        }
