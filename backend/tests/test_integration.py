import pytest
from PIL import Image


@pytest.mark.asyncio
async def test_full_message_flow(client, tmp_path):
    """Register → create device → send message → Pi polls → Pi ACKs → check history."""

    # Register user (becomes admin)
    reg_r = await client.post("/api/v1/auth/register", json={
        "email": "sender@example.com",
        "display_name": "Sender",
        "password": "password123",
    })
    assert reg_r.status_code == 201
    token = reg_r.json()["access_token"]

    # Create device (simulates iOS app registering the Pi)
    dev_r = await client.post(
        "/api/v1/devices",
        json={"name": "Living Room Printer"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert dev_r.status_code == 201
    device_id = dev_r.json()["id"]
    api_key = dev_r.json()["api_key"]

    # Send a text message
    msg_r = await client.post(
        "/api/v1/messages",
        data={
            "device_id": device_id,
            "body": "Good morning!",
            "style": '{"bold": true, "size": "large", "align": "center"}',
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert msg_r.status_code == 201
    msg_id = msg_r.json()["id"]
    assert msg_r.json()["status"] == "pending"

    # Pi polls for pending messages
    pending_r = await client.get(
        "/api/v1/device/messages/pending",
        headers={"x-device-key": api_key},
    )
    assert pending_r.status_code == 200
    pending = pending_r.json()
    assert len(pending) == 1
    assert pending[0]["id"] == msg_id
    assert pending[0]["body"] == "Good morning!"

    # Pi ACKs after printing
    ack_r = await client.post(
        f"/api/v1/device/messages/{msg_id}/ack",
        headers={"x-device-key": api_key},
    )
    assert ack_r.status_code == 200

    # History shows printed
    history_r = await client.get(
        "/api/v1/messages",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert history_r.json()[0]["status"] == "printed"
    assert history_r.json()[0]["printed_at"] is not None

    # No more pending messages
    pending2_r = await client.get(
        "/api/v1/device/messages/pending",
        headers={"x-device-key": api_key},
    )
    assert pending2_r.json() == []


@pytest.mark.asyncio
async def test_full_image_message_flow(client, tmp_path):
    """Send image message → Pi polls → Pi downloads image → Pi ACKs."""

    reg_r = await client.post("/api/v1/auth/register", json={
        "email": "sender@example.com", "display_name": "Sender", "password": "pw"
    })
    token = reg_r.json()["access_token"]

    dev_r = await client.post(
        "/api/v1/devices",
        json={"name": "Printer"},
        headers={"Authorization": f"Bearer {token}"},
    )
    device_id = dev_r.json()["id"]
    api_key = dev_r.json()["api_key"]

    img_path = tmp_path / "photo.png"
    Image.new("RGB", (50, 50), color=(100, 150, 200)).save(img_path)

    with open(img_path, "rb") as f:
        msg_r = await client.post(
            "/api/v1/messages",
            data={"device_id": device_id, "body": "Photo!", "style": "{}"},
            files={"image": ("photo.png", f, "image/png")},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert msg_r.status_code == 201
    image_path = msg_r.json()["image_path"]
    assert image_path is not None

    # Pi fetches pending
    pending_r = await client.get(
        "/api/v1/device/messages/pending",
        headers={"x-device-key": api_key},
    )
    assert pending_r.json()[0]["image_path"] == image_path

    # Pi downloads the image using its device key
    media_r = await client.get(
        f"/api/v1/media/{image_path}",
        headers={"x-device-key": api_key},
    )
    assert media_r.status_code == 200
    assert media_r.headers["content-type"].startswith("image/")

    # Pi ACKs
    msg_id = msg_r.json()["id"]
    await client.post(
        f"/api/v1/device/messages/{msg_id}/ack",
        headers={"x-device-key": api_key},
    )

    history_r = await client.get(
        "/api/v1/messages",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert history_r.json()[0]["status"] == "printed"


@pytest.mark.asyncio
async def test_admin_disables_registration(client):
    """Admin locks down the server after initial setup."""
    admin_r = await client.post("/api/v1/auth/register", json={
        "email": "admin@example.com", "display_name": "Admin", "password": "pw"
    })
    admin_token = admin_r.json()["access_token"]

    await client.patch(
        "/api/v1/admin/config",
        json={"key": "registration_enabled", "value": "false"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    r = await client.post("/api/v1/auth/register", json={
        "email": "intruder@example.com", "display_name": "Intruder", "password": "pw"
    })
    assert r.status_code == 403
