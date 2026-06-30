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
