import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User


class TestRegister:
    @pytest.mark.asyncio
    async def test_register_success(self, client: AsyncClient):
        payload = {
            "full_name": "New Advocate",
            "email": "new@test.com",
            "password": "securepass123",
            "bar_number": "BAR99999",
            "phone": "+1234567890",
        }
        resp = await client.post("/api/auth/register", json=payload)
        assert resp.status_code == 201
        data = resp.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_register_duplicate_email(self, client: AsyncClient,
                                             user: User):
        payload = {
            "full_name": "Duplicate",
            "email": user.email,
            "password": "securepass123",
            "bar_number": "BAR88888",
        }
        resp = await client.post("/api/auth/register", json=payload)
        assert resp.status_code == 409
        assert "already registered" in resp.text.lower()

    @pytest.mark.asyncio
    async def test_register_duplicate_bar_number(self, client: AsyncClient,
                                                  user: User):
        payload = {
            "full_name": "Duplicate Bar",
            "email": "dupbar@test.com",
            "password": "securepass123",
            "bar_number": user.bar_number,
        }
        resp = await client.post("/api/auth/register", json=payload)
        assert resp.status_code == 409
        assert "already registered" in resp.text.lower()

    @pytest.mark.asyncio
    async def test_register_short_password(self, client: AsyncClient):
        payload = {
            "full_name": "Weak Password",
            "email": "weak@test.com",
            "password": "short",
            "bar_number": "BAR77777",
        }
        resp = await client.post("/api/auth/register", json=payload)
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_register_invalid_email(self, client: AsyncClient):
        payload = {
            "full_name": "Bad Email",
            "email": "not-an-email",
            "password": "securepass123",
            "bar_number": "BAR66666",
        }
        resp = await client.post("/api/auth/register", json=payload)
        assert resp.status_code == 422


class TestLogin:
    @pytest.mark.asyncio
    async def test_login_success(self, client: AsyncClient, user: User):
        payload = {"email": user.email, "password": "testpassword123"}
        resp = await client.post("/api/auth/login", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_login_wrong_password(self, client: AsyncClient, user: User):
        payload = {"email": user.email, "password": "wrongpassword"}
        resp = await client.post("/api/auth/login", json=payload)
        assert resp.status_code == 401

    @pytest.mark.asyncio
    async def test_login_nonexistent_email(self, client: AsyncClient):
        payload = {"email": "nobody@test.com", "password": "testpassword123"}
        resp = await client.post("/api/auth/login", json=payload)
        assert resp.status_code == 401


class TestLogout:
    @pytest.mark.asyncio
    async def test_logout_success(self, client: AsyncClient, token: str):
        resp = await client.post(
            "/api/auth/logout",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

    @pytest.mark.asyncio
    async def test_logout_without_token(self, client: AsyncClient):
        resp = await client.post("/api/auth/logout")
        assert resp.status_code == 403


class TestProtectedRoutes:
    @pytest.mark.asyncio
    async def test_me_authenticated(self, client: AsyncClient,
                                     auth_headers: dict):
        resp = await client.get("/api/auth/me", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["email"] == "advocate@test.com"
        assert data["full_name"] == "Test Advocate"

    @pytest.mark.asyncio
    async def test_me_unauthenticated(self, client: AsyncClient):
        resp = await client.get("/api/auth/me")
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_me_invalid_token(self, client: AsyncClient):
        resp = await client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer invalidtoken123"},
        )
        assert resp.status_code == 401

    @pytest.mark.asyncio
    async def test_me_revoked_token(self, client: AsyncClient, db_session: AsyncSession,
                                     token: str):
        resp = await client.post(
            "/api/auth/logout",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 204

        resp = await client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 401


class TestUsersEndpoint:
    @pytest.mark.asyncio
    async def test_get_me(self, client_fixture: AsyncClient):
        resp = await client_fixture.get("/api/users/me")
        assert resp.status_code == 200
        assert resp.json()["email"] == "advocate@test.com"

    @pytest.mark.asyncio
    async def test_update_me(self, client_fixture: AsyncClient):
        resp = await client_fixture.put("/api/users/me", json={
            "full_name": "Updated Name",
            "phone": "+9876543210",
        })
        assert resp.status_code == 200
        assert resp.json()["full_name"] == "Updated Name"
