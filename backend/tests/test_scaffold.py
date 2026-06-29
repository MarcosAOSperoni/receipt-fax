"""Smoke tests to verify the scaffold is wired up correctly."""
import pytest
from sqlalchemy import text


async def test_db_fixture(reset_db):
    """Verify the test DB connection works (reset_db fixture is autouse)."""
    # If we get here, reset_db ran without error — tables were dropped and recreated
    pass


async def test_client_fixture(client):
    """Verify the ASGI test client fixture works."""
    response = await client.get("/")
    # 404 is expected — no routes are defined yet
    assert response.status_code == 404
