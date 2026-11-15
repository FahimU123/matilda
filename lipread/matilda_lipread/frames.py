import numpy as np

MODEL_FPS = 25


def resample(frames: list[np.ndarray], fps: float) -> list[np.ndarray]:
    count = max(1, round(len(frames) * MODEL_FPS / fps))
    return [frames[min(len(frames) - 1, int(index * fps / MODEL_FPS))] for index in range(count)]
