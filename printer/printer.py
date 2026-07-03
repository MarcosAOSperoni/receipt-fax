import io
import logging

from PIL import Image, ImageDraw, ImageFont

log = logging.getLogger(__name__)

_FONT_BASE = "/usr/share/fonts/truetype/dejavu"
_FONT_PATHS = {
    "monospace":   (_FONT_BASE + "/DejaVuSansMono.ttf",    _FONT_BASE + "/DejaVuSansMono-Bold.ttf"),
    "serif":       (_FONT_BASE + "/DejaVuSerif.ttf",       _FONT_BASE + "/DejaVuSerif-Bold.ttf"),
    "sans":        (_FONT_BASE + "/DejaVuSans.ttf",        _FONT_BASE + "/DejaVuSans-Bold.ttf"),
    "handwriting": ("/usr/share/fonts/truetype/humor-sans/Humor-Sans.ttf",
                    "/usr/share/fonts/truetype/humor-sans/Humor-Sans.ttf"),
}
_SIZE_PX = {"normal": 24, "large": 32, "header": 42}
PRINTER_WIDTH_PX = 384


def process_image(image_bytes: bytes, width_px: int) -> Image.Image:
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")
    new_height = int(img.height * width_px / img.width)
    img = img.resize((width_px, new_height), Image.LANCZOS)
    img = img.convert("L")
    img = img.convert("1")
    return img


def _load_font(family: str, bold: bool, size_px: int) -> ImageFont.FreeTypeFont:
    regular, bold_path = _FONT_PATHS.get(family, _FONT_PATHS["monospace"])
    path = bold_path if bold else regular
    try:
        return ImageFont.truetype(path, size_px)
    except (OSError, IOError):
        return ImageFont.load_default(size=size_px)


def _render_lines_as_image(lines: list, font_family: str) -> Image.Image:
    # First pass: measure line heights
    line_heights = []
    for line in lines:
        size_px = _SIZE_PX.get(line["size"], 24)
        f = _load_font(font_family, False, size_px)
        bbox = f.getbbox("Ag")
        h = bbox[3] - bbox[1]  # bottom - top (top can be negative for ascenders)
        line_heights.append(h + 4)

    total_height = sum(line_heights) + 8
    img = Image.new("1", (PRINTER_WIDTH_PX, total_height), 1)
    draw = ImageDraw.Draw(img)

    y = 4
    for line, lh in zip(lines, line_heights):
        size_px = _SIZE_PX.get(line["size"], 24)
        align = line.get("align", "left")

        # Measure total line width for center alignment
        total_w = 0
        span_fonts = []
        for span in line["spans"]:
            f = _load_font(font_family, span["bold"], size_px)
            span_fonts.append(f)
            if span["text"]:
                total_w += int(f.getlength(span["text"]))

        x = (PRINTER_WIDTH_PX - total_w) // 2 if align == "center" else 0

        for span, f in zip(line["spans"], span_fonts):
            if span["text"]:
                draw.text((x, y), span["text"], font=f, fill=0)
                x += int(f.getlength(span["text"]))

        y += lh

    return img


def print_message(msg: dict, image, printer) -> None:
    rich_body = msg.get("rich_body")
    if rich_body:
        _print_rich(rich_body, image, printer, font=msg.get("font") or "monospace")
    else:
        _print_legacy(msg, image, printer)
    printer.text("\n\n\n\n")


def _print_legacy(msg: dict, image, printer) -> None:
    style = msg.get("style") or {}
    size = style.get("size", "normal")

    printer.set(
        bold=bool(style.get("bold", False)),
        align=style.get("align", "left"),
        double_height=size in ("large", "header"),
        double_width=size == "header",
    )

    if image is not None:
        printer.image(image)

    if msg.get("body"):
        printer.text(msg["body"] + "\n")


def _print_rich(lines: list, image, printer, font: str = "monospace") -> None:
    if image is not None:
        printer.set(align="left")
        printer.image(image)
    text_img = _render_lines_as_image(lines, font)
    printer.image(text_img)


def open_printer(vendor_id: int = None, product_id: int = None, device: str = None):
    if device:
        from escpos.printer import File
        return File(device)
    from escpos.printer import Usb
    return Usb(vendor_id, product_id)
