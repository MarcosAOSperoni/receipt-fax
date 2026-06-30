import os
import sys

import pytest
import requests

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


from unittest.mock import MagicMock


def make_session(status=200, json_data=None, content=b""):
    session = MagicMock()
    response = MagicMock()
    response.status_code = status
    response.json.return_value = json_data if json_data is not None else []
    response.content = content
    response.raise_for_status = MagicMock()
    session.get.return_value = response
    session.post.return_value = response
    return session


def test_fetch_pending_returns_messages():
    messages = [{"id": "abc", "body": "hello", "style": {}, "image_path": None}]
    session = make_session(json_data=messages)
    result = client.fetch_pending(session, "https://example.com")
    assert result == messages
    session.get.assert_called_once_with(
        "https://example.com/api/v1/device/messages/pending"
    )


def test_fetch_pending_returns_empty_on_connection_error():
    session = MagicMock()
    session.get.side_effect = requests.exceptions.ConnectionError("no network")
    result = client.fetch_pending(session, "https://example.com")
    assert result == []


def test_fetch_pending_returns_empty_on_http_error():
    session = make_session(status=500)
    session.get.return_value.raise_for_status.side_effect = Exception("server error")
    result = client.fetch_pending(session, "https://example.com")
    assert result == []


def test_download_image_returns_bytes():
    session = make_session(content=b"\x89PNG\r\n")
    result = client.download_image(session, "https://example.com", "2026/06/img.png")
    assert result == b"\x89PNG\r\n"
    session.get.assert_called_once_with(
        "https://example.com/api/v1/media/2026/06/img.png"
    )


def test_download_image_raises_on_error():
    session = MagicMock()
    session.get.side_effect = requests.exceptions.RequestException("fail")
    with pytest.raises(requests.exceptions.RequestException):
        client.download_image(session, "https://example.com", "2026/06/img.png")


def test_ack_message_posts_to_correct_url():
    session = make_session()
    client.ack_message(session, "https://example.com", "msg-123")
    session.post.assert_called_once_with(
        "https://example.com/api/v1/device/messages/msg-123/ack"
    )


def test_fail_message_posts_reason():
    session = make_session()
    client.fail_message(session, "https://example.com", "msg-123", "USB error")
    session.post.assert_called_once_with(
        "https://example.com/api/v1/device/messages/msg-123/fail",
        json={"reason": "USB error"},
    )
