#!/bin/sh
set -eu
cd "$(dirname "$0")/../assets"
curl -fsSL -o lipread_ctc.int8.onnx https://huggingface.co/eschmechel/auto-avsr-lrs3-vsr-int8-onnx/resolve/main/lipread_ctc.int8.onnx
curl -fsSL -o tokens.json https://huggingface.co/eschmechel/auto-avsr-lrs3-vsr-int8-onnx/resolve/main/tokens.json
curl -fsSL -o blaze_face_short_range.tflite https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite
curl -fsSL -o mean_face.npy https://raw.githubusercontent.com/mpc001/auto_avsr/main/preparation/detectors/mediapipe/20words_mean_face.npy
echo "da02d72ee472eb3d7d50f7dd309bfe81973acb4cac8bb770dd86aa97872f195b  lipread_ctc.int8.onnx" | shasum -a 256 -c
