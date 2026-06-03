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

from typing import Annotated

from fastapi import APIRouter, Depends, Header

from src.workflows_executor.dto.workflows_executor_dto import (
    EditImageRequest,
    GenerateAudioRequest,
    GenerateImageRequest,
    GenerateTextRequest,
    GenerateVideoRequest,
    VirtualTryOnRequest,
)
from src.workflows_executor.workflows_executor_service import (
    WorkflowsExecutorService,
)

router = APIRouter(
    prefix="/api/workflows-executor",
    tags=["Workflows Executor"],
    responses={404: {"description": "Not found"}},
)

# These endpoints are invoked by GCP Workflow executions, not the browser. When
# the backend is behind Cloud Run IAM, the workflow authenticates as its service
# account via OIDC, which occupies the Authorization header; the end-user token
# is then forwarded in X-Forwarded-Authorization. We read that header first and
# fall back to Authorization (local/unauthenticated deployments). [IAS-3775]


@router.post("/generate_text")
async def generate_text(
    request: GenerateTextRequest,
    x_forwarded_authorization: Annotated[str | None, Header()] = None,
    authorization: Annotated[str | None, Header()] = None,
    service: WorkflowsExecutorService = Depends(),
):
    return await service.generate_text(
        request, x_forwarded_authorization or authorization
    )


@router.post("/generate_image")
async def generate_image(
    request: GenerateImageRequest,
    x_forwarded_authorization: Annotated[str | None, Header()] = None,
    authorization: Annotated[str | None, Header()] = None,
    service: WorkflowsExecutorService = Depends(),
):
    return await service.generate_image(
        request, x_forwarded_authorization or authorization
    )


@router.post("/edit_image")
async def edit_image(
    request: EditImageRequest,
    x_forwarded_authorization: Annotated[str | None, Header()] = None,
    authorization: Annotated[str | None, Header()] = None,
    service: WorkflowsExecutorService = Depends(),
):
    return await service.edit_image(
        request, x_forwarded_authorization or authorization
    )


@router.post("/generate_video")
async def generate_video(
    request: GenerateVideoRequest,
    x_forwarded_authorization: Annotated[str | None, Header()] = None,
    authorization: Annotated[str | None, Header()] = None,
    service: WorkflowsExecutorService = Depends(),
):
    return await service.generate_video(
        request, x_forwarded_authorization or authorization
    )


@router.post("/virtual_try_on")
async def virtual_try_on(
    request: VirtualTryOnRequest,
    x_forwarded_authorization: Annotated[str | None, Header()] = None,
    authorization: Annotated[str | None, Header()] = None,
    service: WorkflowsExecutorService = Depends(),
):
    return await service.virtual_try_on(
        request, x_forwarded_authorization or authorization
    )


@router.post("/generate_audio")
async def generate_audio(
    request: GenerateAudioRequest,
    x_forwarded_authorization: Annotated[str | None, Header()] = None,
    authorization: Annotated[str | None, Header()] = None,
    service: WorkflowsExecutorService = Depends(),
):
    return await service.generate_audio(
        request, x_forwarded_authorization or authorization
    )
