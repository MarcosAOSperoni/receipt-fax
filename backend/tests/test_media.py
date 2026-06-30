import pytest
from pathlib import Path
from PIL import Image


async def setup_user_and_device(client, email="user@example.com"):
    r = await client.post("/api/v1/auth/register", json={
        "email": email, "display_name": "User", "password": "pw"
    })
    token = r.json()["access_token"]
    dr = await client.post(
        "/api/v1/devices",
        json={"name": "Printer"},
        headers={"Authorization": f"Bearer {token}"},
    )
    return token, dr.json()["id"], dr.json()["api_key"]


async def upload_image(client, token, device_id, tmp_path):
    img_path = tmp_path / "img.png"
    Image.new("RGB", (10, 10)).save(img_path)
    with open(img_path, "rb") as f:
        r = await client.post(
            "/api/v1/messages",
            data={"device_id": device_id, "body": "hi", "style": "{}"},
            files={"image": ("img.png", f, "image/png")},
            headers={"Authorization": f"Bearer {token}"},
        )
    return r.json()["image_path"]


@pytest.mark.asyncio
async def test_serve_image_with_jwt(client, tmp_path):
    token, device_id, _ = await setup_user_and_device(client)
    image_path = await upload_image(client, token, device_id, tmp_path)
    r = await client.get(
        f"/api/v1/media/{image_path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("image/")


@pytest.mark.asyncio
async def test_serve_image_with_device_key(client, tmp_path):
    token, device_id, api_key = await setup_user_and_device(client)
    image_path = await upload_image(client, token, device_id, tmp_path)
    r = await client.get(
        f"/api/v1/media/{image_path}",
        headers={"x-device-key": api_key},
    )
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_unauthenticated_media_rejected(client, tmp_path):
    token, device_id, _ = await setup_user_and_device(client)
    image_path = await upload_image(client, token, device_id, tmp_path)
    r = await client.get(f"/api/v1/media/{image_path}")
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_path_traversal_rejected(client):
    token, _, _ = await setup_user_and_device(client)
    r = await client.get(
        "/api/v1/media/../etc/passwd",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code in (400, 403, 404)
