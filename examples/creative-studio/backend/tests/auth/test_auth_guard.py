# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException

from src.auth.auth_guard import RoleChecker, get_current_user
from src.config.config_service import config_service
from src.users.user_model import UserModel, UserRoleEnum


@pytest.fixture(name="mock_user_service")
def fixture_mock_user_service():
    service = AsyncMock()
    # Mock create_user_if_not_exists to return a user
    service.create_user_if_not_exists.return_value = UserModel(
        id=1,
        email="test@example.com",
        roles=["user"],
        name="Test User",
    )
    return service


class TestGetCurrentUser:
    """Tests for get_current_user dependency."""

    @pytest.mark.anyio
    @patch("src.auth.auth_guard.auth.verify_id_token")
    async def test_get_current_user_local_success(
        self, mock_verify, mock_user_service
    ):
        # Setup: Local environment
        config_service.ENVIRONMENT = "local"
        config_service.ALLOWED_ORGS_STR = ""

        # Mock token verification
        mock_verify.return_value = {
            "email": "test@example.com",
            "name": "Test User",
            "picture": "http://example.com/pic.jpg",
            "hd": "example.com",
        }

        user = await get_current_user(
            token="valid_token",
            user_service=mock_user_service,
        )

        assert user.email == "test@example.com"
        assert user.name == "Test User"
        mock_user_service.create_user_if_not_exists.assert_called_once_with(
            email="test@example.com",
            name="Test User",
            picture="http://example.com/pic.jpg",
        )

    @pytest.mark.anyio
    @patch("src.auth.auth_guard.auth.verify_id_token")
    async def test_get_current_user_grants_admin_from_list(
        self, mock_verify, mock_user_service, monkeypatch
    ):
        """A user whose email is in the comma-separated ADMIN_USER_EMAIL list
        is granted (and persisted) the ADMIN role."""
        config_service.ENVIRONMENT = "local"
        config_service.ALLOWED_ORGS_STR = ""
        monkeypatch.setattr(
            config_service,
            "ADMIN_USER_EMAIL",
            "other@fox.com,test@example.com",
        )

        mock_verify.return_value = {
            "email": "test@example.com",
            "name": "Test User",
            "picture": "http://example.com/pic.jpg",
        }

        user = await get_current_user(
            token="valid_token", user_service=mock_user_service
        )

        assert UserRoleEnum.ADMIN in user.roles
        mock_user_service.user_repo.update.assert_awaited()

    @pytest.mark.anyio
    @patch("src.auth.auth_guard.auth.verify_id_token")
    async def test_get_current_user_non_listed_email_not_granted_admin(
        self, mock_verify, mock_user_service, monkeypatch
    ):
        """A user whose email is NOT in ADMIN_USER_EMAIL is never granted the
        ADMIN role (guards against an accidental blanket grant)."""
        config_service.ENVIRONMENT = "local"
        config_service.ALLOWED_ORGS_STR = ""
        monkeypatch.setattr(config_service, "ADMIN_USER_EMAIL", "admin@fox.com")

        mock_verify.return_value = {
            "email": "test@example.com",  # not in the admin list
            "name": "Test User",
            "picture": "http://example.com/pic.jpg",
        }

        user = await get_current_user(
            token="valid_token", user_service=mock_user_service
        )

        assert UserRoleEnum.ADMIN not in user.roles

    @pytest.mark.anyio
    @patch("src.auth.auth_guard.auth.verify_id_token")
    async def test_get_current_user_no_email(
        self, mock_verify, mock_user_service
    ):
        config_service.ENVIRONMENT = "local"
        mock_verify.return_value = {"name": "Test User"}  # Missing email

        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(
                token="valid_token", user_service=mock_user_service
            )

        assert exc_info.value.status_code == 403
        assert "User identity could not be confirmed" in exc_info.value.detail

    @pytest.mark.anyio
    @patch("src.auth.auth_guard.auth.verify_id_token")
    async def test_get_current_user_allowed_orgs_fail(
        self,
        mock_verify,
        mock_user_service,
    ):
        config_service.ENVIRONMENT = "local"
        config_service.ALLOWED_ORGS_STR = "allowed.com"

        mock_verify.return_value = {
            "email": "test@example.com",
            "name": "Test User",
            "hd": "forbidden.com",
        }

        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(
                token="valid_token", user_service=mock_user_service
            )

        assert exc_info.value.status_code == 401
        assert "not part of an allowed organization" in exc_info.value.detail


class TestRoleChecker:
    """Tests for RoleChecker class."""

    def test_role_checker_authorized(self):
        checker = RoleChecker(allowed_roles=[UserRoleEnum.ADMIN])
        user = UserModel(
            id=1,
            email="admin@example.com",
            roles=["admin"],
            name="Admin User",
        )

        # Should not raise exception
        checker(user=user)

    def test_role_checker_forbidden(self):
        checker = RoleChecker(allowed_roles=[UserRoleEnum.ADMIN])
        user = UserModel(
            id=1,
            email="user@example.com",
            roles=["user"],
            name="Regular User",
        )

        with pytest.raises(HTTPException) as exc_info:
            checker(user=user)

        assert exc_info.value.status_code == 403
        assert "do not have sufficient permissions" in exc_info.value.detail


class TestAdminEmails:
    """Tests for multi-admin ADMIN_USER_EMAIL parsing."""

    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("a@fox.com", ["a@fox.com"]),
            ("a@fox.com,b@fox.com", ["a@fox.com", "b@fox.com"]),
            (" a@fox.com , b@fox.com ", ["a@fox.com", "b@fox.com"]),
            ("system", []),
            ("", []),
            ("a@fox.com,system", ["a@fox.com"]),
        ],
    )
    def test_admin_emails_parsing(self, raw, expected, monkeypatch):
        monkeypatch.setattr(config_service, "ADMIN_USER_EMAIL", raw)
        assert config_service.admin_emails == expected
