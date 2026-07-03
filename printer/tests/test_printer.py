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


# --- Bitmap rendering (_render_lines_as_image) ---

def test_render_lines_returns_1bit_image():
    lines = [{"size": "normal", "align": "left", "spans": [{"text": "Hello", "bold": False}]}]
    img = printer._render_lines_as_image(lines, "monospace")
    assert img.mode == "1"


def test_render_lines_width_is_384():
    lines = [{"size": "normal", "align": "left", "spans": [{"text": "Hello", "bold": False}]}]
    img = printer._render_lines_as_image(lines, "monospace")
    assert img.width == 384


def test_render_lines_all_font_families_succeed():
    lines = [{"size": "normal", "align": "left", "spans": [{"text": "Test", "bold": False}]}]
    for family in ("monospace", "serif", "sans", "handwriting"):
        img = printer._render_lines_as_image(lines, family)
        assert isinstance(img, Image.Image), f"Expected Image for family={family}"


def test_render_lines_all_sizes_succeed():
    for size in ("normal", "large", "header"):
        lines = [{"size": size, "align": "left", "spans": [{"text": "Sz", "bold": False}]}]
        img = printer._render_lines_as_image(lines, "monospace")
        assert isinstance(img, Image.Image), f"Expected Image for size={size}"


def test_render_lines_center_align_succeeds():
    lines = [{"size": "normal", "align": "center", "spans": [{"text": "Centered", "bold": False}]}]
    img = printer._render_lines_as_image(lines, "monospace")
    assert img.width == 384


def test_render_lines_bold_span_succeeds():
    lines = [{"size": "normal", "align": "left", "spans": [
        {"text": "Normal ", "bold": False},
        {"text": "Bold", "bold": True},
    ]}]
    img = printer._render_lines_as_image(lines, "monospace")
    assert isinstance(img, Image.Image)


def test_render_lines_multiple_lines_taller_than_one():
    one_line = [{"size": "normal", "align": "left", "spans": [{"text": "A", "bold": False}]}]
    two_lines = [
        {"size": "normal", "align": "left", "spans": [{"text": "A", "bold": False}]},
        {"size": "normal", "align": "left", "spans": [{"text": "B", "bold": False}]},
    ]
    h1 = printer._render_lines_as_image(one_line, "monospace").height
    h2 = printer._render_lines_as_image(two_lines, "monospace").height
    assert h2 > h1


def test_render_lines_empty_span_text_does_not_crash():
    lines = [{"size": "normal", "align": "left", "spans": [{"text": "", "bold": False}]}]
    img = printer._render_lines_as_image(lines, "monospace")
    assert isinstance(img, Image.Image)


# --- print_message with rich_body (bitmap path) ---

def test_print_rich_calls_printer_image():
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)
    assert p.image.call_count == 1
    img_arg = p.image.call_args[0][0]
    assert isinstance(img_arg, Image.Image)
    assert img_arg.width == 384
    assert img_arg.mode == "1"


def test_print_rich_with_photo_calls_image_twice():
    p = MagicMock()
    photo = Image.new("1", (384, 100))
    printer.print_message(make_rich_msg(), photo, p)
    assert p.image.call_count == 2
    # Photo is sent first, text bitmap second
    assert p.image.call_args_list[0][0][0] is photo


def test_print_rich_still_feeds_paper():
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)
    p.text.assert_any_call("\n\n\n\n")


def test_print_rich_does_not_call_set():
    """Text is now bitmap; no ESC/POS set() calls for rich body."""
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)
    p.set.assert_not_called()


def test_print_rich_uses_font_field_from_message():
    p = MagicMock()
    msg = make_rich_msg()
    msg["font"] = "serif"
    printer.print_message(msg, None, p)
    img_arg = p.image.call_args[0][0]
    assert isinstance(img_arg, Image.Image)


def test_print_rich_defaults_to_monospace_when_font_absent():
    p = MagicMock()
    printer.print_message(make_rich_msg(), None, p)  # no "font" key
    p.image.assert_called_once()


def test_print_rich_falls_back_to_legacy_when_no_rich_body():
    """Unchanged: legacy path still uses ESC/POS."""
    p = MagicMock()
    printer.print_message(make_msg("Legacy"), None, p)
    p.set.assert_any_call(bold=False, align="left", double_height=False, double_width=False)
    p.text.assert_any_call("Legacy\n")
