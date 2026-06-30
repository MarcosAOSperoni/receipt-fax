import pytest


async def make_admin(client):
    r = await client.post("/api/v1/auth/register", json={
        "email": "admin@example.com", "display_name": "Admin", "password": "pw"
    })
    return r.json()["access_token"]


async def make_user(client, email):
    r = await client.post("/api/v1/auth/register", json={
        "email": email, "display_name": "User", "password": "pw"
    })
    return r.json()["access_token"]


@pytest.mark.asyncio
async def test_get_config_as_admin(client):
    token = await make_admin(client)
    r = await client.get("/api/v1/admin/config", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.asyncio
async def test_update_config(client):
    token = await make_admin(client)
    r = await client.patch(
        "/api/v1/admin/config",
        json={"key": "registration_enabled", "value": "false"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200
    assert r.json()["value"] == "false"


@pytest.mark.asyncio
async def test_non_admin_cannot_access_admin_endpoints(client):
    await make_admin(client)
    token = await make_user(client, "user@example.com")
    r = await client.get("/api/v1/admin/config", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_list_users(client):
    admin_token = await make_admin(client)
    await make_user(client, "user@example.com")
    r = await client.get("/api/v1/admin/users", headers={"Authorization": f"Bearer {admin_token}"})
    assert r.status_code == 200
    assert len(r.json()) == 2


@pytest.mark.asyncio
async def test_delete_user(client):
    admin_token = await make_admin(client)
    user_token = await make_user(client, "bye@example.com")
    users_r = await client.get("/api/v1/admin/users", headers={"Authorization": f"Bearer {admin_token}"})
    user_id = next(u["id"] for u in users_r.json() if u["email"] == "bye@example.com")

    r = await client.delete(
        f"/api/v1/admin/users/{user_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 204


@pytest.mark.asyncio
async def test_admin_cannot_delete_self(client):
    admin_token = await make_admin(client)
    users_r = await client.get("/api/v1/admin/users", headers={"Authorization": f"Bearer {admin_token}"})
    admin_id = users_r.json()[0]["id"]
    r = await client.delete(
        f"/api/v1/admin/users/{admin_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 400
