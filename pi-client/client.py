import configparser
import logging
import sys
import time

import requests

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


def fetch_pending(session: requests.Session, base_url: str) -> list:
    try:
        r = session.get(f"{base_url}/api/v1/device/messages/pending")
        r.raise_for_status()
        return r.json()
    except Exception as e:
        log.error("Failed to fetch pending messages: %s", e)
        return []


def download_image(session: requests.Session, base_url: str, image_path: str) -> bytes:
    r = session.get(f"{base_url}/api/v1/media/{image_path}")
    r.raise_for_status()
    return r.content


def ack_message(session: requests.Session, base_url: str, message_id: str) -> None:
    try:
        r = session.post(f"{base_url}/api/v1/device/messages/{message_id}/ack")
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
        )
        r.raise_for_status()
    except Exception as e:
        log.error("Failed to mark message %s failed: %s", message_id, e)


if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "config.ini"
    cfg = load_config(config_path)
    log.info("Configuration loaded from %s", config_path)
