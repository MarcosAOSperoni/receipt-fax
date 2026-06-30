import configparser
import logging
import sys
import time

import requests

from printer import open_printer, print_message, process_image

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)


def load_config(path: str) -> configparser.ConfigParser:
    config = configparser.ConfigParser()
    with open(path) as f:
        config.read_file(f)
    return config


_TIMEOUT = (10, 30)  # (connect_seconds, read_seconds)


def fetch_pending(session: requests.Session, base_url: str) -> list:
    try:
        r = session.get(
            f"{base_url}/api/v1/device/messages/pending", timeout=_TIMEOUT
        )
        r.raise_for_status()
        return r.json()
    except Exception as e:
        log.error("Failed to fetch pending messages: %s", e)
        return []


def download_image(session: requests.Session, base_url: str, image_path: str) -> bytes:
    r = session.get(f"{base_url}/api/v1/media/{image_path}", timeout=_TIMEOUT)
    r.raise_for_status()
    return r.content


def ack_message(session: requests.Session, base_url: str, message_id: str) -> None:
    try:
        r = session.post(
            f"{base_url}/api/v1/device/messages/{message_id}/ack", timeout=_TIMEOUT
        )
        r.raise_for_status()
    except Exception as e:
        log.error("Failed to ack message %s: %s", message_id, e)


def fail_message(
    session: requests.Session, base_url: str, message_id: str, reason: str
) -> None:
    try:
        r = session.post(
            f"{base_url}/api/v1/device/messages/{message_id}/fail",
            json={"reason": reason},
            timeout=_TIMEOUT,
        )
        r.raise_for_status()
    except Exception as e:
        log.error("Failed to mark message %s failed: %s", message_id, e)


def process_message(
    msg: dict,
    session: requests.Session,
    base_url: str,
    printer_config,
) -> None:
    message_id = msg["id"]
    try:
        image = None
        if msg.get("image_path"):
            width_px = int(printer_config.get("print_width_px", 576))
            image_bytes = download_image(session, base_url, msg["image_path"])
            image = process_image(image_bytes, width_px)

        vendor = int(printer_config["usb_vendor_id"], 16)
        product = int(printer_config["usb_product_id"], 16)
        p = open_printer(vendor, product)
        print_message(msg, image, p)
        ack_message(session, base_url, message_id)
    except Exception as e:
        log.error("Failed to process message %s: %s", message_id, e)
        fail_message(session, base_url, message_id, str(e))


def poll_loop(config: configparser.ConfigParser) -> None:
    base_url = config["server"]["url"].rstrip("/")
    device_key = config["server"]["device_key"]
    interval = config.getfloat("poll", "interval_seconds")

    session = requests.Session()
    session.headers.update({"X-Device-Key": device_key})

    log.info("Polling %s every %.0fs", base_url, interval)
    while True:
        try:
            messages = fetch_pending(session, base_url)
            for msg in messages:
                process_message(msg, session, base_url, config["printer"])
        except Exception as e:
            log.error("Unexpected poll cycle error: %s", e)
        time.sleep(interval)


if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "config.ini"
    cfg = load_config(config_path)
    log.info("Starting Receipt-Fax client (config: %s)", config_path)
    poll_loop(cfg)
