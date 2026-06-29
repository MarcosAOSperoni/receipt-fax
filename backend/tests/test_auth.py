import pytest
import pytest_asyncio


@pytest.mark.asyncio
async def test_register_first_user_becomes_admin(client):
    r = await client.post("/api/v1/auth/register", json={
        "email": "admin@example.com",
        "display_name": "Admin",
        "password": "password123",
    })
    assert r.status_code == 201
    data = r.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_register_duplicate_email(client):
    payload = {"email": "a@example.com", "display_name": "A", "password": "pw"}
    await client.post("/api/v1/auth/register", json=payload)
    r = await client.post("/api/v1/auth/register", json=payload)
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_login_success(client):
    await client.post("/api/v1/auth/register", json={
        "email": "user@example.com", "display_name": "U", "password": "secret"
    })
    r = await client.post("/api/v1/auth/login", json={
        "email": "user@example.com", "password": "secret"
    })
    assert r.status_code == 200
    assert "access_token" in r.json()


@pytest.mark.asyncio
async def test_login_wrong_password(client):
    await client.post("/api/v1/auth/register", json={
        "email": "user@example.com", "display_name": "U", "password": "secret"
    })
    r = await client.post("/api/v1/auth/login", json={
        "email": "user@example.com", "password": "wrong"
    })
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_refresh_token(client):
    r = await client.post("/api/v1/auth/register", json={
        "email": "user@example.com", "display_name": "U", "password": "pw"
    })
    refresh_token = r.json()["refresh_token"]
    r2 = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert r2.status_code == 200
    assert "access_token" in r2.json()


@pytest.mark.asyncio
async def test_registration_disabled(client):
    # Register first user (becomes admin)
    r = await client.post("/api/v1/auth/register", json={
        "email": "admin@example.com", "display_name": "Admin", "password": "pw"
    })
    token = r.json()["access_token"]

    # Admin disables registration (requires admin endpoint — will be tested fully in test_admin.py)
    # Directly insert config for this test
    from tests.conftest import TestSession
    from app.models.models import ServerConfig
    async with TestSession() as db:
        db.add(ServerConfig(key="registration_enabled", value="false"))
        await db.commit()

    r2 = await client.post("/api/v1/auth/register", json={
        "email": "new@example.com", "display_name": "New", "password": "pw"
    })
    assert r2.status_code == 403
