from pathlib import Path

import numpy as np
import pytest

from matilda_lipread.frames import resample
from matilda_lipread.commands import Command, command_for
from matilda_lipread.model import decode_ctc
from matilda_lipread.mouth import CROP, NoFaceFound, crop_sequence, fill_gaps, load_mean_face

TOKENS = ["<blank>", "▁YES", "▁NO", "▁TWO", "<eos>"]


def test_ctc_collapses_repeats_and_drops_blanks():
    assert decode_ctc([0, 1, 1, 0, 0, 4], TOKENS) == "YES"
    assert decode_ctc([2, 0, 2], TOKENS) == "NO NO"


@pytest.mark.parametrize(
    ("transcript", "expected"),
    [
        ("YES", Command.YES),
        ("YEAH", Command.YES),
        ("KNOW", Command.NO),
        ("TOO", Command.TWO),
        ("FREE", Command.THREE),
        ("NO THANKS", Command.NO),
    ],
)
def test_lookalike_words_map_to_commands(transcript, expected):
    assert command_for(transcript) == expected


@pytest.mark.parametrize(
    "transcript",
    ["I WANT TO GO", "IT'S NOT THAT", "I DON'T KNOW WHAT", "OK SO", "I KNOW", "YES YES YES", ""],
)
def test_sentences_are_not_commands(transcript):
    assert command_for(transcript) is None


def test_conflicting_words_are_not_guessed():
    assert command_for("YES NO") is None
    assert command_for("HELLO THERE") is None


def test_missing_frames_are_interpolated():
    a, b = np.zeros((4, 2)), np.full((4, 2), 10.0)
    filled = fill_gaps([None, a, None, b, None])
    assert len(filled) == 5
    assert np.allclose(filled[2], 5.0)
    assert np.allclose(filled[0], a) and np.allclose(filled[4], b)


def test_no_face_anywhere_is_an_error():
    with pytest.raises(NoFaceFound):
        fill_gaps([None, None])


def test_crops_have_the_model_input_shape():
    mean_face = load_mean_face(Path(__file__).parent.parent / "assets" / "mean_face.npy")
    frames = [np.full((480, 360, 3), 128, dtype=np.uint8) for _ in range(6)]
    points = np.array([[140.0, 200.0], [220.0, 200.0], [180.0, 250.0], [180.0, 300.0]])
    crops = crop_sequence(frames, [points] * 6, mean_face)
    assert crops.shape == (6, CROP, CROP)
    assert crops.dtype == np.float32


def test_thirty_fps_is_resampled_to_twenty_five():
    frames = [np.zeros((2, 2, 3))] * 30
    assert len(resample(frames, 30)) == 25
