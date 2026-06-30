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


if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else "config.ini"
    cfg = load_config(config_path)
    log.info("Configuration loaded from %s", config_path)
