import pytest
import time
from jose import JWTError
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_api_key,
    hash_api_key,
)


def test_password_hash_and_verify():
    hashed = hash_password("hunter2")
    assert hashed != "hunter2"
    assert verify_password("hunter2", hashed)
    assert not verify_password("wrong", hashed)


def test_access_token_roundtrip():
    token = create_access_token("user-123")
    payload = decode_token(token)
    assert payload["sub"] == "user-123"
    assert payload["type"] == "access"


def test_refresh_token_roundtrip():
    token = create_refresh_token("user-123")
    payload = decode_token(token)
    assert payload["sub"] == "user-123"
    assert payload["type"] == "refresh"


def test_decode_token_rejects_garbage():
    with pytest.raises(JWTError):
        decode_token("not.a.token")


def test_generate_api_key_uniqueness():
    raw1, hash1 = generate_api_key()
    raw2, hash2 = generate_api_key()
    assert raw1 != raw2
    assert hash1 != hash2
    assert raw1.startswith("sk_")


def test_hash_api_key_deterministic():
    raw, stored_hash = generate_api_key()
    assert hash_api_key(raw) == stored_hash
    assert hash_api_key(raw) == stored_hash  # same result twice
