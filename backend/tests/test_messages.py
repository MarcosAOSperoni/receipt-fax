import io
import pytest


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
    device_id = dr.json()["id"]
    api_key = dr.json()["api_key"]
    return token, device_id, api_key


@pytest.mark.asyncio
async def test_send_text_message(client):
    token, device_id, _ = await setup_user_and_device(client)
    r = await client.post(
        "/api/v1/messages",
        data={"device_id": device_id, "body": "Hello!", "style": "{}"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 201
    data = r.json()
    assert data["body"] == "Hello!"
    assert data["status"] == "pending"
    assert data["image_path"] is None


@pytest.mark.asyncio
async def test_send_message_requires_body_or_image(client):
    token, device_id, _ = await setup_user_and_device(client)
    r = await client.post(
        "/api/v1/messages",
        data={"device_id": device_id, "style": "{}"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_send_message_with_image(client, tmp_path):
    token, device_id, _ = await setup_user_and_device(client)
    # Create a minimal valid PNG (1x1 white pixel)
    from PIL import Image
    img_path = tmp_path / "test.png"
    Image.new("RGB", (1, 1), color=(255, 255, 255)).save(img_path)

    with open(img_path, "rb") as f:
        r = await client.post(
            "/api/v1/messages",
            data={"device_id": device_id, "body": "With image", "style": "{}"},
            files={"image": ("test.png", f, "image/png")},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert r.status_code == 201
    assert r.json()["image_path"] is not None


@pytest.mark.asyncio
async def test_list_messages(client):
    token, device_id, _ = await setup_user_and_device(client)
    await client.post(
        "/api/v1/messages",
        data={"device_id": device_id, "body": "Msg 1", "style": "{}"},
        headers={"Authorization": f"Bearer {token}"},
    )
    await client.post(
        "/api/v1/messages",
        data={"device_id": device_id, "body": "Msg 2", "style": "{}"},
        headers={"Authorization": f"Bearer {token}"},
    )
    r = await client.get("/api/v1/messages", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert len(r.json()) == 2


@pytest.mark.asyncio
async def test_delete_message(client):
    token, device_id, _ = await setup_user_and_device(client)
    r = await client.post(
        "/api/v1/messages",
        data={"device_id": device_id, "body": "Delete me", "style": "{}"},
        headers={"Authorization": f"Bearer {token}"},
    )
    msg_id = r.json()["id"]
    del_r = await client.delete(
        f"/api/v1/messages/{msg_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert del_r.status_code == 204


@pytest.mark.asyncio
async def test_cannot_send_to_another_users_device(client):
    token1, device_id, _ = await setup_user_and_device(client, "user1@example.com")
    token2, _, _ = await setup_user_and_device(client, "user2@example.com")
    r = await client.post(
        "/api/v1/messages",
        data={"device_id": device_id, "body": "Sneaky", "style": "{}"},
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert r.status_code == 404
