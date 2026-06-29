import pytest


async def register_and_login(client, email="user@example.com"):
    r = await client.post("/api/v1/auth/register", json={
        "email": email, "display_name": "User", "password": "pw"
    })
    return r.json()["access_token"]


@pytest.mark.asyncio
async def test_create_device(client):
    token = await register_and_login(client)
    r = await client.post(
        "/api/v1/devices",
        json={"name": "Living Room"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Living Room"
    assert "api_key" in data
    assert data["api_key"].startswith("sk_")


@pytest.mark.asyncio
async def test_list_devices(client):
    token = await register_and_login(client)
    await client.post(
        "/api/v1/devices",
        json={"name": "Printer 1"},
        headers={"Authorization": f"Bearer {token}"},
    )
    r = await client.get("/api/v1/devices", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert "api_key" not in r.json()[0]  # key not exposed in list


@pytest.mark.asyncio
async def test_delete_device(client):
    token = await register_and_login(client)
    create_r = await client.post(
        "/api/v1/devices",
        json={"name": "Printer"},
        headers={"Authorization": f"Bearer {token}"},
    )
    device_id = create_r.json()["id"]
    r = await client.delete(
        f"/api/v1/devices/{device_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 204


@pytest.mark.asyncio
async def test_delete_other_users_device_returns_404(client):
    token1 = await register_and_login(client, "user1@example.com")
    token2 = await register_and_login(client, "user2@example.com")
    create_r = await client.post(
        "/api/v1/devices",
        json={"name": "Printer"},
        headers={"Authorization": f"Bearer {token1}"},
    )
    device_id = create_r.json()["id"]
    r = await client.delete(
        f"/api/v1/devices/{device_id}",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_unauthenticated_device_list_rejected(client):
    r = await client.get("/api/v1/devices")
    assert r.status_code == 403  # HTTPBearer returns 403 when no credentials provided
