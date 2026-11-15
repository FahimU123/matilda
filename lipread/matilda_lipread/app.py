import base64
import binascii
import os
from pathlib import Path
from typing import Annotated

MAX_SIDE = 1280
os.environ.setdefault("OPENCV_IO_MAX_IMAGE_PIXELS", str(MAX_SIDE * MAX_SIDE))

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from .commands import Command, command_for
from .frames import resample
from .landmarks import FaceKeypoints
from .model import LipReader
from .mouth import NoFaceFound, crop_sequence, load_mean_face

ASSETS = Path(os.environ.get("LIPREAD_ASSETS", Path(__file__).resolve().parent.parent / "assets"))
MAX_FRAMES = 150
MAX_FRAME_CHARS = 300_000


class ReadRequest(BaseModel):
    fps: float = Field(gt=0, le=120)
    frames: list[Annotated[str, Field(max_length=MAX_FRAME_CHARS)]] = Field(
        min_length=4, max_length=400, description="Base64 JPEG frames, upright"
    )


class ReadResponse(BaseModel):
    text: str
    command: Command | None


app = FastAPI(title="Matilda lip reader")
detector = FaceKeypoints(ASSETS / "blaze_face_short_range.tflite")
reader = LipReader(ASSETS / "lipread_ctc.int8.onnx", ASSETS / "tokens.json")
mean_face = load_mean_face(ASSETS / "mean_face.npy")


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/read")
def read(request: ReadRequest) -> ReadResponse:
    frames = resample([decode_jpeg(frame) for frame in request.frames], request.fps)[:MAX_FRAMES]
    crops = None
    for rotation in (None, cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_90_COUNTERCLOCKWISE):
        oriented = frames if rotation is None else [cv2.rotate(frame, rotation) for frame in frames]
        try:
            crops = crop_sequence(oriented, detector(oriented), mean_face)
            break
        except NoFaceFound:
            continue
    if crops is None:
        raise HTTPException(status_code=422, detail="No face was found in any frame")
    text = reader.read(crops)
    return ReadResponse(text=text, command=command_for(text))


def decode_jpeg(encoded: str) -> np.ndarray:
    try:
        data = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=400, detail="A frame was not valid base64") from None
    if not data:
        raise HTTPException(status_code=400, detail="A frame was empty")
    image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=400, detail="A frame was not a valid JPEG")
    if max(image.shape[:2]) > MAX_SIDE:
        raise HTTPException(status_code=413, detail=f"Frames must be at most {MAX_SIDE} pixels per side")
    return cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
