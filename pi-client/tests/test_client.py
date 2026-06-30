import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import client


def test_load_config_reads_values(tmp_path):
    cfg_file = tmp_path / "config.ini"
    cfg_file.write_text(
        "[server]\n"
        "url = https://example.com\n"
        "device_key = sk_test\n"
        "[printer]\n"
        "usb_vendor_id = 0x04b8\n"
        "usb_product_id = 0x0e15\n"
        "char_width = 42\n"
        "print_width_px = 576\n"
        "[poll]\n"
        "interval_seconds = 5\n"
    )
    config = client.load_config(str(cfg_file))
    assert config["server"]["url"] == "https://example.com"
    assert config["server"]["device_key"] == "sk_test"
    assert config["printer"]["usb_vendor_id"] == "0x04b8"
    assert config.getint("poll", "interval_seconds") == 5


def test_load_config_raises_on_missing_file():
    with pytest.raises(FileNotFoundError):
        client.load_config("/nonexistent/config.ini")
