import io
import logging

from PIL import Image

log = logging.getLogger(__name__)


def process_image(image_bytes: bytes, width_px: int) -> Image.Image:
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")
    new_height = int(img.height * width_px / img.width)
    img = img.resize((width_px, new_height), Image.LANCZOS)
    img = img.convert("L")
    img = img.convert("1")  # PIL uses Floyd-Steinberg dither by default
    return img


def print_message(msg: dict, image, printer) -> None:
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

    printer.cut()


def open_printer(vendor_id: int = None, product_id: int = None, device: str = None):
    if device:
        from escpos.printer import File
        return File(device)
    from escpos.printer import Usb
    return Usb(vendor_id, product_id)
