# Video Processing & FFmpeg Integration Guide

## Overview

Creative Studio uses FFmpeg for video processing tasks and Veo 2.0 for AI-powered video generation. This guide covers video processing pipeline, format handling, and optimization.

**Key Technologies**:
- **Veo 2.0**: Google's video generation model
- **FFmpeg**: Video processing and transcoding
- **mediapy**: Python bindings for media operations
- **Vertex AI**: Video operation orchestration

---

## Table of Contents

1. [Video Processing Pipeline](#video-processing-pipeline)
2. [FFmpeg Setup](#ffmpeg-setup)
3. [Format Support](#format-support)
4. [Video Generation](#video-generation)
5. [Transcoding & Processing](#transcoding--processing)
6. [Quality Settings](#quality-settings)
7. [Performance Optimization](#performance-optimization)
8. [Troubleshooting](#troubleshooting)

---

## Video Processing Pipeline

### Generation Pipeline

```
User Request
    ↓
Validate Parameters
    ↓
Create Firestore Document (status=pending)
    ↓
Call Veo API (async)
    ↓
Store Operation ID
    ↓
Return Request ID (202 Accepted)
    ↓
Frontend Polls Status
    ↓
Video Generation Complete
    ↓
Download from Veo
    ↓
Process with FFmpeg (optional transcode)
    ↓
Upload to GenMedia Bucket
    ↓
Update Firestore (status=success)
    ↓
Frontend Displays Video
```

### Processing Pipeline

```
Uploaded Video
    ↓
Validate Format
    ↓
Extract Metadata
    ↓
Determine Processing Needed
    ├─ If already optimal → Store as-is
    └─ If needs optimization → Transcode
        ↓
    FFmpeg Processing
        ├─ Re-encode video codec
        ├─ Adjust bitrate
        ├─ Re-encode audio
        └─ Optimize for web
        ↓
    Store in Cloud Storage
    ↓
    Create Thumbnail
    ↓
    Update Media Library
```

---

## FFmpeg Setup

### Installation

**Docker** (automatically included):

```dockerfile
# backend/Dockerfile
FROM python:3.12-slim

# Install FFmpeg
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*
```

**Local Development**:

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt-get install ffmpeg

# Windows
choco install ffmpeg
```

### Version Check

```bash
ffmpeg -version
# Should show version 4.2+

ffprobe -version
# Used for metadata extraction
```

### Python Integration

**File**: `backend/src/common/video_processor.py`

```python
import subprocess
import json
import logging
from pathlib import Path
from typing import Dict, List

logger = logging.getLogger(__name__)

class VideoProcessor:
    """FFmpeg-based video processing"""

    def __init__(self):
        self.ffmpeg_path = 'ffmpeg'
        self.ffprobe_path = 'ffprobe'

    async def get_video_info(self, video_path: str) -> Dict:
        """
        Extract video metadata using ffprobe

        Args:
            video_path: Path to video file

        Returns:
            {
                'duration': 120.5,
                'width': 1920,
                'height': 1080,
                'fps': 30,
                'bitrate': 5000,
                'codec': 'h264',
                'file_size': 1234567,
            }
        """
        try:
            cmd = [
                self.ffprobe_path,
                '-v', 'error',
                '-select_streams', 'v:0',
                '-show_entries', 'stream=width,height,duration,r_frame_rate,bit_rate,codec_name',
                '-of', 'json',
                video_path,
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)
            data = json.loads(result.stdout)

            stream = data['streams'][0]

            return {
                'duration': float(stream.get('duration', 0)),
                'width': int(stream.get('width', 0)),
                'height': int(stream.get('height', 0)),
                'fps': self._parse_fps(stream.get('r_frame_rate', '30/1')),
                'bitrate': int(stream.get('bit_rate', 0)) // 1000,  # Convert to kbps
                'codec': stream.get('codec_name', 'unknown'),
            }

        except Exception as e:
            logger.error(f'Failed to get video info: {e}')
            raise

    def _parse_fps(self, fps_string: str) -> float:
        """Parse FPS from format like '30/1' or '24000/1001'"""
        if '/' in fps_string:
            num, den = fps_string.split('/')
            return float(num) / float(den)
        return float(fps_string)

    async def transcode(
        self,
        input_path: str,
        output_path: str,
        settings: Dict = None,
    ) -> None:
        """
        Transcode video using FFmpeg

        Args:
            input_path: Input video path
            output_path: Output video path
            settings: Encoding settings

        Settings example:
        {
            'codec': 'h264',
            'preset': 'medium',  # ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
            'bitrate': '5000k',
            'width': 1920,
            'height': 1080,
            'fps': 30,
            'audio_codec': 'aac',
            'audio_bitrate': '128k',
        }
        """
        settings = settings or {}

        # Build FFmpeg command
        cmd = [self.ffmpeg_path, '-i', input_path]

        # Video codec
        codec = settings.get('codec', 'h264')
        cmd.extend(['-c:v', codec])

        # Preset (speed vs quality)
        preset = settings.get('preset', 'medium')
        if codec == 'h264':
            cmd.extend(['-preset', preset])
        elif codec == 'hevc':
            cmd.extend(['-preset', preset])

        # Bitrate
        if settings.get('bitrate'):
            cmd.extend(['-b:v', settings['bitrate']])

        # Resolution
        if settings.get('width') and settings.get('height'):
            scale = f"{settings['width']}:{settings['height']}"
            cmd.extend(['-vf', f'scale={scale}'])

        # FPS
        if settings.get('fps'):
            cmd.extend(['-r', str(settings['fps'])])

        # Audio codec
        audio_codec = settings.get('audio_codec', 'aac')
        cmd.extend(['-c:a', audio_codec])

        # Audio bitrate
        if settings.get('audio_bitrate'):
            cmd.extend(['-b:a', settings['audio_bitrate']])

        # Output
        cmd.append(output_path)

        logger.info(f'Starting transcode', extra={
            'input': input_path,
            'output': output_path,
            'codec': codec,
        })

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)

            if result.returncode != 0:
                raise Exception(f'FFmpeg error: {result.stderr}')

            logger.info('Transcode completed', extra={'output': output_path})

        except subprocess.TimeoutExpired:
            logger.error('Transcode timeout (1 hour)')
            raise
        except Exception as e:
            logger.error(f'Transcode failed: {e}')
            raise

    async def extract_thumbnail(
        self,
        video_path: str,
        output_path: str,
        timestamp: str = '00:00:01',
    ) -> None:
        """
        Extract thumbnail from video

        Args:
            video_path: Input video
            output_path: Output thumbnail (JPG)
            timestamp: Time to extract (HH:MM:SS format)
        """
        cmd = [
            self.ffmpeg_path,
            '-i', video_path,
            '-ss', timestamp,
            '-vframes', '1',
            '-s', '320x180',  # Thumbnail size
            output_path,
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode != 0:
                raise Exception(f'Thumbnail extraction failed: {result.stderr}')

            logger.info('Thumbnail extracted', extra={'output': output_path})

        except Exception as e:
            logger.error(f'Thumbnail extraction failed: {e}')
            raise

    async def create_preview(
        self,
        video_path: str,
        output_path: str,
        duration: int = 10,
    ) -> None:
        """
        Create preview clip (first 10 seconds)

        Args:
            video_path: Input video
            output_path: Output preview video
            duration: Preview duration in seconds
        """
        cmd = [
            self.ffmpeg_path,
            '-i', video_path,
            '-t', str(duration),
            '-c:v', 'h264',
            '-preset', 'fast',
            '-b:v', '2000k',
            '-c:a', 'aac',
            '-b:a', '128k',
            output_path,
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

            if result.returncode != 0:
                raise Exception(f'Preview creation failed: {result.stderr}')

            logger.info('Preview created', extra={'output': output_path})

        except Exception as e:
            logger.error(f'Preview creation failed: {e}')
            raise
```

---

## Format Support

### Supported Formats

| Format | Codec | Container | Support |
|--------|-------|-----------|---------|
| **MP4** | H.264 | MP4 | ✅ Recommended |
| **WebM** | VP9 | WebM | ✅ Supported |
| **MOV** | H.264 | MOV | ✅ Supported |
| **MKV** | H.264/VP9 | Matroska | ✅ Supported |
| **AVI** | MPEG-2 | AVI | ✅ Supported |
| **FLV** | H.264 | Flash | ⚠️ Legacy |

### Recommended Specifications

```python
RECOMMENDED_SETTINGS = {
    'codec': 'h264',              # Widely compatible
    'bitrate': '5000k',           # 1080p 30fps
    'fps': 30,
    'width': 1920,
    'height': 1080,
    'audio_codec': 'aac',
    'audio_bitrate': '128k',
    'preset': 'medium',           # Balance speed and quality
}

# For high quality (4K)
HIGH_QUALITY_SETTINGS = {
    'codec': 'h264',
    'bitrate': '15000k',
    'fps': 60,
    'width': 3840,
    'height': 2160,
    'audio_codec': 'aac',
    'audio_bitrate': '192k',
    'preset': 'slow',
}

# For web/mobile
WEB_OPTIMIZED_SETTINGS = {
    'codec': 'h264',
    'bitrate': '2000k',
    'fps': 24,
    'width': 1280,
    'height': 720,
    'audio_codec': 'aac',
    'audio_bitrate': '96k',
    'preset': 'fast',
}
```

---

## Video Generation

### Veo 2.0 API Integration

**File**: `backend/src/services/video_service.py`

```python
import asyncio
from google.cloud import aiplatform
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class VideoService:
    """Video generation with Veo 2.0"""

    def __init__(self, firestore_repo, storage_service):
        self.firestore = firestore_repo
        self.storage = storage_service
        self.client = aiplatform.init(project='your-project')

    async def generate_video(
        self,
        prompt: str,
        user_email: str,
        duration: int = 5,
        style: str = 'cinematic',
        aspect_ratio: str = '16:9',
        fps: int = 24,
        workspace_id: str = None,
    ) -> dict:
        """
        Generate video with Veo 2.0

        Args:
            prompt: Video description
            duration: 1-60 seconds
            style: cinematic, animated, documentary, realistic
            aspect_ratio: 16:9, 9:16, 1:1
            fps: 24 or 30

        Returns:
            Response with video request ID and operation ID
        """

        # Validate inputs
        if not prompt or len(prompt) > 2000:
            raise ValueError('Prompt must be 1-2000 characters')

        if not 1 <= duration <= 60:
            raise ValueError('Duration must be 1-60 seconds')

        valid_styles = ['cinematic', 'animated', 'documentary', 'realistic']
        if style not in valid_styles:
            raise ValueError(f'Invalid style. Must be one of: {valid_styles}')

        # Create pending document
        video_doc = {
            'user_email': user_email,
            'workspace_id': workspace_id,
            'prompt': prompt,
            'duration': duration,
            'style': style,
            'aspect_ratio': aspect_ratio,
            'fps': fps,
            'status': 'pending',
            'created_at': datetime.utcnow().isoformat(),
        }

        doc_id = await self.firestore.create_document('media_library', video_doc)

        logger.info('Video generation started', extra={
            'doc_id': doc_id,
            'user_email': user_email,
            'duration': duration,
        })

        # Call Veo API asynchronously
        try:
            operation = await self._call_veo_api(
                prompt=prompt,
                duration=duration,
                style=style,
                aspect_ratio=aspect_ratio,
                fps=fps,
            )

            # Store operation ID
            await self.firestore.update_document('media_library', doc_id, {
                'operation_id': operation.name,
                'operation_status': 'pending',
            })

            return {
                'id': doc_id,
                'status': 'pending',
                'operation_id': operation.name,
            }

        except Exception as e:
            logger.error(f'Veo API call failed: {e}', exc_info=True)
            await self.firestore.update_document('media_library', doc_id, {
                'status': 'failed',
                'error': str(e),
            })
            raise

    async def _call_veo_api(
        self,
        prompt: str,
        duration: int,
        style: str,
        aspect_ratio: str,
        fps: int,
    ):
        """
        Call Veo 2.0 API

        Returns Google long-running operation
        """
        # Get appropriate aspect ratio dimensions
        dimensions = {
            '16:9': (1280, 720),
            '9:16': (720, 1280),
            '1:1': (1024, 1024),
        }

        width, height = dimensions[aspect_ratio]

        # Call Veo API
        response = aiplatform.gapic.PredictionServiceClient.generate_content(
            model='veo-2',
            prompt=prompt,
            duration_seconds=duration,
            width=width,
            height=height,
            style_guide=style,
            fps=fps,
        )

        return response

    async def get_video_status(self, video_id: str, user_email: str) -> dict:
        """
        Get video generation status

        Args:
            video_id: Media library document ID
            user_email: User email (ownership check)

        Returns:
            Status dict with progress
        """
        doc = await self.firestore.get_document('media_library', video_id)

        if not doc or doc['user_email'] != user_email:
            raise PermissionError('Not your video')

        status = doc['status']

        if status == 'success':
            return {
                'id': video_id,
                'status': 'success',
                'gcs_uri': doc['gcs_uri'],
                'completed_at': doc['completed_at'],
            }

        if status == 'pending':
            # Check operation status
            operation_id = doc.get('operation_id')
            if operation_id:
                operation = await self._check_operation_status(operation_id)

                if operation['done']:
                    # Video is complete
                    video_uri = operation['result']['output_uri']
                    await self._finalize_video(video_id, video_uri)

                    return {
                        'id': video_id,
                        'status': 'success',
                        'gcs_uri': video_uri,
                    }

                else:
                    # Still processing
                    progress = operation.get('metadata', {}).get('progress_percentage', 0)
                    return {
                        'id': video_id,
                        'status': 'pending',
                        'progress_percentage': progress,
                    }

        return {
            'id': video_id,
            'status': status,
        }

    async def _finalize_video(self, video_id: str, temp_uri: str) -> None:
        """
        Finalize video generation:
        1. Download from temporary URI
        2. Optional: Process with FFmpeg
        3. Upload to GenMedia bucket
        4. Update Firestore
        """
        logger.info('Finalizing video', extra={'video_id': video_id})

        try:
            # Download video
            video_data = await self.storage.download(temp_uri)

            # Upload to permanent location
            gcs_uri = await self.storage.upload(
                data=video_data,
                bucket='genMedia',
                path=f'media/videos/{video_id}.mp4',
                content_type='video/mp4',
            )

            # Update document
            await self.firestore.update_document('media_library', video_id, {
                'status': 'success',
                'gcs_uri': gcs_uri,
                'completed_at': datetime.utcnow().isoformat(),
            })

            logger.info('Video finalized', extra={
                'video_id': video_id,
                'gcs_uri': gcs_uri,
            })

        except Exception as e:
            logger.error(f'Video finalization failed: {e}', exc_info=True)
            await self.firestore.update_document('media_library', video_id, {
                'status': 'failed',
                'error': str(e),
            })
```

---

## Transcoding & Processing

### When to Transcode

```python
async def determine_processing_needed(video_info: dict) -> dict:
    """
    Determine if video needs transcoding

    Returns:
        {
            'needs_processing': bool,
            'reason': str,
            'recommended_settings': dict,
        }
    """
    issues = []

    # Check codec
    if video_info['codec'] not in ['h264', 'h265']:
        issues.append('Video codec not optimized')

    # Check bitrate
    if video_info['bitrate'] > 8000:
        issues.append('Bitrate too high')
    elif video_info['bitrate'] < 2000:
        issues.append('Bitrate too low')

    # Check resolution
    if video_info['width'] > 1920 or video_info['height'] > 1080:
        issues.append('Resolution exceeds 1080p')

    # Check FPS
    if video_info['fps'] not in [24, 25, 30, 60]:
        issues.append('FPS not standard')

    if issues:
        return {
            'needs_processing': True,
            'reason': '; '.join(issues),
            'recommended_settings': RECOMMENDED_SETTINGS,
        }

    return {
        'needs_processing': False,
        'reason': 'Video already optimized',
    }
```

### Batch Processing

```python
async def batch_transcode_videos(video_ids: List[str]):
    """
    Transcode multiple videos in parallel

    Uses asyncio to process multiple videos concurrently
    """
    tasks = [
        transcode_video(video_id)
        for video_id in video_ids
    ]

    results = await asyncio.gather(*tasks, return_exceptions=True)

    succeeded = sum(1 for r in results if not isinstance(r, Exception))
    failed = sum(1 for r in results if isinstance(r, Exception))

    logger.info(f'Batch transcode completed', extra={
        'total': len(video_ids),
        'succeeded': succeeded,
        'failed': failed,
    })

    return results
```

---

## Quality Settings

### Preset Comparison

| Preset | Speed | Quality | File Size | Use Case |
|--------|-------|---------|-----------|----------|
| ultrafast | Very fast | Low | Small | Live streaming |
| superfast | Fast | Low-Medium | Medium | Web streaming |
| veryfast | Fast | Medium | Medium | Standard |
| faster | Medium | Medium-High | Large | Standard |
| fast | Medium | High | Large | Standard |
| **medium** | Slow | Very High | Very Large | **Default** |
| slow | Very Slow | Very High | Very Large | Archive |
| slower | Extremely Slow | Maximum | Maximum | Final archival |
| veryslow | Extremely Slow | Maximum | Maximum | Final archival |

### Bitrate Guidelines

| Resolution | Quality | Bitrate (Mbps) | FPS | Use Case |
|------------|---------|----------------|-----|----------|
| 480p | Low | 0.5-1 | 24 | Mobile |
| 720p | Medium | 2-4 | 30 | Web |
| 1080p | High | 5-8 | 30 | Desktop |
| 1440p | Very High | 10-15 | 60 | High-end |
| 4K | Maximum | 20-50 | 60 | Cinema |

---

## Performance Optimization

### Parallel Processing

```python
# Process multiple videos in parallel
async def process_multiple_videos(video_paths: List[str]):
    tasks = [
        process_video(path)
        for path in video_paths
    ]

    # Run up to 3 at a time (limit resource usage)
    semaphore = asyncio.Semaphore(3)

    async def bounded_task(task):
        async with semaphore:
            return await task

    results = await asyncio.gather(
        *[bounded_task(task) for task in tasks],
        return_exceptions=True
    )

    return results
```

### Hardware Acceleration

```bash
# Check for GPU support
ffmpeg -hwaccels

# Use NVIDIA GPU for encoding (if available)
ffmpeg -i input.mp4 \
    -c:v h264_nvenc \      # NVIDIA encoder
    -preset fast \          # fast, default, slow
    output.mp4

# Use Intel QuickSync (if available)
ffmpeg -i input.mp4 \
    -c:v h264_qsv \        # Intel encoder
    -preset fast \
    output.mp4
```

---

## Troubleshooting

### Issue: "FFmpeg command not found"

**Solution**:
```bash
# Install FFmpeg
# macOS
brew install ffmpeg

# Linux
sudo apt-get install ffmpeg

# Docker: already included in Dockerfile
```

### Issue: "Video codec not supported"

**Solution**:
```python
# Check supported codecs
ffmpeg -codecs | grep h264

# Re-encode to H.264
ffmpeg -i input.avi -c:v h264 output.mp4
```

### Issue: "Processing too slow"

**Solution**:
1. Use faster preset: `preset: 'fast'` or `'veryfast'`
2. Lower bitrate: `2000k` instead of `5000k`
3. Use hardware acceleration (GPU)
4. Process in parallel with semaphore limit

### Issue: "Output file too large"

**Solution**:
```python
# Reduce bitrate
settings = {
    'bitrate': '2000k',  # Instead of 5000k
    'preset': 'fast',
}

# Or reduce resolution
settings = {
    'width': 1280,
    'height': 720,  # Instead of 1920x1080
}
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Video processing and generation
- **Related Docs**: BACKEND_SERVICES.md, 02_DATA_FLOW_PATTERNS.md, DOCKER_SETUP.md
