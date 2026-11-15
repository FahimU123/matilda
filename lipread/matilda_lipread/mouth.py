"""Mouth crops matching Auto-AVSR's MediaPipe preparation (github.com/mpc001/auto_avsr, Apache 2.0)."""

from pathlib import Path

import cv2
import numpy as np

from .landmarks import Keypoints

TARGET_SIZE = 256
PATCH = 96
CROP = 88
MEAN, STD = 0.421, 0.165
SMOOTHING_WINDOW = 12


class NoFaceFound(ValueError):
    pass


def stable_reference(mean_face: np.ndarray) -> np.ndarray:
    return np.vstack(
        [
            mean_face[36:42].mean(axis=0),
            mean_face[42:48].mean(axis=0),
            mean_face[31:36].mean(axis=0),
            mean_face[48:68].mean(axis=0),
        ]
    )


def fill_gaps(landmarks: list[Keypoints | None]) -> list[Keypoints]:
    found = [index for index, points in enumerate(landmarks) if points is not None]
    if not found:
        raise NoFaceFound("No face was found in any frame")

    filled: list[Keypoints | None] = list(landmarks)
    for start, stop in zip(found, found[1:]):
        for offset in range(1, stop - start):
            weight = offset / (stop - start)
            filled[start + offset] = filled[start] + weight * (filled[stop] - filled[start])
    first, last = found[0], found[-1]
    for index in range(first):
        filled[index] = filled[first]
    for index in range(last + 1, len(filled)):
        filled[index] = filled[last]
    return [points for points in filled if points is not None]


def smoothed(landmarks: list[Keypoints], index: int) -> Keypoints:
    margin = min(SMOOTHING_WINDOW // 2, index, len(landmarks) - 1 - index)
    window = np.mean(landmarks[index - margin : index + margin + 1], axis=0)
    return window + landmarks[index].mean(axis=0) - window.mean(axis=0)


def crop_sequence(frames: list[np.ndarray], landmarks: list[Keypoints | None], mean_face: np.ndarray) -> np.ndarray:
    """Returns a normalised float32 array shaped (T, 88, 88)."""
    points = fill_gaps(landmarks)
    reference = stable_reference(mean_face)
    crops = []
    for index, frame in enumerate(frames):
        source = smoothed(points, index)
        transform = cv2.estimateAffinePartial2D(source, reference, method=cv2.LMEDS)[0]
        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        aligned = cv2.warpAffine(gray, transform, (TARGET_SIZE, TARGET_SIZE), flags=cv2.INTER_LINEAR)
        mouth = source[3] @ transform[:, :2].T + transform[:, 2]
        crops.append(cut(aligned, mouth))
    sequence = np.stack(crops).astype(np.float32) / 255.0
    return (sequence - MEAN) / STD


def cut(image: np.ndarray, centre: np.ndarray) -> np.ndarray:
    half = PATCH // 2
    x, y = (int(round(value)) for value in np.clip(centre, half, TARGET_SIZE - half))
    patch = image[y - half : y + half, x - half : x + half]
    margin = (PATCH - CROP) // 2
    return patch[margin : margin + CROP, margin : margin + CROP]


def load_mean_face(path: Path) -> np.ndarray:
    return np.load(path)
