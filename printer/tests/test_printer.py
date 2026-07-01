import io
import os
import sys

import pytest
from PIL import Image
from unittest.mock import MagicMock, call

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


def make_msg(body="Hello!", bold=False, size="normal", align="left"):
    return {
        "id": "msg-1",
        "body": body,
        "style": {"bold": bold, "size": size, "align": align},
        "image_path": None,
    }


def test_print_message_text_calls_text_and_cut():
    p = MagicMock()
    printer.print_message(make_msg("Hello!"), None, p)
    p.text.assert_called_once_with("Hello!\n")
    p.cut.assert_called_once()


def test_print_message_normal_size():
    p = MagicMock()
    printer.print_message(make_msg(size="normal"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=False, double_width=False)


def test_print_message_large_size():
    p = MagicMock()
    printer.print_message(make_msg(size="large"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=True, double_width=False)


def test_print_message_header_size():
    p = MagicMock()
    printer.print_message(make_msg(size="header"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=True, double_width=True)


def test_print_message_bold():
    p = MagicMock()
    printer.print_message(make_msg(bold=True), None, p)
    p.set.assert_any_call(bold=True, align="left", double_height=False, double_width=False)


def test_print_message_center_align():
    p = MagicMock()
    printer.print_message(make_msg(align="center"), None, p)
    p.set.assert_any_call(bold=False, align="center", double_height=False, double_width=False)


def test_print_message_with_image():
    p = MagicMock()
    img = Image.new("1", (200, 100))
    printer.print_message(make_msg(body=None), img, p)
    p.image.assert_called_once_with(img)
    p.cut.assert_called_once()
    p.text.assert_not_called()


def test_print_message_image_and_text():
    p = MagicMock()
    img = Image.new("1", (200, 100))
    printer.print_message(make_msg("Caption"), img, p)
    p.image.assert_called_once_with(img)
    p.text.assert_called_once_with("Caption\n")


def test_print_message_no_body_no_image_still_cuts():
    p = MagicMock()
    printer.print_message(make_msg(body=None), None, p)
    p.cut.assert_called_once()
    p.text.assert_not_called()
    p.image.assert_not_called()
