import asyncio
import os
import subprocess
import sys
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy import text as sa_text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.database import get_db

BACKEND_DIR = Path(__file__).parent.parent
TEST_DB_URL = "postgresql+asyncpg://receiptfax:receiptfax@localhost:5432/receiptfax_test"
TEST_DATABASE_URL_SYNC = "postgresql://receiptfax:receiptfax@localhost:5432/receiptfax_test"

test_engine = create_async_engine(TEST_DB_URL, echo=False, poolclass=NullPool)
TestSession = async_sessionmaker(test_engine, expire_on_commit=False)


async def override_get_db():
    async with TestSession() as session:
        yield session


def _alembic(cmd: str) -> None:
    env = {**os.environ, "DATABASE_URL": TEST_DATABASE_URL_SYNC}
    result = subprocess.run(
        [sys.executable, "-m", "alembic", *cmd.split()],
        cwd=BACKEND_DIR,
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"alembic {cmd} failed:\n{result.stderr}")


async def _drop_all_tables() -> None:
    """Drop every table and the alembic_version row so we start clean."""
    async with test_engine.begin() as conn:
        await conn.execute(
            sa_text(
                "DROP TABLE IF EXISTS messages, devices, users, server_config, "
                "alembic_version CASCADE"
            )
        )
        await conn.execute(sa_text("DROP TYPE IF EXISTS messagestatus"))


@pytest_asyncio.fixture(autouse=True)
async def reset_db():
    await _drop_all_tables()
    loop = asyncio.get_running_loop()
    await loop.run_in_executor(None, _alembic, "upgrade head")
    yield


@pytest_asyncio.fixture
async def client():
    from app.main import app
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c
    app.dependency_overrides.clear()
