# API Reference

## Overview

This document provides comprehensive reference documentation for all REST API endpoints in Creative Studio. The API is built with FastAPI and follows RESTful conventions.

**Base URL**: `http://localhost:8080/api` (development) or `https://api.your-domain.com/api` (production)

**Authentication**: All endpoints require a valid Firebase ID token in the `Authorization` header:
```
Authorization: Bearer <firebase-id-token>
```

**Auto-Generated Documentation**: OpenAPI (Swagger) documentation is available at:
- Development: `http://localhost:8080/docs`
- Production: `https://api.your-domain.com/docs`

---

## Table of Contents

1. [Common Response Formats](#common-response-formats)
2. [Image Generation](#image-generation-endpoints)
3. [Video Generation](#video-generation-endpoints)
4. [Audio Generation](#audio-generation-endpoints)
5. [Virtual Try-On](#virtual-try-on-endpoints)
6. [Gallery Management](#gallery-management-endpoints)
7. [Gemini Analysis](#gemini-analysis-endpoints)
8. [User Management](#user-management-endpoints)
9. [Source Assets](#source-assets-endpoints)
10. [Brand Guidelines](#brand-guidelines-endpoints)
11. [Media Templates](#media-templates-endpoints)
12. [Workspace Management](#workspace-management-endpoints)
13. [Error Handling](#error-handling)
14. [Rate Limiting](#rate-limiting)
15. [Data Types & Models](#data-types--models)

---

## Common Response Formats

### Success Response

All successful API responses follow this format:

```json
{
  "success": true,
  "data": {
    "id": "resource-id",
    "created_at": "2025-01-15T10:30:00Z",
    "...": "other fields"
  },
  "message": "Operation completed successfully"
}
```

### Error Response

All error responses follow this format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "field_name",
      "issue": "validation error details"
    }
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

### Common HTTP Status Codes

| Status | Meaning | Example |
|--------|---------|---------|
| 200 | OK | Request succeeded |
| 201 | Created | Resource created |
| 204 | No Content | Successful deletion |
| 400 | Bad Request | Invalid input validation error |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | Insufficient permissions for resource |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate resource or state conflict |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Server Error | Unexpected server error |
| 503 | Service Unavailable | AI service temporary unavailable |

---

## Image Generation Endpoints

### Generate Image

**POST** `/api/images`

Generate an image using Imagen 3.0 model with optional brand guidelines application.

**Request Body**:
```json
{
  "prompt": "A beautiful sunset over mountains, photorealistic, 4k quality",
  "style": "photorealistic",
  "size": "1024x1024",
  "guidance_scale": 7.5,
  "negative_prompt": "blurry, low quality, distorted",
  "seed": null,
  "apply_brand_guidelines": false,
  "workspace_id": "optional-workspace-id"
}
```

**Query Parameters**:
- None

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "media-gen-abc123",
    "user_email": "user@example.com",
    "model": "imagen-3-fast",
    "prompt": "A beautiful sunset over mountains, photorealistic, 4k quality",
    "style": "photorealistic",
    "size": "1024x1024",
    "status": "success",
    "gcs_uri": "gs://bucket/media/image-abc123.png",
    "mime_type": "image/png",
    "metadata": {
      "width": 1024,
      "height": 1024,
      "guidance_scale": 7.5,
      "seed": 12345
    },
    "created_at": "2025-01-15T10:30:00Z",
    "completed_at": "2025-01-15T10:31:15Z"
  },
  "message": "Image generated successfully"
}
```

**Error Responses**:
- 400: Invalid prompt length (max 1000 chars) or invalid style
- 401: Invalid authentication token
- 503: Imagen API temporarily unavailable

**Validation Rules**:
- `prompt`: Required, 1-1000 characters
- `style`: Optional, one of: photorealistic, watercolor, oil-painting, sketch, digital-art
- `size`: Optional, one of: 512x512, 768x768, 1024x1024, 1024x576, 576x1024
- `guidance_scale`: Optional, 1.0-20.0 (default: 7.5)
- `seed`: Optional, integer for reproducible results

---

### List Image Requests

**GET** `/api/images`

Retrieve paginated list of image generation requests for current user.

**Query Parameters**:
- `page_size`: Integer, default 20, max 100
- `start_after`: String (document ID) for cursor-based pagination
- `style`: Optional filter by style
- `status`: Optional filter by status (pending, success, failed)

**Response** (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "media-gen-abc123",
      "prompt": "A beautiful sunset...",
      "style": "photorealistic",
      "status": "success",
      "gcs_uri": "gs://bucket/...",
      "created_at": "2025-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "page_size": 20,
    "has_more": true,
    "next_cursor": "media-gen-def456"
  }
}
```

---

### Get Image Details

**GET** `/api/images/{image_id}`

Retrieve detailed information about a specific image generation request.

**Path Parameters**:
- `image_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "media-gen-abc123",
    "user_email": "user@example.com",
    "model": "imagen-3-fast",
    "prompt": "A beautiful sunset over mountains, photorealistic, 4k quality",
    "style": "photorealistic",
    "size": "1024x1024",
    "status": "success",
    "gcs_uri": "gs://bucket/media/image-abc123.png",
    "signed_url": "https://storage.googleapis.com/bucket/...",
    "metadata": {
      "width": 1024,
      "height": 1024,
      "guidance_scale": 7.5,
      "seed": 12345
    },
    "created_at": "2025-01-15T10:30:00Z",
    "completed_at": "2025-01-15T10:31:15Z"
  }
}
```

---

### Delete Image

**DELETE** `/api/images/{image_id}`

Delete an image and its associated metadata.

**Path Parameters**:
- `image_id`: String, required

**Response** (204 No Content):
No response body.

**Error Responses**:
- 403: User doesn't own this image
- 404: Image not found

---

### Upscale Image

**POST** `/api/images/upscale`

Upscale an image to higher resolution using AI upscaling.

**Request Body**:
```json
{
  "image_uri": "gs://bucket/media/image-abc123.png",
  "upscale_factor": 2,
  "model": "real-esrgan"
}
```

**Query Parameters**:
- None

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "media-gen-upscale123",
    "original_image_uri": "gs://bucket/media/image-abc123.png",
    "upscaled_image_uri": "gs://bucket/media/image-upscale-abc123.png",
    "upscale_factor": 2,
    "original_size": {"width": 512, "height": 512},
    "upscaled_size": {"width": 1024, "height": 1024},
    "model": "real-esrgan",
    "status": "success",
    "created_at": "2025-01-15T10:35:00Z",
    "completed_at": "2025-01-15T10:36:30Z"
  },
  "message": "Image upscaled successfully"
}
```

**Error Responses**:
- 400: Invalid upscale_factor (must be 2 or 4) or invalid image URI
- 401: Invalid authentication token
- 503: Upscaling service temporarily unavailable

**Validation Rules**:
- `image_uri`: Required, must be valid GCS URI
- `upscale_factor`: Required, one of: 2, 4
- `model`: Optional, default: real-esrgan

---

### Convert Image Format

**POST** `/api/images/convert`

Convert image to PNG or other supported formats.

**Request Body**:
```json
{
  "image_uri": "gs://bucket/media/image-abc123.jpg",
  "target_format": "png",
  "quality": 95
}
```

**Query Parameters**:
- None

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "media-gen-convert123",
    "original_image_uri": "gs://bucket/media/image-abc123.jpg",
    "converted_image_uri": "gs://bucket/media/image-abc123.png",
    "original_format": "jpg",
    "target_format": "png",
    "quality": 95,
    "original_size": {"width": 1024, "height": 1024, "bytes": 250000},
    "converted_size": {"width": 1024, "height": 1024, "bytes": 180000},
    "status": "success",
    "created_at": "2025-01-15T10:40:00Z",
    "completed_at": "2025-01-15T10:40:15Z"
  },
  "message": "Image converted successfully"
}
```

**Error Responses**:
- 400: Invalid target_format or unsupported conversion
- 401: Invalid authentication token
- 503: Conversion service temporarily unavailable

**Validation Rules**:
- `image_uri`: Required, must be valid GCS URI
- `target_format`: Required, one of: png, jpg, webp, gif
- `quality`: Optional (1-100, default: 95, used for lossy formats)

---

## Video Generation Endpoints

### Generate Video

**POST** `/api/videos`

Generate a video using Veo 2.0 model (async operation).

**Request Body**:
```json
{
  "prompt": "A drone flying over mountains at sunrise, cinematic, smooth motion",
  "duration": 5,
  "style": "cinematic",
  "aspect_ratio": "16:9",
  "fps": 24,
  "seed": null,
  "workspace_id": "optional-workspace-id"
}
```

**Response** (202 Accepted):
```json
{
  "success": true,
  "data": {
    "id": "video-gen-xyz789",
    "user_email": "user@example.com",
    "status": "pending",
    "operation_id": "projects/123/locations/us-central1/operations/abc123",
    "prompt": "A drone flying over mountains at sunrise, cinematic, smooth motion",
    "duration": 5,
    "created_at": "2025-01-15T10:30:00Z"
  },
  "message": "Video generation started. Check status using the returned ID."
}
```

**Validation Rules**:
- `prompt`: Required, 1-2000 characters
- `duration`: Optional, 1-60 seconds (default: 5)
- `aspect_ratio`: Optional, one of: 16:9, 9:16, 1:1 (default: 16:9)
- `fps`: Optional, 24 or 30 (default: 24)

---

### Get Video Status

**GET** `/api/videos/{video_id}`

Retrieve status and details of a video generation request.

**Path Parameters**:
- `video_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "video-gen-xyz789",
    "status": "success",
    "prompt": "A drone flying over mountains at sunrise...",
    "duration": 5,
    "operation_id": "projects/123/locations/us-central1/operations/abc123",
    "gcs_uri": "gs://bucket/media/video-xyz789.mp4",
    "signed_url": "https://storage.googleapis.com/bucket/...",
    "metadata": {
      "width": 1920,
      "height": 1080,
      "duration_seconds": 5,
      "file_size_bytes": 45678901
    },
    "created_at": "2025-01-15T10:30:00Z",
    "completed_at": "2025-01-15T11:15:30Z",
    "progress_percentage": 100
  }
}
```

**Status Values**:
- `pending`: Still processing
- `success`: Completed successfully
- `failed`: Generation failed

---

### List Video Requests

**GET** `/api/videos`

Retrieve paginated list of video generation requests.

**Query Parameters**:
- `page_size`: Integer, default 20
- `start_after`: String (document ID) for pagination
- `status`: Optional filter by status

**Response** (200 OK): Same format as image list endpoint

---

### Concatenate Videos

**POST** `/api/videos/concatenate`

Combine multiple video clips into a single video with optional transitions.

**Request Body**:
```json
{
  "video_uris": [
    "gs://bucket/media/video-1.mp4",
    "gs://bucket/media/video-2.mp4",
    "gs://bucket/media/video-3.mp4"
  ],
  "transition_type": "fade",
  "transition_duration_ms": 500,
  "output_format": "mp4",
  "workspace_id": "optional-workspace-id"
}
```

**Query Parameters**:
- None

**Response** (202 Accepted):
```json
{
  "success": true,
  "data": {
    "id": "video-concat-abc123",
    "status": "pending",
    "input_video_count": 3,
    "transition_type": "fade",
    "transition_duration_ms": 500,
    "output_format": "mp4",
    "created_at": "2025-01-15T10:45:00Z"
  },
  "message": "Video concatenation started"
}
```

**Error Responses**:
- 400: Invalid video URIs or too many videos (max 10)
- 401: Invalid authentication token
- 503: Video concatenation service temporarily unavailable

**Validation Rules**:
- `video_uris`: Required array, 2-10 valid GCS URIs
- `transition_type`: Optional, one of: none, fade, wipe, crossfade (default: fade)
- `transition_duration_ms`: Optional, 100-2000ms (default: 500)
- `output_format`: Optional, one of: mp4, webm, mov (default: mp4)

**Notes**:
- All input videos should have the same resolution and frame rate for best results
- Processing time depends on total video duration and transition complexity
- Check status using the returned ID (see Get Video Status endpoint)

---

## Audio Generation Endpoints

### Generate Audio

**POST** `/api/audios`

Generate audio using Chirp 1.0 model (async operation).

**Request Body**:
```json
{
  "prompt": "A calm piano melody with soft rain sounds in the background",
  "duration": 30,
  "style": "ambient",
  "workspace_id": "optional-workspace-id"
}
```

**Response** (202 Accepted):
```json
{
  "success": true,
  "data": {
    "id": "audio-gen-lmn456",
    "status": "pending",
    "prompt": "A calm piano melody with soft rain sounds...",
    "duration": 30,
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

**Validation Rules**:
- `prompt`: Required, 1-500 characters
- `duration`: Optional, 5-120 seconds (default: 30)
- `style`: Optional, one of: ambient, cinematic, electronic, acoustic

---

### Get Audio Status

**GET** `/api/audios/{audio_id}`

Retrieve status and details of audio generation.

**Path Parameters**:
- `audio_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "audio-gen-lmn456",
    "status": "success",
    "gcs_uri": "gs://bucket/media/audio-lmn456.mp3",
    "signed_url": "https://storage.googleapis.com/bucket/...",
    "metadata": {
      "duration_seconds": 30,
      "sample_rate": 44100,
      "channels": 2,
      "file_size_bytes": 2345678
    },
    "created_at": "2025-01-15T10:30:00Z",
    "completed_at": "2025-01-15T10:35:45Z"
  }
}
```

---

### Transcribe Audio

**POST** `/api/audios/transcribe`

Transcribe audio to text using speech-to-text service.

**Request Body**:
```json
{
  "audio_uri": "gs://bucket/media/audio-lmn456.mp3",
  "language": "en",
  "workspace_id": "optional-workspace-id"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "transcription-abc123",
    "audio_uri": "gs://bucket/media/audio-lmn456.mp3",
    "transcription": "This is the transcribed text from the audio file",
    "language": "en",
    "confidence": 0.95,
    "duration_seconds": 30,
    "word_count": 45,
    "created_at": "2025-01-15T10:40:00Z",
    "completed_at": "2025-01-15T10:42:30Z"
  },
  "message": "Audio transcribed successfully"
}
```

**Error Responses**:
- 400: Invalid audio URI or unsupported format
- 401: Invalid authentication token
- 503: Transcription service temporarily unavailable

**Validation Rules**:
- `audio_uri`: Required, must be valid GCS URI (mp3, wav, m4a, webm formats supported)
- `language`: Optional, language code (en, es, fr, de, etc., default: en)

---

## Virtual Try-On Endpoints

### Get Available Garments

**GET** `/api/vto/garments`

Retrieve catalog of available garments for virtual try-on.

**Query Parameters**:
- `category`: Optional filter (clothing, accessories, footwear, etc.)
- `page_size`: Integer, default 20

**Response** (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "garment-abc123",
      "name": "Blue Silk Blouse",
      "category": "clothing",
      "image_uri": "gs://bucket/...",
      "thumbnail_uri": "gs://bucket/...",
      "metadata": {
        "color": "blue",
        "material": "silk",
        "size_guide": "XS-XXL"
      }
    }
  ],
  "pagination": {
    "total_count": 150,
    "page_size": 20,
    "has_more": true
  }
}
```

---

### Generate Virtual Try-On

**POST** `/api/vto`

Generate a virtual try-on image.

**Request Body**:
```json
{
  "garment_id": "garment-abc123",
  "person_image_uri": "gs://bucket/user-uploads/person.jpg",
  "model_type": "full-body",
  "workspace_id": "optional-workspace-id"
}
```

**Response** (202 Accepted):
```json
{
  "success": true,
  "data": {
    "id": "vto-result-pqr789",
    "status": "pending",
    "garment_id": "garment-abc123",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### Get VTO Result

**GET** `/api/vto/{vto_id}`

Retrieve virtual try-on result.

**Path Parameters**:
- `vto_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "vto-result-pqr789",
    "status": "success",
    "garment_id": "garment-abc123",
    "result_image_uri": "gs://bucket/media/vto-pqr789.jpg",
    "signed_url": "https://storage.googleapis.com/bucket/...",
    "created_at": "2025-01-15T10:30:00Z",
    "completed_at": "2025-01-15T10:32:00Z"
  }
}
```

---

## Gallery Management Endpoints

### List Media (Gallery)

**GET** `/api/galleries`

Retrieve user's generated media library.

**Query Parameters**:
- `page_size`: Integer, default 20, max 100
- `start_after`: String for cursor pagination
- `mime_type`: Optional filter (image/png, video/mp4, audio/mpeg)
- `model`: Optional filter (imagen-3-fast, veo-2, etc.)
- `status`: Optional filter (success, failed, pending)
- `sort_by`: Optional (created_at, updated_at, name)
- `order`: Optional (asc, desc)

**Response** (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "media-abc123",
      "type": "image",
      "mime_type": "image/png",
      "model": "imagen-3-fast",
      "prompt": "A beautiful sunset...",
      "status": "success",
      "gcs_uri": "gs://bucket/...",
      "thumbnail_uri": "gs://bucket/...",
      "created_at": "2025-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "page_size": 20,
    "has_more": true,
    "next_cursor": "media-def456"
  }
}
```

---

### Get Media Details

**GET** `/api/galleries/{media_id}`

Retrieve detailed information about a media item.

**Path Parameters**:
- `media_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "media-abc123",
    "user_email": "user@example.com",
    "workspace_id": "ws-123",
    "type": "image",
    "mime_type": "image/png",
    "model": "imagen-3-fast",
    "prompt": "A beautiful sunset over mountains, photorealistic, 4k quality",
    "status": "success",
    "gcs_uri": "gs://bucket/media/image-abc123.png",
    "signed_url": "https://storage.googleapis.com/bucket/...",
    "signed_url_expires_at": "2025-01-15T11:30:00Z",
    "metadata": {
      "width": 1024,
      "height": 1024,
      "file_size_bytes": 2345678
    },
    "tags": ["sunset", "mountains", "landscape"],
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### Update Media Metadata

**PATCH** `/api/galleries/{media_id}`

Update media tags, name, or other metadata.

**Request Body**:
```json
{
  "tags": ["sunset", "mountains", "new-tag"],
  "name": "My Beautiful Sunset"
}
```

**Response** (200 OK): Updated media object

---

### Delete Media

**DELETE** `/api/galleries/{media_id}`

Delete a media item from gallery and storage.

**Path Parameters**:
- `media_id`: String, required

**Response** (204 No Content)

---

### Get Download URL

**POST** `/api/galleries/{media_id}/download-url`

Generate a time-limited signed URL for downloading media.

**Path Parameters**:
- `media_id`: String, required

**Query Parameters**:
- `expires_in_hours`: Optional, 1-24 (default: 1)

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "signed_url": "https://storage.googleapis.com/bucket/media/...",
    "expires_at": "2025-01-15T11:30:00Z",
    "expires_in_seconds": 3600
  }
}
```

---

## Gemini Analysis Endpoints

### Analyze Image

**POST** `/api/gemini/analyze-image`

Analyze an image using Gemini 2.0 multimodal model.

**Request Body**:
```json
{
  "image_uri": "gs://bucket/media/image-abc123.png",
  "prompt": "Describe this image in detail and suggest improvements",
  "workspace_id": "optional-workspace-id"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "analysis-xyz123",
    "image_uri": "gs://bucket/media/image-abc123.png",
    "analysis": "This is a high-quality landscape photograph showing...",
    "suggestions": [
      "Consider adjusting the color saturation slightly",
      "The composition follows good rule-of-thirds principles"
    ],
    "metadata": {
      "model": "gemini-2.0-pro",
      "tokens_used": 456
    },
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### Analyze Text

**POST** `/api/gemini/analyze-text`

Analyze text using Gemini API.

**Request Body**:
```json
{
  "text": "User-provided text to analyze",
  "prompt": "Summarize the key points",
  "workspace_id": "optional-workspace-id"
}
```

**Response** (200 OK): Similar format to image analysis

---

## User Management Endpoints

### Get Current User Profile

**GET** `/api/users/me`

Retrieve current authenticated user's profile.

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "user-abc123",
    "email": "user@example.com",
    "display_name": "John Doe",
    "avatar_uri": "https://lh3.googleusercontent.com/...",
    "roles": ["viewer", "editor"],
    "workspace_id": "ws-123",
    "created_at": "2025-01-01T10:00:00Z",
    "last_login": "2025-01-15T09:00:00Z"
  }
}
```

---

### Get User by ID

**GET** `/api/users/{user_id}`

Retrieve a specific user's public profile.

**Path Parameters**:
- `user_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "user-abc123",
    "email": "user@example.com",
    "display_name": "John Doe",
    "roles": ["viewer"]
  }
}
```

---

### List Workspace Users

**GET** `/api/users?workspace_id={workspace_id}`

List all users in a workspace (admin only).

**Query Parameters**:
- `workspace_id`: String, required
- `page_size`: Integer, default 20
- `role_filter`: Optional (admin, editor, viewer)

**Response** (200 OK): Paginated list of users

---

### Update User Profile

**PATCH** `/api/users/me`

Update current user's profile information.

**Request Body**:
```json
{
  "display_name": "John Doe Updated",
  "avatar_uri": "https://lh3.googleusercontent.com/..."
}
```

**Response** (200 OK): Updated user profile

---

## Source Assets Endpoints

### Upload Source Asset

**POST** `/api/source-assets/upload-url`

Get a presigned URL for uploading source assets to Cloud Storage.

**Request Body**:
```json
{
  "asset_type": "reference-image",
  "mime_type": "image/jpeg",
  "file_size_bytes": 2345678,
  "workspace_id": "ws-123"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "upload_url": "https://storage.googleapis.com/bucket/...",
    "file_id": "upload-abc123",
    "expires_at": "2025-01-15T11:30:00Z"
  }
}
```

---

### Register Source Asset

**POST** `/api/source-assets`

Register an uploaded file as a source asset after direct upload to Cloud Storage.

**Request Body**:
```json
{
  "gcs_uri": "gs://bucket/uploads/abc123.jpg",
  "asset_type": "reference-image",
  "name": "My Reference Image",
  "workspace_id": "ws-123"
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "data": {
    "id": "asset-xyz789",
    "gcs_uri": "gs://bucket/uploads/abc123.jpg",
    "asset_type": "reference-image",
    "name": "My Reference Image",
    "mime_type": "image/jpeg",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### List Source Assets

**GET** `/api/source-assets`

List source assets in a workspace.

**Query Parameters**:
- `workspace_id`: String, required
- `asset_type`: Optional filter
- `page_size`: Integer, default 20

**Response** (200 OK): Paginated list of assets

---

### Delete Source Asset

**DELETE** `/api/source-assets/{asset_id}`

Delete a source asset.

**Path Parameters**:
- `asset_id`: String, required

**Response** (204 No Content)

---

## Brand Guidelines Endpoints

### Get Upload URL for Brand PDF

**POST** `/api/brand-guidelines/upload-url`

Get presigned URL for uploading brand guidelines PDF.

**Request Body**:
```json
{
  "file_size_bytes": 5678901,
  "workspace_id": "ws-123"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "upload_url": "https://storage.googleapis.com/bucket/...",
    "expires_at": "2025-01-15T11:30:00Z"
  }
}
```

---

### Register Brand Guidelines

**POST** `/api/brand-guidelines`

Register brand guidelines PDF after upload to Cloud Storage.

**Request Body**:
```json
{
  "gcs_uri": "gs://bucket/brand-guidelines/abc123.pdf",
  "workspace_id": "ws-123"
}
```

**Response** (202 Accepted):
```json
{
  "success": true,
  "data": {
    "id": "brand-guide-abc123",
    "gcs_uri": "gs://bucket/brand-guidelines/abc123.pdf",
    "status": "processing",
    "created_at": "2025-01-15T10:30:00Z"
  },
  "message": "Brand guidelines submitted for processing"
}
```

---

### Get Brand Guidelines

**GET** `/api/brand-guidelines`

Retrieve current brand guidelines for workspace.

**Query Parameters**:
- `workspace_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "brand-guide-abc123",
    "gcs_uri": "gs://bucket/brand-guidelines/abc123.pdf",
    "extracted_text": "Color Palette: Primary colors are...",
    "summary": "Brand guidelines covering colors, typography, imagery, and tone",
    "status": "ready",
    "created_at": "2025-01-15T10:30:00Z",
    "processed_at": "2025-01-15T10:35:00Z"
  }
}
```

---

### Delete Brand Guidelines

**DELETE** `/api/brand-guidelines/{guide_id}`

Delete brand guidelines.

**Path Parameters**:
- `guide_id`: String, required

**Response** (204 No Content)

---

## Media Templates Endpoints

### List Templates

**GET** `/api/templates`

List available generation templates (pre-configured prompts).

**Query Parameters**:
- `category`: Optional (fashion, interior, product, social-media)
- `model`: Optional (imagen, veo, gemini)
- `workspace_id`: Optional

**Response** (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "template-abc123",
      "name": "Product Photography",
      "description": "Professional product photography template",
      "category": "product",
      "model": "imagen-3-fast",
      "prompt_template": "A professional product photo of {{product}} on a white background",
      "variables": [
        {
          "name": "product",
          "description": "Product name or description",
          "required": true
        }
      ],
      "created_at": "2025-01-15T10:30:00Z"
    }
  ]
}
```

---

### Create Custom Template

**POST** `/api/templates`

Create a custom template in workspace.

**Request Body**:
```json
{
  "name": "My Custom Template",
  "category": "fashion",
  "model": "imagen-3-fast",
  "prompt_template": "A {{style}} {{item}} in {{color}}, worn by a model",
  "variables": [
    {"name": "style", "required": true},
    {"name": "item", "required": true},
    {"name": "color", "required": false}
  ],
  "workspace_id": "ws-123"
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "data": {
    "id": "template-xyz789",
    "name": "My Custom Template",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### Generate from Template

**POST** `/api/templates/{template_id}/generate`

Generate media using a template with variable substitution.

**Path Parameters**:
- `template_id`: String, required

**Request Body**:
```json
{
  "variables": {
    "style": "elegant",
    "item": "dress",
    "color": "emerald green"
  },
  "workspace_id": "ws-123"
}
```

**Response** (202 Accepted): Image/video generation response

---

## Workspace Management Endpoints

### Create Workspace

**POST** `/api/workspaces`

Create a new workspace.

**Request Body**:
```json
{
  "name": "My Project Workspace",
  "description": "Workspace for my creative project",
  "settings": {
    "brand_color": "#0066cc",
    "theme": "light"
  }
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "data": {
    "id": "ws-abc123",
    "name": "My Project Workspace",
    "owner_id": "user-abc123",
    "members": [
      {
        "user_id": "user-abc123",
        "role": "admin",
        "joined_at": "2025-01-15T10:30:00Z"
      }
    ],
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### Get Workspace

**GET** `/api/workspaces/{workspace_id}`

Retrieve workspace details.

**Path Parameters**:
- `workspace_id`: String, required

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "ws-abc123",
    "name": "My Project Workspace",
    "owner_id": "user-abc123",
    "members": [
      {
        "user_id": "user-abc123",
        "email": "user@example.com",
        "role": "admin",
        "joined_at": "2025-01-15T10:30:00Z"
      }
    ],
    "settings": {
      "brand_color": "#0066cc",
      "theme": "light"
    },
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### List User Workspaces

**GET** `/api/workspaces`

List all workspaces for current user.

**Query Parameters**:
- `page_size`: Integer, default 20
- `role`: Optional filter (admin, editor, viewer)

**Response** (200 OK): Paginated list of workspaces

---

### Update Workspace

**PATCH** `/api/workspaces/{workspace_id}`

Update workspace settings.

**Request Body**:
```json
{
  "name": "Updated Workspace Name",
  "settings": {
    "brand_color": "#ff6600"
  }
}
```

**Response** (200 OK): Updated workspace object

---

### Add Workspace Member

**POST** `/api/workspaces/{workspace_id}/members`

Add a member to workspace.

**Request Body**:
```json
{
  "email": "newmember@example.com",
  "role": "editor"
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "data": {
    "user_id": "user-new123",
    "email": "newmember@example.com",
    "role": "editor",
    "joined_at": "2025-01-15T10:30:00Z"
  }
}
```

---

### Remove Workspace Member

**DELETE** `/api/workspaces/{workspace_id}/members/{user_id}`

Remove a member from workspace.

**Path Parameters**:
- `workspace_id`: String, required
- `user_id`: String, required

**Response** (204 No Content)

---

### Delete Workspace

**DELETE** `/api/workspaces/{workspace_id}`

Delete a workspace (owner only).

**Path Parameters**:
- `workspace_id`: String, required

**Response** (204 No Content)

---

## Error Handling

### Common Error Codes

| Code | HTTP Status | Meaning | Solution |
|------|-------------|---------|----------|
| `AUTHENTICATION_FAILED` | 401 | Invalid or missing token | Refresh authentication token |
| `UNAUTHORIZED` | 403 | Insufficient permissions | Check user role/workspace access |
| `RESOURCE_NOT_FOUND` | 404 | Resource doesn't exist | Verify resource ID |
| `VALIDATION_ERROR` | 400 | Invalid input data | Check request schema |
| `DUPLICATE_RESOURCE` | 409 | Resource already exists | Use different ID/name |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests | Implement exponential backoff retry |
| `SERVICE_UNAVAILABLE` | 503 | AI service down | Retry after delay |
| `INTERNAL_SERVER_ERROR` | 500 | Unexpected error | Contact support |

### Retry Strategy

For transient errors (429, 503), implement exponential backoff:

```typescript
// Frontend example with rxjs
import { retry, timer } from 'rxjs';

this.http.post('/api/images', request).pipe(
  retry({
    count: 3,
    delay: (error, retryCount) => {
      const delayMs = Math.pow(2, retryCount) * 1000;
      return timer(delayMs);
    }
  })
).subscribe(success => {
  // Handle success
}, error => {
  // Handle final failure after retries
});
```

---

## Rate Limiting

### Rate Limit Headers

All responses include rate limit information:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642262400
```

### Rate Limits by Endpoint

| Endpoint Pattern | Limit | Window |
|------------------|-------|--------|
| `/api/images/*` | 10 requests | Per minute |
| `/api/videos/*` | 5 requests | Per minute |
| `/api/audios/*` | 10 requests | Per minute |
| `/api/galleries/*` | 60 requests | Per minute |
| `/api/gemini/*` | 20 requests | Per minute |
| Other endpoints | 100 requests | Per minute |

---

## Data Types & Models

### MediaItem

```json
{
  "id": "media-abc123",
  "user_email": "user@example.com",
  "workspace_id": "ws-123",
  "type": "image",
  "mime_type": "image/png",
  "model": "imagen-3-fast",
  "prompt": "A beautiful sunset",
  "status": "success",
  "gcs_uri": "gs://bucket/media/image-123.png",
  "metadata": {
    "width": 1024,
    "height": 1024
  },
  "created_at": "2025-01-15T10:30:00Z",
  "completed_at": "2025-01-15T10:31:15Z"
}
```

### User

```json
{
  "id": "user-abc123",
  "email": "user@example.com",
  "display_name": "John Doe",
  "avatar_uri": "https://lh3.googleusercontent.com/...",
  "roles": ["viewer", "editor"],
  "workspace_id": "ws-123",
  "created_at": "2025-01-01T10:00:00Z",
  "last_login": "2025-01-15T09:00:00Z"
}
```

### Workspace

```json
{
  "id": "ws-123",
  "name": "My Workspace",
  "owner_id": "user-abc123",
  "members": [
    {
      "user_id": "user-abc123",
      "role": "admin",
      "joined_at": "2025-01-15T10:30:00Z"
    }
  ],
  "created_at": "2025-01-15T10:30:00Z"
}
```

### SourceAsset

```json
{
  "id": "asset-xyz789",
  "workspace_id": "ws-123",
  "user_id": "user-abc123",
  "asset_type": "reference-image",
  "mime_type": "image/jpeg",
  "gcs_uri": "gs://bucket/uploads/file-123.jpg",
  "file_hash": "sha256-abc123...",
  "created_at": "2025-01-15T10:30:00Z"
}
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: All API endpoints
- **Related Docs**: AUTH_IMPLEMENTATION.md, ENVIRONMENT_VARIABLES.md, 02_DATA_FLOW_PATTERNS.md
