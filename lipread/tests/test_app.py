import base64
from pathlib import Path

import cv2
import numpy as np
import pytest

ASSETS = Path(__file__).parent.parent / "assets"
pytestmark = pytest.mark.skipif(
    not (ASSETS / "lipread_ctc.int8.onnx").exists(), reason="model assets are not downloaded"
)


@pytest.fixture(scope="module")
def client():
    from fastapi.testclient import TestClient

    from matilda_lipread.app import app

    return TestClient(app)


def jpeg(width: int, height: int) -> str:
    ok, data = cv2.imencode(".jpg", np.zeros((height, width, 3), np.uint8))
    assert ok
    return base64.b64encode(data.tobytes()).decode()


def post(client, frames):
    return client.post("/read", json={"fps": 25, "frames": frames})


@pytest.mark.parametrize("frame", ["not base64!", "abc", ""])
def test_malformed_base64_is_a_bad_request(client, frame):
    assert post(client, [frame] * 4).status_code == 400


def test_undecodable_jpeg_is_a_bad_request(client):
    garbage = base64.b64encode(b"definitely not a jpeg").decode()
    assert post(client, [garbage] * 4).status_code == 400


def test_oversized_image_is_rejected(client):
    assert post(client, [jpeg(1300, 200)] * 4).status_code == 413


def test_oversized_frame_string_is_rejected(client):
    assert post(client, ["A" * 300_004] * 4).status_code == 422


def test_frame_count_limits_still_apply(client):
    frame = jpeg(32, 32)
    assert post(client, [frame] * 3).status_code == 422
    assert post(client, [frame] * 401).status_code == 422


def test_blank_frames_have_no_face(client):
    assert post(client, [jpeg(64, 64)] * 4).status_code == 422
