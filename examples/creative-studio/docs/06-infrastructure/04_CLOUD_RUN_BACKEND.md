# Cloud Run Deployment for the Backend

This document outlines the process for deploying the Creative Studio backend to Google Cloud Run, a fully managed compute platform for deploying containerized applications. The deployment process is automated using Google Cloud Build.

## 🚀 Overview

The backend application is containerized using Docker and deployed to Cloud Run. The deployment workflow leverages Google Cloud Build to automate the image building and deployment steps. 

**Key technologies involved:**
- **Docker**: For containerizing the FastAPI application.
- **Google Cloud Build**: For continuous integration and continuous deployment (CI/CD) of the Docker image to Google Artifact Registry and then to Cloud Run.
- **Google Artifact Registry**: Stores the Docker images.
- **Cloud Run**: Hosts the scalable, serverless backend application.

## 🐳 Dockerfile

The `backend/Dockerfile` defines the environment and steps to build the backend application's Docker image. It includes:
- A Python 3.12 base image with `uv` pre-installed for efficient dependency management.
- Installation of Python dependencies from `uv.lock` and `pyproject.toml`.
- Installation of `ffmpeg`, which is required for certain media processing tasks.
- Exposure of port 8080.
- The command to run `gunicorn` with `uvicorn.workers.UvicornWorker` to serve the FastAPI application.

**Location**: `backend/Dockerfile`

```dockerfile
# Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Install the project into `/app`
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Update package lists and install ffmpeg
RUN apt-get update && apt-get install -y ffmpeg

# Reset the entrypoint, don't invoke `uv`
ENTRYPOINT []

# Set default environment variables
ENV ENVIRONMENT="development"
ENV FRONTEND_URL="http://localhost:4200"

EXPOSE 8080

CMD ["gunicorn", "main:app", "--workers=4", "--worker-class=uvicorn.workers.UvicornWorker", "--timeout=36000", "--bind=0.0.0.0:8080"]
```

## ☁️ Cloud Build Configuration

The `backend/cloudbuild.yaml` file defines the steps for Google Cloud Build to: 
1. Build the Docker image for the backend application.
2. Push the Docker image to Google Artifact Registry.
3. Deploy the new image to Google Cloud Run.

**Location**: `backend/cloudbuild.yaml`

```yaml
steps:
  # Step 1: Build the container image using the standard Docker builder.
  # Using SHORT_SHA for the tag is a best practice for traceability.
  - name: 'gcr.io/cloud-builders/docker'
    id: 'Build'
    env: ['DOCKER_BUILDKIT=1']
    args:
      [
        'build',
        '-t',
        '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO_NAME}/${_SERVICE_NAME}:$SHORT_SHA',
        '.',
      ]
    # This ensures the build context is the 'backend' folder
    dir: 'examples/creative-studio/backend'

  # Step 2: Push the container image to Google Artifact Registry.
  - name: 'gcr.io/cloud-builders/docker'
    id: 'Push'
    args:
      [
        'push',
        '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO_NAME}/${_SERVICE_NAME}:$SHORT_SHA',
      ]

  # Step 3: Deploy to Cloud Run using the gcloud CLI builder.
  # This command updates the service with the new image, creating a new revision.
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    id: 'Deploy'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - '${_SERVICE_NAME}'
      - '--image=${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO_NAME}/${_SERVICE_NAME}:$SHORT_SHA'
      - '--region'
      - '${_REGION}'
      - '--quiet' # Suppress interactive prompts for CI/CD environments

# BEST PRACTICE: Explicitly declare the image(s) built by this pipeline.
# This integrates the build with Google Cloud's security features, like showing
# vulnerability scan results in the Cloud Build UI.
images:
  - '${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO_NAME}/${_SERVICE_NAME}:$SHORT_SHA'

# Substitutions will be passed in from the Cloud Build trigger.
# You can override these for manual runs.
substitutions:
  _SERVICE_NAME: 'creative-studio-backend'
  _REPO_NAME: 'cs-be-development-repo' # This matches local.artifact_repo_id
  _REGION: 'us-central1' # TODO: Make Region generic from users input

options:
  logging: CLOUD_LOGGING_ONLY
```

## 🚀 Deployment Process

1.  **Code Commit**: When changes are pushed to the repository, a Cloud Build trigger initiates the process.
2.  **Image Build**: Cloud Build executes the `Build` step, using the `backend/Dockerfile` to create a Docker image of the backend application.
3.  **Image Push**: The `Push` step uploads the newly built Docker image to the specified Google Artifact Registry (`${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO_NAME}/${_SERVICE_NAME}:$SHORT_SHA`).
4.  **Cloud Run Deployment**: The `Deploy` step uses the `gcloud run deploy` command to deploy the image from Artifact Registry to Cloud Run. This creates a new revision of the `creative-studio-backend` service in the specified region (`${_REGION}`).

## 📝 Configuration and Environment Variables

Cloud Run services can be configured with environment variables, which are crucial for database connections, API keys, and other settings. These are typically managed through Cloud Run service settings in the GCP console or via `gcloud` commands during deployment. 

**Example environment variables:**
- `PROJECT_ID`: Your Google Cloud Project ID.
- `GOOGLE_TOKEN_AUDIENCE`: OAuth Client ID for authentication.
- `INSTANCE_CONNECTION_NAME`: Connection string for Cloud SQL (e.g., `project:region:instance-name`).
- `DB_NAME`, `DB_USER`, `DB_PASS`: Database credentials for PostgreSQL.
- `FRONTEND_URL`: The URL of the frontend application for CORS settings.

## 🔗 Connecting to Cloud SQL

The backend application connects to a Cloud SQL PostgreSQL instance. This connection is established securely and efficiently using the Cloud SQL Python Connector, which is configured via environment variables (e.g., `INSTANCE_CONNECTION_NAME`). For more details on Cloud SQL setup, refer to [Cloud SQL Documentation](03_CLOUD_SQL_DATABASE.md).

## 📈 Scaling and Traffic Management

Cloud Run automatically scales the number of container instances up and down based on incoming request traffic. You can configure scaling settings such as:
- **Minimum and Maximum Instances**: To control cost and performance.
- **Concurrency**: The number of requests that can be sent to a single container instance at once.

## ⚠️ Troubleshooting

- **Build Failures**: Check Cloud Build logs for errors during the `Build` or `Push` steps.
- **Deployment Errors**: Review Cloud Run revision logs and `gcloud run deploy` output for issues. Ensure all required environment variables are set.
- **Runtime Errors**: Examine Cloud Run service logs in Cloud Logging for application-specific errors.