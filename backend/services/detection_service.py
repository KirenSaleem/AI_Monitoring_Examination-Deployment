from __future__ import annotations

from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple
import traceback

from PIL import Image, ImageDraw, ImageOps

try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None

try:
    import torch

    _TORCH_AVAILABLE = True
except ImportError:
    _TORCH_AVAILABLE = False

_model = None

_MODEL_NAME = "yolov8n.pt"
_INFERENCE_SIZE = 640
_CONFIDENCE = 0.18

# COCO class ids — only phone & book (faster than scanning all 80 classes)
_PHONE_CLASS_ID = 67
_BOOK_CLASS_ID = 73
_SUSPICIOUS_CLASS_IDS = [_PHONE_CLASS_ID, _BOOK_CLASS_ID]

SUSPICIOUS_LABELS = {
    "cell phone": "mobile_detected",
    "book": "book_detected",
}


def _get_model():
    global _model
    if _model is not None:
        return _model
    if YOLO is None:
        raise RuntimeError("Install ultralytics: pip install ultralytics pillow")
    print(f"Loading {_MODEL_NAME}...")
    _model = YOLO(_MODEL_NAME)
    print("YOLO loaded.")
    return _model


def _clamp_box(x1: float, y1: float, x2: float, y2: float, w: int, h: int) -> Tuple[int, int, int, int]:
    ix1 = max(0, min(int(round(x1)), w - 1))
    iy1 = max(0, min(int(round(y1)), h - 1))
    ix2 = max(ix1 + 1, min(int(round(x2)), w))
    iy2 = max(iy1 + 1, min(int(round(y2)), h))
    return ix1, iy1, ix2, iy2


def analyze_frame(frame_bytes: bytes) -> Dict[str, Any]:
    """Detect only cell phone & book; draw boxes only on suspicious objects."""
    try:
        image = Image.open(BytesIO(frame_bytes)).convert("RGB")
        image = ImageOps.exif_transpose(image)
        orig_w, orig_h = image.size

        model = _get_model()
        predict_kwargs = {
            "imgsz": _INFERENCE_SIZE,
            "conf": _CONFIDENCE,
            "classes": _SUSPICIOUS_CLASS_IDS,
            "verbose": False,
        }

        if _TORCH_AVAILABLE:
            with torch.inference_mode():
                results = model.predict(image, **predict_kwargs)
        else:
            results = model.predict(image, **predict_kwargs)

        result = results[0]
        boxes = result.boxes

        cheating_detected = False
        alert_type: Optional[str] = None
        highest_confidence = 0.0
        best_box: Optional[Tuple[int, int, int, int]] = None
        best_label = ""

        if boxes is not None and len(boxes) > 0:
            names = result.names
            xyxy_list = boxes.xyxy.cpu().tolist()
            conf_list = boxes.conf.cpu().tolist()
            cls_list = [int(c) for c in boxes.cls.cpu().tolist()]

            for (x1, y1, x2, y2), score, cls_id in zip(xyxy_list, conf_list, cls_list):
                label = str(names.get(int(cls_id), "")).lower()
                alert = SUSPICIOUS_LABELS.get(label)
                if not alert:
                    continue

                conf = float(score)
                if conf > highest_confidence:
                    highest_confidence = conf
                    alert_type = alert
                    best_label = label
                    best_box = _clamp_box(x1, y1, x2, y2, orig_w, orig_h)

            cheating_detected = best_box is not None

        annotated_bytes: Optional[bytes] = None
        if cheating_detected and best_box is not None:
            draw = ImageDraw.Draw(image)
            bx1, by1, bx2, by2 = best_box
            stroke = max(2, int(min(orig_w, orig_h) / 200))
            draw.rectangle([(bx1, by1), (bx2, by2)], outline="red", width=stroke)
            draw.text((bx1, max(0, by1 - 18)), f"{best_label} {highest_confidence:.2f}", fill="red")
            output = BytesIO()
            image.save(output, format="JPEG", quality=85)
            annotated_bytes = output.getvalue()

        if cheating_detected:
            message = (
                "Mobile detected"
                if alert_type == "mobile_detected"
                else "Book/notes detected"
            )
        else:
            message = "No suspicious object detected."

        return {
            "success": True,
            "cheating_detected": cheating_detected,
            "alert_type": alert_type,
            "confidence": round(highest_confidence, 4),
            "message": message,
            "annotated_image_bytes": annotated_bytes,
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
