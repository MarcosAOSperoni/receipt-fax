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


# --- Legacy (no rich_body) ---

def make_msg(body="Hello!", bold=False, size="normal", align="left"):
    return {
        "id": "msg-1",
        "body": body,
        "style": {"bold": bold, "size": size, "align": align},
        "image_path": None,
    }


def test_print_legacy_text_calls_text():
    p = MagicMock()
    printer.print_message(make_msg("Hello!"), None, p)
    p.text.assert_any_call("Hello!\n")
    p.text.assert_any_call("\n\n\n\n")
    p.cut.assert_not_called()


def test_print_legacy_normal_size():
    p = MagicMock()
    printer.print_message(make_msg(size="normal"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=False, double_width=False)


def test_print_legacy_large_size():
    p = MagicMock()
    printer.print_message(make_msg(size="large"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=True, double_width=False)


def test_print_legacy_header_size():
    p = MagicMock()
    printer.print_message(make_msg(size="header"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=True, double_width=True)


def test_print_legacy_bold():
    p = MagicMock()
    printer.print_message(make_msg(bold=True), None, p)
    p.set.assert_any_call(bold=True, align="left", double_height=False, double_width=False)


def test_print_legacy_center_align():
    p = MagicMock()
    printer.print_message(make_msg(align="center"), None, p)
    p.set.assert_any_call(bold=False, align="center", double_height=False, double_width=False)


def test_print_legacy_with_image():
    p = MagicMock()
    img = Image.new("1", (200, 100))
    printer.print_message(make_msg(body=None), img, p)
    p.image.assert_called_once_with(img)
    p.cut.assert_not_called()
    p.text.assert_any_call("\n\n\n\n")


def test_print_legacy_image_and_text():
    p = MagicMock()
    img = Image.new("1", (200, 100))
    printer.print_message(make_msg("Caption"), img, p)
    p.image.assert_called_once_with(img)
    p.text.assert_any_call("Caption\n")


def test_print_legacy_no_body_no_image_still_feeds():
    p = MagicMock()
    printer.print_message(make_msg(body=None), None, p)
    p.cut.assert_not_called()
    p.text.assert_any_call("\n\n\n\n")
    p.image.assert_not_called()


# --- Rich body ---

def make_rich_msg(lines=None):
    if lines is None:
        lines = [{
            "size": "normal", "align": "left",
            "spans": [{"text": "Hello ", "bold": False}, {"text": "world", "bold": True}]
        }]
    return {"id": "msg-1", "body": "Hello world", "style": {}, "image_path": None, "rich_body": lines}


def test_print_rich_sets_line_style():
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)
    p.set.assert_any_call(align="left", double_height=False, double_width=False, bold=False)


def test_print_rich_sets_bold_per_span():
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)
    p.set.assert_any_call(bold=False)
    p.set.assert_any_call(bold=True)


def test_print_rich_text_per_span():
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)
    p.text.assert_any_call("Hello ")
    p.text.assert_any_call("world")
    p.text.assert_any_call("\n")
    p.text.assert_any_call("\n\n\n\n")


def test_print_rich_large_line():
    p = MagicMock()
    lines = [{"size": "large", "align": "center", "spans": [{"text": "Big", "bold": False}]}]
    printer.print_message(make_rich_msg(lines), None, p)
    p.set.assert_any_call(align="center", double_height=True, double_width=False, bold=False)


def test_print_rich_header_line():
    p = MagicMock()
    lines = [{"size": "header", "align": "center", "spans": [{"text": "Head", "bold": False}]}]
    printer.print_message(make_rich_msg(lines), None, p)
    p.set.assert_any_call(align="center", double_height=True, double_width=True, bold=False)


def test_print_rich_with_image():
    p = MagicMock()
    img = Image.new("1", (200, 100))
    printer.print_message(make_rich_msg(), img, p)
    p.image.assert_called_once_with(img)


def test_print_rich_skips_empty_spans():
    p = MagicMock()
    lines = [{"size": "normal", "align": "left", "spans": [{"text": "", "bold": False}]}]
    printer.print_message(make_rich_msg(lines), None, p)
    # text("\n") for line end and text("\n\n\n\n") for feed, but no span text
    text_calls = [str(c) for c in p.text.call_args_list]
    assert not any("" == c for c in p.text.call_args_list if c.args == ("",))


def test_print_rich_multiple_lines():
    p = MagicMock()
    lines = [
        {"size": "normal", "align": "left", "spans": [{"text": "Line 1", "bold": False}]},
        {"size": "large", "align": "center", "spans": [{"text": "Line 2", "bold": True}]},
    ]
    printer.print_message(make_rich_msg(lines), None, p)
    p.text.assert_any_call("Line 1")
    p.text.assert_any_call("Line 2")
    # Two line-end \n calls
    newline_calls = [c for c in p.text.call_args_list if c.args == ("\n",)]
    assert len(newline_calls) == 2


def test_print_rich_falls_back_to_legacy_when_no_rich_body():
    p = MagicMock()
    printer.print_message(make_msg("Legacy"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=False, double_width=False)
    p.text.assert_any_call("Legacy\n")
