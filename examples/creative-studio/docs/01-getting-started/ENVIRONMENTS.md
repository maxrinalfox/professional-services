# Environment Variables Configuration Guide

## Overview

This document provides a complete reference for all environment variables used in Creative Studio. Environment variables control application behavior across different environments (local, development, staging, production).

---

## Table of Contents

1. [Backend Environment Variables](#backend-environment-variables)
2. [Frontend Environment Variables](#frontend-environment-variables)
3. [Environment Profiles](#environment-profiles)
4. [Setup Instructions](#setup-instructions)
5. [Variable Reference](#variable-reference)
6. [Secret vs Non-Secret Variables](#secret-vs-non-secret-variables)

---

## Backend Environment Variables

### Location
- **File**: `.env` (root of `backend/` directory)
- **Config Class**: `backend/src/config/config_service.py`
- **Load Method**: Pydantic BaseSettings (reads from `.env` file or environment)

### Required Variables

```bash
# Core Project Settings
PROJECT_ID="your-gcp-project-id"              # GCP Project ID
ENVIRONMENT="development"                       # dev|staging|prod
LOCATION="global"                               # GCP region
FRONTEND_URL="http://localhost:4200"            # Frontend base URL
LOG_LEVEL="INFO"                                # DEBUG|INFO|WARNING|ERROR

# Google Identity Platform
GOOGLE_TOKEN_AUDIENCE="your-client-id"          # OAuth 2.0 Client ID for token validation

# Storage
GENMEDIA_BUCKET="your-project-cs-dev-bucket"    # Cloud Storage bucket name

# Relational Database (Cloud SQL PostgreSQL)
INSTANCE_CONNECTION_NAME="project-id:region:creative-studio-db-xxxx"  # Cloud SQL connection string
DB_NAME="creative_studio"                        # PostgreSQL database name
DB_USER="creative_studio_user"                   # PostgreSQL user
DB_PASS="secure-password"                        # PostgreSQL password (from Secret Manager)
USE_CLOUD_SQL_AUTH_PROXY="false"                 # Use Cloud SQL Auth Proxy (alternative to Python Connector)

# Document Database (Firestore)
FIREBASE_DB="cstudio-development"               # Firestore database name

# AI Models
GEMINI_MODEL_ID="gemini-2.5-pro"               # Gemini model version
GEMINI_AUDIO_ANALYSIS_MODEL_ID="gemini-2.5-pro" # Audio analysis model
IMAGEN_PRODUCT_RECONTEXT="imagen-product-recontext-preview-06-30"
VEO_MODEL_ID="veo-2.0-generate-001"            # Video generation model
VTO_MODEL_ID="virtual-try-on-preview-08-04"    # Virtual try-on model
MODEL_IMAGEN_PRODUCT_RECONTEXT="imagen-product-recontext-preview-06-30"

# Optional Settings
ALLOWED_ORGS_STR=""                             # Comma-separated allowed organizations
INIT_VERTEX="true"                              # Initialize Vertex AI on startup
```

### Optional Variables

```bash
# Lyria (Audio)
LYRIA_PROJECT_ID="your-lyria-project-id"       # Lyria project ID
LYRIA_MODEL_VERSION="lyria-002"                 # Lyria model version

# Email Service
SENDER_EMAIL="no-reply@your-domain.com"         # Email sender address

# Okta (Future)
OKTA_DOMAIN="https://your-org.okta.com"        # Okta domain (if implementing Okta auth)
OKTA_CLIENT_ID="your-okta-client-id"           # Okta application client ID
OKTA_AUTHORIZATION_SERVER="default"             # Okta authorization server
```

### Computed/Derived Values

These are automatically derived from other variables:

```python
# Auto-generated from PROJECT_ID
GENMEDIA_BUCKET = f"{PROJECT_ID}-assets"
VIDEO_BUCKET = f"{GENMEDIA_BUCKET}/videos"
IMAGE_BUCKET = f"{GENMEDIA_BUCKET}/images"

# Auto-generated from ALLOWED_ORGS_STR
ALLOWED_ORGS = set(org.strip() for org in ALLOWED_ORGS_STR.split(",") if org.strip())
```

---

## Frontend Environment Variables

### Location
- **Files**:
  - `frontend/src/environments/environment.ts` (development)
  - `frontend/src/environments/environment.prod.ts` (production)
- **Build-time**: Variables are compiled into the application bundle

### Development Configuration

**File**: `frontend/src/environments/environment.ts`

```typescript
export const environment = {
  // Backend API
  backendURL: 'http://localhost:8080/api',           // Backend API URL

  // Firebase Configuration
  firebase: {
    apiKey: 'YOUR_FIREBASE_API_KEY',                 // Firebase API key
    authDomain: 'your-project.firebaseapp.com',      // Firebase auth domain
    projectId: 'your-gcp-project-id',                // GCP project ID
    storageBucket: 'your-project.appspot.com',       // Storage bucket
    messagingSenderId: '123456789',                  // Firebase messaging ID
    appId: '1:123456789:web:abc123def456',           // Firebase app ID
    measurementId: 'G-XXXXXXXXXXXX',                 // Google Analytics ID
  },

  // Google OAuth
  GOOGLE_CLIENT_ID: 'your-client-id.apps.googleusercontent.com',

  // App Configuration
  production: false,
  isLocal: true,
  ADMIN: 'admin',

  // Regex Patterns
  EMAIL_REGEX: /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/,
};
```

### Production Configuration

**File**: `frontend/src/environments/environment.prod.ts`

```typescript
export const environment = {
  backendURL: 'https://api.your-domain.com/api',    // Production API URL
  firebase: {
    apiKey: 'YOUR_PRODUCTION_FIREBASE_API_KEY',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'your-gcp-project-id',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: '123456789',
    appId: '1:123456789:web:abc123def456',
    measurementId: 'G-YYYYYYYYYYYYY',
  },
  GOOGLE_CLIENT_ID: 'your-prod-client-id.apps.googleusercontent.com',
  production: true,
  isLocal: false,
  ADMIN: 'admin',
  EMAIL_REGEX: /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/,
};
```

---

## Environment Profiles

### Development (Local)

**Backend .env**:
```bash
PROJECT_ID="your-gcp-project"
ENVIRONMENT="local"
FRONTEND_URL="http://localhost:4200"
GOOGLE_TOKEN_AUDIENCE="your-dev-client-id"
GENMEDIA_BUCKET="your-project-dev-bucket"
FIREBASE_DB="cstudio-development"
LOG_LEVEL="DEBUG"
INIT_VERTEX="true"
```

**Frontend environment.ts**:
```typescript
backendURL: 'http://localhost:8080/api'
production: false
isLocal: true
```

### Staging

**Backend .env**:
```bash
PROJECT_ID="your-gcp-project"
ENVIRONMENT="staging"
FRONTEND_URL="https://staging-app.your-domain.com"
GOOGLE_TOKEN_AUDIENCE="your-staging-client-id"
GENMEDIA_BUCKET="your-project-staging-bucket"
FIREBASE_DB="cstudio-staging"
LOG_LEVEL="INFO"
INIT_VERTEX="true"
```

**Frontend environment.prod.ts**:
```typescript
backendURL: 'https://staging-api.your-domain.com/api'
production: false
isLocal: false
```

### Production

**Backend .env** (stored in Cloud Secret Manager):
```bash
PROJECT_ID="your-gcp-project"
ENVIRONMENT="production"
FRONTEND_URL="https://app.your-domain.com"
GOOGLE_TOKEN_AUDIENCE="your-prod-client-id"
GENMEDIA_BUCKET="your-project-prod-bucket"
FIREBASE_DB="cstudio-production"
LOG_LEVEL="WARNING"
INIT_VERTEX="true"
ALLOWED_ORGS_STR="your-domain.com"
```

**Frontend environment.prod.ts**:
```typescript
backendURL: 'https://api.your-domain.com/api'
production: true
isLocal: false
```

---

## Setup Instructions

### Local Development Setup

#### Backend

1. **Clone environment template**:
   ```bash
   cd backend
   cp .env.example .env  # If .env.example exists
   # OR create manually:
   cat > .env << 'EOF'
   PROJECT_ID=your-gcp-project-id
   ENVIRONMENT=local
   FRONTEND_URL=http://localhost:4200
   GOOGLE_TOKEN_AUDIENCE=your-oauth-client-id
   GENMEDIA_BUCKET=your-bucket
   FIREBASE_DB=cstudio-development
   LOG_LEVEL=DEBUG
   INIT_VERTEX=true
   EOF
   ```

2. **Obtain GCP credentials**:
   ```bash
   # Use Application Default Credentials (ADC)
   gcloud auth application-default login

   # OR use service account key
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
   ```

3. **Cloud SQL PostgreSQL Setup**:
   ```bash
   # For local development with Docker Compose PostgreSQL:
   # Add to .env file:
   INSTANCE_CONNECTION_NAME="localhost:5432"  # Local postgres
   DB_NAME=creative_studio
   DB_USER=postgres
   DB_PASS=postgres
   USE_CLOUD_SQL_AUTH_PROXY=false

   # For Cloud SQL in production/staging:
   INSTANCE_CONNECTION_NAME="my-project:us-central1:creative-studio-db-xxxx"
   DB_NAME=creative_studio
   DB_USER=creative_studio_user
   DB_PASS=${DB_PASSWORD_SECRET}  # From Secret Manager
   USE_CLOUD_SQL_AUTH_PROXY=false  # Python Connector is recommended
   ```

   **Initialize database schema**:
   ```bash
   # Apply Alembic migrations (runs automatically on startup)
   alembic upgrade head

   # Or manually create tables:
   psql postgresql://postgres:postgres@localhost/creative_studio < backend/alembic/versions/6591e10bbab7_initial_schema.sql
   ```

4. **Verify configuration**:
   ```bash
   python -c "from src.config.config_service import config_service; print(config_service.PROJECT_ID)"
   ```

#### Frontend

1. **Create environment files**:
   ```bash
   cd frontend/src/environments
   ```

2. **Edit environment.ts** with your Firebase credentials:
   - Get Firebase config from Firebase Console
   - Get Google OAuth Client ID from Google Cloud Console
   - Update backendURL to `http://localhost:8080/api`

3. **Verify configuration**:
   ```bash
   ng serve
   # Check browser console for any configuration warnings
   ```

### Firebase Setup

1. **Create Firebase project**:
   - Visit [Firebase Console](https://console.firebase.google.com)
   - Create new project or select existing
   - Enable Firestore Database (Native Mode)
   - Enable Authentication (Google Sign-In)

2. **Get Firebase configuration**:
   - Go to Project Settings
   - Copy Web app config
   - Add to `frontend/src/environments/environment.ts`

3. **Enable required services**:
   ```bash
   # Authentication
   - Google Sign-In provider enabled

   # Firestore
   - Create database in Native Mode
   - Region: us-central1 (or your choice)

   # Cloud Storage
   - Create bucket for media
   ```

### Google OAuth Setup

1. **Create OAuth 2.0 credentials**:
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Select your project
   - Go to Credentials → Create Credentials → OAuth 2.0 Client ID
   - Type: Web application
   - Authorized JavaScript origins: `http://localhost:4200`, `https://your-domain.com`
   - Authorized redirect URIs: Add your backend callback URLs

2. **Add to environment variables**:
   - Backend: `GOOGLE_TOKEN_AUDIENCE` = Client ID
   - Frontend: `GOOGLE_CLIENT_ID` = Client ID

### GCP Project Setup

1. **Enable required APIs**:
   ```bash
   gcloud services enable \
     firestore.googleapis.com \
     storage.googleapis.com \
     aiplatform.googleapis.com \
     cloudrun.googleapis.com \
     cloudbuild.googleapis.com \
     secretmanager.googleapis.com
   ```

2. **Create service accounts**:
   ```bash
   # Backend runtime service account
   gcloud iam service-accounts create cs-run \
     --display-name="Creative Studio Backend"

   # CI/CD service account
   gcloud iam service-accounts create cs-trig \
     --display-name="Creative Studio CI/CD"
   ```

3. **Grant IAM roles**:
   ```bash
   # Backend service account roles
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member=serviceAccount:cs-run@PROJECT_ID.iam.gserviceaccount.com \
     --role=roles/aiplatform.user

   # (Add other required roles)
   ```

---

## Variable Reference

### Backend Variables Detailed

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `PROJECT_ID` | string | YES | - | GCP project ID |
| `ENVIRONMENT` | string | YES | development | Environment: local, development, staging, production |
| `LOCATION` | string | NO | global | GCP region for resources |
| `FRONTEND_URL` | string | YES | - | Frontend base URL for CORS |
| `LOG_LEVEL` | string | NO | INFO | Logging level: DEBUG, INFO, WARNING, ERROR |
| `GOOGLE_TOKEN_AUDIENCE` | string | YES | - | OAuth 2.0 Client ID for token validation |
| `GENMEDIA_BUCKET` | string | NO | {PROJECT_ID}-assets | Cloud Storage bucket for media |
| `INSTANCE_CONNECTION_NAME` | string | YES | - | Cloud SQL connection string (project:region:instance) |
| `DB_NAME` | string | YES | creative_studio | PostgreSQL database name |
| `DB_USER` | string | YES | creative_studio_user | PostgreSQL user |
| `DB_PASS` | string | YES | - | PostgreSQL password (from Secret Manager) |
| `USE_CLOUD_SQL_AUTH_PROXY` | boolean | NO | false | Use Cloud SQL Auth Proxy instead of Python Connector |
| `FIREBASE_DB` | string | NO | cstudio-development | Firestore database name |
| `GEMINI_MODEL_ID` | string | NO | gemini-2.5-pro | Gemini model version |
| `VEO_MODEL_ID` | string | NO | veo-2.0-generate-001 | Video generation model |
| `IMAGEN_PRODUCT_RECONTEXT` | string | NO | imagen-product-recontext-preview-06-30 | Image recontext model |
| `ALLOWED_ORGS_STR` | string | NO | (empty) | Comma-separated allowed organizations |
| `INIT_VERTEX` | boolean | NO | true | Initialize Vertex AI on startup |

### Frontend Variables Detailed

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `backendURL` | string | YES | Backend API base URL |
| `firebase.apiKey` | string | YES | Firebase API key |
| `firebase.authDomain` | string | YES | Firebase authentication domain |
| `firebase.projectId` | string | YES | GCP project ID |
| `firebase.storageBucket` | string | YES | Cloud Storage bucket |
| `firebase.messagingSenderId` | string | NO | Firebase Cloud Messaging ID |
| `firebase.appId` | string | YES | Firebase app ID |
| `firebase.measurementId` | string | NO | Google Analytics measurement ID |
| `GOOGLE_CLIENT_ID` | string | YES | Google OAuth 2.0 Client ID |
| `production` | boolean | YES | Production mode flag |
| `isLocal` | boolean | YES | Local development flag |

---

## Secret vs Non-Secret Variables

### Non-Secret (Can be in code/config):
- `ENVIRONMENT`
- `LOG_LEVEL`
- `FRONTEND_URL`
- `FIREBASE_DB`
- `GENMEDIA_BUCKET`
- `Model IDs` (Imagen, Veo, Gemini, etc.)

### Secret (Must be in Secret Manager):
- `PROJECT_ID` (avoid hardcoding)
- `GOOGLE_TOKEN_AUDIENCE` (OAuth client ID)
- `DB_PASS` (PostgreSQL password) - **Critical**
- `INSTANCE_CONNECTION_NAME` (can be non-secret but keep in env)
- Firebase API Key
- Firebase Auth Domain (partially sensitive)
- Google OAuth Client ID (partially sensitive)
- Service account keys
- API tokens

### How to Handle Secrets

**Local Development**:
- Use `.env` file (add to `.gitignore`)
- Use `gcloud auth application-default login`

**Production**:
- Store in Google Secret Manager
- Load via environment variables in Cloud Run
- Never commit `.env` files

**Cloud Run**:
```bash
# Set secret as environment variable
gcloud run services update SERVICE_NAME \
  --set-env-vars "VAR_NAME=secret:secret-version" \
  --region REGION
```

---

## Troubleshooting

### Backend Configuration Issues

**Error: "PROJECT_ID could not be determined"**
- Ensure `PROJECT_ID` is set in `.env`
- Or ensure Application Default Credentials are available: `gcloud auth application-default login`

**Error: "GOOGLE_TOKEN_AUDIENCE is required"**
- Set `GOOGLE_TOKEN_AUDIENCE` to your OAuth 2.0 Client ID
- Get from Google Cloud Console → Credentials

**Error: "Firestore database not found"**
- Verify `FIREBASE_DB` value matches actual Firestore database name
- Create database if it doesn't exist

### Frontend Configuration Issues

**Error: "firebase is not defined"**
- Ensure Firebase config is present in environment.ts
- Verify Firebase SDK is imported in main.ts

**Error: "Invalid Firebase configuration"**
- Double-check all Firebase config values
- Ensure they match your actual Firebase project

**Error: "GOOGLE_CLIENT_ID is invalid"**
- Verify Client ID format (should end with .apps.googleusercontent.com)
- Check if Client ID is for Web application type

---

## Verification Checklist

Use this checklist to verify your environment setup:

### Backend
- [ ] `.env` file created in `backend/` directory
- [ ] `PROJECT_ID` is set and valid
- [ ] `GOOGLE_TOKEN_AUDIENCE` is set to OAuth Client ID
- [ ] `GENMEDIA_BUCKET` points to valid GCS bucket
- [ ] GCP credentials available (ADC or service account key)
- [ ] Firestore database exists with correct name
- [ ] `npm install` or `pip install` completed
- [ ] Backend starts without config errors

### Frontend
- [ ] `environment.ts` and `environment.prod.ts` updated
- [ ] Firebase config values copied from Firebase Console
- [ ] `GOOGLE_CLIENT_ID` set correctly
- [ ] `backendURL` points to correct backend
- [ ] `npm install` completed
- [ ] `ng serve` starts without errors

### Integration
- [ ] Frontend can call backend APIs
- [ ] Authentication flows work
- [ ] File uploads/downloads work
- [ ] Firestore reads/writes work

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: All environments (local, staging, production)
- **Related Docs**: INFRASTRUCTURE.md, QUICK_START_GUIDE.md
