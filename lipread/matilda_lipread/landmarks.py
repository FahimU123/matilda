from pathlib import Path

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import BaseOptions, vision

Keypoints = np.ndarray  # shape (4, 2): right eye, left eye, nose tip, mouth centre, in pixels


class FaceKeypoints:
    """BlazeFace keypoints per frame, the same four points Auto-AVSR was trained with."""

    def __init__(self, model_path: Path) -> None:
        options = vision.FaceDetectorOptions(
            base_options=BaseOptions(model_asset_path=str(model_path)),
            running_mode=vision.RunningMode.IMAGE,
            min_detection_confidence=0.5,
        )
        self._detector = vision.FaceDetector.create_from_options(options)

    def __call__(self, frames: list[np.ndarray]) -> list[Keypoints | None]:
        return [self._detect(frame) for frame in frames]

    def _detect(self, rgb: np.ndarray) -> Keypoints | None:
        result = self._detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
        if not result.detections:
            return None
        face = max(result.detections, key=lambda d: d.bounding_box.width * d.bounding_box.height)
        height, width = rgb.shape[:2]
        return np.array([[point.x * width, point.y * height] for point in face.keypoints[:4]], dtype=np.float64)
