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
        "https://example.com/api/v1/device/messages/pending", timeout=(10, 30)
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
        "https://example.com/api/v1/media/2026/06/img.png", timeout=(10, 30)
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
        "https://example.com/api/v1/device/messages/msg-123/ack", timeout=(10, 30)
    )


def test_fail_message_posts_reason():
    session = make_session()
    client.fail_message(session, "https://example.com", "msg-123", "USB error")
    session.post.assert_called_once_with(
        "https://example.com/api/v1/device/messages/msg-123/fail",
        json={"reason": "USB error"},
        timeout=(10, 30),
    )


import configparser
from unittest.mock import patch


def make_config():
    config = configparser.ConfigParser()
    config.read_string(
        "[server]\nurl = https://example.com\ndevice_key = sk_test\n"
        "[printer]\nusb_vendor_id = 0x04b8\nusb_product_id = 0x0e15\n"
        "char_width = 42\nprint_width_px = 576\n"
        "[poll]\ninterval_seconds = 5\n"
    )
    return config


def test_process_message_text_only_acks():
    session = make_session()
    msg = {"id": "m1", "body": "hi", "style": {}, "image_path": None}
    with patch("client.open_printer", return_value=MagicMock()), \
         patch("client.print_message") as mock_print, \
         patch("client.ack_message") as mock_ack:
        client.process_message(msg, session, "https://example.com", make_config()["printer"])
    mock_print.assert_called_once()
    mock_ack.assert_called_once_with(session, "https://example.com", "m1")


def test_process_message_with_image_downloads_and_processes():
    from PIL import Image as PILImage
    session = make_session()
    msg = {"id": "m2", "body": None, "style": {}, "image_path": "2026/06/img.png"}
    fake_img = PILImage.new("1", (576, 400))
    with patch("client.download_image", return_value=b"\x89PNG") as mock_dl, \
         patch("client.process_image", return_value=fake_img) as mock_proc, \
         patch("client.open_printer", return_value=MagicMock()), \
         patch("client.print_message") as mock_print, \
         patch("client.ack_message") as mock_ack:
        client.process_message(msg, session, "https://example.com", make_config()["printer"])
    mock_dl.assert_called_once_with(session, "https://example.com", "2026/06/img.png")
    mock_proc.assert_called_once_with(b"\x89PNG", 576)
    mock_print.assert_called_once()
    mock_ack.assert_called_once_with(session, "https://example.com", "m2")


def test_process_message_calls_fail_on_printer_error():
    session = make_session()
    msg = {"id": "m3", "body": "hi", "style": {}, "image_path": None}
    with patch("client.open_printer", side_effect=Exception("USB error")), \
         patch("client.fail_message") as mock_fail, \
         patch("client.ack_message") as mock_ack:
        client.process_message(msg, session, "https://example.com", make_config()["printer"])
    mock_fail.assert_called_once_with(session, "https://example.com", "m3", "USB error")
    mock_ack.assert_not_called()


def test_poll_loop_processes_messages_and_sleeps():
    messages = [{"id": "m1", "body": "hi", "style": {}, "image_path": None}]
    sleep_calls = []

    def fake_sleep(n):
        sleep_calls.append(n)
        if len(sleep_calls) >= 2:
            raise StopIteration

    with patch("client.fetch_pending", return_value=messages) as mock_fetch, \
         patch("client.process_message") as mock_proc, \
         patch("client.time.sleep", side_effect=fake_sleep):
        with pytest.raises(StopIteration):
            client.poll_loop(make_config())

    assert mock_fetch.call_count == 2
    assert mock_proc.call_count == 2
    assert sleep_calls == [5.0, 5.0]


def test_poll_loop_sleeps_even_when_no_messages():
    sleep_calls = []

    def fake_sleep(n):
        sleep_calls.append(n)
        if len(sleep_calls) >= 1:
            raise StopIteration

    with patch("client.fetch_pending", return_value=[]), \
         patch("client.time.sleep", side_effect=fake_sleep):
        with pytest.raises(StopIteration):
            client.poll_loop(make_config())

    assert sleep_calls == [5.0]
