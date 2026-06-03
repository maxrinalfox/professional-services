# Copyright 2026 Google LLC
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
"""Tests for the Workflows Executor controller auth resolution."""

import pytest
from fastapi import HTTPException

from src.workflows_executor.workflows_executor_controller import (
    _resolve_user_token,
)


def test_resolve_user_token_prefers_forwarded():
    """When deployed behind IAM, Authorization holds the OIDC token and the
    user token arrives in X-Forwarded-Authorization, which must win."""
    assert (
        _resolve_user_token("Bearer forwarded", "Bearer oidc")
        == "Bearer forwarded"
    )


def test_resolve_user_token_falls_back_to_authorization():
    """Local/unauthenticated mode: only Authorization is present."""
    assert _resolve_user_token(None, "Bearer original") == "Bearer original"


def test_resolve_user_token_raises_401_when_both_absent():
    """No token at all: fail loud, not unauthenticated loopback calls."""
    with pytest.raises(HTTPException) as exc_info:
        _resolve_user_token(None, None)
    assert exc_info.value.status_code == 401


def test_resolve_user_token_treats_empty_forwarded_as_absent():
    """An empty X-Forwarded-Authorization falls back to Authorization."""
    assert _resolve_user_token("", "Bearer original") == "Bearer original"
