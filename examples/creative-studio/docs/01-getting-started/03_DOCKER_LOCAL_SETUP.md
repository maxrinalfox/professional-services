# Docker Setup & Development Guide

## Overview

This guide covers Docker setup for local development using Docker Compose. Docker provides a consistent development environment that matches production as closely as possible.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Docker Compose Configuration](#docker-compose-configuration)
4. [Building Images](#building-images)
5. [Running Services](#running-services)
6. [Debugging](#debugging)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Docker**: v20.10+
  ```bash
  docker --version
  # Docker version 20.10.0, build 3...
  ```

- **Docker Compose**: v2.0+
  ```bash
  docker compose version
  # Docker Compose version v2.0.0
  ```

### Installation

**macOS** (using Homebrew):
```bash
brew install docker docker-compose
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**Windows**:
- Download [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Install and enable WSL 2 backend

### Verify Installation

```bash
docker --version
docker compose version
docker run hello-world
```

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/your-org/creative-studio.git
cd creative-studio
```

### 2. Create Environment Files

```bash
# Backend environment
cat > backend/.env << 'EOF'
PROJECT_ID=your-gcp-project-id
ENVIRONMENT=local
FRONTEND_URL=http://localhost:4200
GOOGLE_TOKEN_AUDIENCE=your-client-id
GENMEDIA_BUCKET=local-bucket
FIREBASE_DB=cstudio-development
LOG_LEVEL=DEBUG
INIT_VERTEX=false
EOF

# Copy or update frontend environment
# (See ENVIRONMENT_VARIABLES.md for details)
```

### 3. Start Services

```bash
docker compose up
```

This starts:
- **Frontend**: http://localhost:4200
- **Backend**: http://localhost:8080
- **Firestore Emulator**: http://localhost:4000

### 4. Verify Services

```bash
# Frontend
curl http://localhost:4200

# Backend
curl http://localhost:8080/api/docs

# Firestore Emulator
curl http://localhost:4000
```

---

## Docker Compose Configuration

### File Structure

**File**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  # Frontend service
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      target: development  # Use development stage
    ports:
      - "4200:4200"
    volumes:
      - ./frontend/src:/app/src              # Live reload
      - ./frontend/public:/app/public
      - /app/node_modules                    # Don't sync node_modules
    environment:
      - NODE_ENV=development
      - BACKEND_URL=http://backend:8080/api
    depends_on:
      - backend
    command: ng serve --host 0.0.0.0

  # Backend service
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
      target: development  # Use development stage
    ports:
      - "8080:8000"
    volumes:
      - ./backend/src:/app/src               # Live reload
      - /app/.venv                           # Don't sync virtualenv
    environment:
      - PROJECT_ID=local-project
      - ENVIRONMENT=local
      - FRONTEND_URL=http://localhost:4200
      - GOOGLE_TOKEN_AUDIENCE=local-client
      - GENMEDIA_BUCKET=local-bucket
      - FIREBASE_DB=cstudio-development
      - LOG_LEVEL=DEBUG
      - FIRESTORE_EMULATOR_HOST=firestore:8080
    depends_on:
      - firestore
      - firebase-emulator
    command: uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload

  # Firestore Emulator
  firestore:
    image: google/cloud-firestore-emulator:latest
    ports:
      - "4000:4000"
      - "8080:8080"
    environment:
      - FIRESTORE_PROJECT_ID=cstudio-development
    command: gcloud beta emulators firestore start --host-port=0.0.0.0:4000

  # Firebase Emulator Suite
  firebase-emulator:
    image: node:20-alpine
    working_dir: /firebase
    volumes:
      - ./firebase-emulator.json:/firebase/firebase.json
      - ./firebase-seed:/firebase/seed
    ports:
      - "4400:4400"  # Authentication
      - "5000:5000"  # Realtime Database
      - "8085:8085"  # Cloud Storage
    environment:
      - FIRESTORE_EMULATOR_HOST=firestore:4000
    command: npx firebase-tools emulators:start
```

### Environment Variables in Compose

```yaml
environment:
  - VAR_NAME=value
  - ANOTHER_VAR=another_value

# Or reference from .env file
env_file:
  - ./backend/.env
```

---

## Building Images

### Build All Services

```bash
docker compose build
```

### Build Specific Service

```bash
docker compose build frontend
docker compose build backend
```

### Build with Cache Busting

```bash
docker compose build --no-cache
```

### Dockerfile Structure

#### Frontend Dockerfile

**File**: `frontend/Dockerfile`

```dockerfile
# Stage 1: Builder
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source
COPY . .

# Build for production
RUN npm run build

# Stage 2: Development
FROM node:20-alpine AS development

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

EXPOSE 4200

CMD ["ng", "serve", "--host", "0.0.0.0"]

# Stage 3: Production
FROM nginx:alpine AS production

COPY --from=builder /app/dist/creative-studio-frontend /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

#### Backend Dockerfile

**File**: `backend/Dockerfile`

```dockerfile
# Stage 1: Builder
FROM python:3.12-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install Python dependencies
RUN uv pip install --system -r pyproject.toml

# Stage 2: Development
FROM python:3.12-slim AS development

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

COPY pyproject.toml uv.lock ./

# Install all dependencies including dev
RUN uv pip install --system -r pyproject.toml[dev]

COPY . .

EXPOSE 8000

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# Stage 3: Production
FROM python:3.12-slim AS production

WORKDIR /app

# Install system dependencies only
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml uv.lock ./

# Install uv
RUN pip install uv

# Install only production dependencies
RUN uv pip install --system -r pyproject.toml

COPY src/ ./src/

EXPOSE 8000

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Running Services

### Start All Services

```bash
docker compose up
```

### Start Services in Background

```bash
docker compose up -d
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f frontend
docker compose logs -f backend

# Last N lines
docker compose logs --tail=50
```

### Stop Services

```bash
# Stop without removing
docker compose stop

# Stop and remove containers
docker compose down

# Stop, remove, and delete volumes
docker compose down -v
```

### Restart Services

```bash
docker compose restart

# Restart specific service
docker compose restart backend
```

---

## Development Workflow

### Live Reload

Both frontend and backend support live reload:

#### Frontend
- Changes to `src/` are automatically detected
- Browser automatically refreshes
- No rebuild needed

#### Backend
- Changes to `src/` are automatically detected
- Server automatically restarts
- No rebuild needed

### Running Commands in Containers

#### Frontend

```bash
# Install new package
docker compose exec frontend npm install package-name

# Run build
docker compose exec frontend npm run build

# Run tests
docker compose exec frontend npm test
```

#### Backend

```bash
# Install new package
docker compose exec backend uv pip install package-name

# Run migrations
docker compose exec backend alembic upgrade head

# Run tests
docker compose exec backend pytest

# Run shell
docker compose exec backend python
```

### Accessing Container Shell

```bash
# Frontend shell
docker compose exec frontend sh

# Backend shell
docker compose exec backend bash

# As root
docker compose exec -u root frontend sh
```

---

## Debugging

### View Container Status

```bash
docker compose ps
```

### Inspect Container

```bash
docker compose exec backend sh
# Inside container:
env  # View environment variables
ls -la  # List files
```

### View Network

```bash
# List networks
docker network ls

# Inspect network
docker network inspect creative-studio_default
```

### Port Conflicts

```bash
# Find process using port 8080
lsof -i :8080  # macOS/Linux
netstat -ano | findstr :8080  # Windows

# Kill process
kill -9 PID
```

### Database Inspection

```bash
# Access Firestore Emulator UI
# Open browser to http://localhost:4000

# View Firestore data
curl http://localhost:8080/v1/projects/cstudio-development/databases/(default)/documents
```

### Network Communication

Services communicate via internal Docker network:

```
frontend:4200 <-> backend:8000 <-> firestore:8080
                                 <-> firebase-emulator:4400
```

From container perspective:
- `http://backend:8000` (not localhost)
- `http://frontend:4200` (from backend)
- `http://firestore:8080` (from backend)

---

## Troubleshooting

### Issue: "Port already in use"

```bash
# Kill process using port
docker compose down -v
lsof -i :4200  # Find process
kill -9 PID    # Kill it

# Or change port in docker-compose.yml
# ports:
#   - "4201:4200"  # Changed from 4200
```

### Issue: "Cannot connect to backend"

```bash
# Verify backend is running
docker compose logs backend

# Test connectivity from frontend container
docker compose exec frontend curl http://backend:8000/api/docs

# Check network
docker network inspect creative-studio_default
```

### Issue: "Firestore emulator not found"

```bash
# Rebuild services
docker compose build --no-cache

# Restart
docker compose down -v
docker compose up
```

### Issue: "Node modules corrupted"

```bash
# Rebuild frontend
docker compose build --no-cache frontend

# Reinstall
docker compose exec frontend rm -rf node_modules
docker compose exec frontend npm ci
```

### Issue: "High Memory Usage"

```bash
# Check container stats
docker stats

# Reduce memory allocation
# In Docker Desktop: Preferences → Resources → Memory

# Or restart everything
docker compose down -v
docker compose up
```

### Issue: "File Permission Denied"

```bash
# Run as root
docker compose exec -u root backend bash

# Fix permissions
chmod -R 755 /app/src

# Or rebuild
docker compose build --no-cache
```

---

## Production vs Development

### Development Setup

**Dockerfile Stage**: `development`

- Includes dev dependencies
- Hot reload enabled
- Debug logging enabled
- Node modules/venv not optimized

### Production Setup

**Dockerfile Stage**: `production`

- Only runtime dependencies
- No hot reload
- Optimized builds
- Minimal image size

### Build for Production

```bash
# Build production images
docker compose -f docker-compose.yml -f docker-compose.prod.yml build

# Or specify stage
docker build --target production -t creative-studio-backend:latest ./backend
```

---

## Docker Compose Commands Reference

| Command | Description |
|---------|-------------|
| `docker compose up` | Start services |
| `docker compose up -d` | Start in background |
| `docker compose down` | Stop and remove |
| `docker compose ps` | List running services |
| `docker compose logs` | View logs |
| `docker compose exec` | Run command in container |
| `docker compose build` | Build images |
| `docker compose pull` | Pull images |
| `docker compose restart` | Restart services |
| `docker compose pause` | Pause services |
| `docker compose unpause` | Resume services |

---

## Best Practices

1. **Use .dockerignore** - Exclude unnecessary files from image
2. **Layer caching** - Order Dockerfile commands for optimal caching
3. **Health checks** - Add health checks to services
4. **Secrets** - Never commit .env files
5. **Volume mounting** - For development only, not production
6. **Resource limits** - Set memory/CPU limits per service
7. **Logging** - Use structured logging for debugging

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Local development environment
- **Related Docs**: ENVIRONMENT_VARIABLES.md, INFRASTRUCTURE.md
