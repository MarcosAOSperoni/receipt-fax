import io
import os
import sys

import pytest
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import printer


def make_png_bytes(width=100, height=80, mode="RGB") -> bytes:
    img = Image.new(mode, (width, height), color=128)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_process_image_returns_1bit():
    result = printer.process_image(make_png_bytes(), width_px=200)
    assert result.mode == "1"


def test_process_image_resizes_to_width():
    result = printer.process_image(make_png_bytes(100, 50), width_px=200)
    assert result.width == 200


def test_process_image_preserves_aspect_ratio():
    # 100x50 resized to width 200 → height should be 100
    result = printer.process_image(make_png_bytes(100, 50), width_px=200)
    assert result.height == 100


def test_process_image_handles_rgba():
    result = printer.process_image(make_png_bytes(mode="RGBA"), width_px=200)
    assert result.mode == "1"


def test_process_image_handles_grayscale():
    result = printer.process_image(make_png_bytes(mode="L"), width_px=200)
    assert result.mode == "1"


def test_process_image_handles_jpeg():
    img = Image.new("RGB", (100, 80), color=200)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    result = printer.process_image(buf.getvalue(), width_px=150)
    assert result.mode == "1"
    assert result.width == 150
