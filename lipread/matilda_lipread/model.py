import json
from pathlib import Path

import numpy as np
import onnxruntime as ort


class LipReader:
    """Auto-AVSR visual encoder with a CTC head, decoded greedily."""

    def __init__(self, model_path: Path, tokens_path: Path) -> None:
        self._session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        self._tokens: list[str] = json.loads(tokens_path.read_text())

    def read(self, crops: np.ndarray) -> str:
        video = crops[np.newaxis, np.newaxis, ...].astype(np.float32)
        (log_probs,) = self._session.run(["log_probs"], {"video": video})
        return decode_ctc(log_probs.argmax(axis=-1).tolist(), self._tokens)


def decode_ctc(ids: list[int], tokens: list[str]) -> str:
    blank, end = 0, len(tokens) - 1
    pieces = []
    previous = None
    for token_id in ids:
        if token_id != previous and token_id not in (blank, end):
            pieces.append(tokens[token_id])
        previous = token_id
    return "".join(pieces).replace("▁", " ").strip()
