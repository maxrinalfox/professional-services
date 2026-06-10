# Logging Configuration & Strategy Guide

## Overview

Creative Studio uses centralized logging for both frontend and backend applications, with integration to Google Cloud Logging for monitoring and debugging in production.

**Logging Architecture**:
```
Frontend Console Logs
    ↓
Backend Python Logging
    ↓
Google Cloud Logging
    ↓
Cloud Console Dashboard
    ↓
Alerts & Monitoring
```

---

## Table of Contents

1. [Backend Logging Setup](#backend-logging-setup)
2. [Frontend Logging Setup](#frontend-logging-setup)
3. [Log Levels](#log-levels)
4. [Structured Logging](#structured-logging)
5. [Cloud Logging Integration](#cloud-logging-integration)
6. [Debug Strategies](#debug-strategies)
7. [Performance & Best Practices](#performance--best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Backend Logging Setup

### Logger Configuration

**File**: `backend/src/config/logger_config.py`

```python
import logging
import json
import sys
from datetime import datetime
import os

class JSONFormatter(logging.Formatter):
    """
    Custom formatter that outputs JSON for Cloud Logging integration

    Cloud Logging expects:
    - severity: Log level
    - message: Log message
    - timestamp: ISO 8601 timestamp
    - labels: Structured fields (service, version, environment)
    - jsonPayload: Additional structured data
    """

    def format(self, record: logging.LogRecord) -> str:
        log_obj = {
            'severity': record.levelname,
            'message': record.getMessage(),
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'labels': {
                'service': 'creative-studio-backend',
                'environment': os.getenv('ENVIRONMENT', 'development'),
                'version': os.getenv('VERSION', '1.0.0'),
            },
            'sourceLocation': {
                'file': record.filename,
                'line': record.lineno,
                'function': record.funcName,
            },
        }

        # Add extra fields (context)
        if record.args:
            log_obj['jsonPayload'] = {k: v for k, v in record.__dict__.items()
                                      if k not in ['name', 'msg', 'args', 'created',
                                                   'filename', 'funcName', 'levelname',
                                                   'lineno', 'module', 'pathname',
                                                   'process', 'processName', 'relativeCreated',
                                                   'thread', 'threadName', 'exc_info',
                                                   'stack_info', 'getMessage']}

        # Add exception info if present
        if record.exc_info:
            log_obj['exception'] = {
                'type': record.exc_info[0].__name__,
                'message': str(record.exc_info[1]),
                'traceback': self.formatException(record.exc_info),
            }

        return json.dumps(log_obj)


def configure_logging():
    """
    Configure Python logging with JSON formatter for Cloud Logging

    Log levels:
    - DEBUG: Detailed diagnostic info (development only)
    - INFO: Confirmation that system is working
    - WARNING: Something unexpected (default level)
    - ERROR: Serious problem, function failed
    - CRITICAL: System is broken
    """

    root_logger = logging.getLogger()

    # Set log level based on environment
    log_level = os.getenv('LOG_LEVEL', 'INFO')
    root_logger.setLevel(getattr(logging, log_level))

    # JSON formatter for Cloud Logging
    formatter = JSONFormatter()

    # Console handler (stdout for container logging)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # Suppress verbose library logs
    logging.getLogger('firebase_admin').setLevel(logging.WARNING)
    logging.getLogger('google.cloud').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)

    return root_logger


# Initialize logging on module load
logger = configure_logging()
```

### Using the Logger

**File**: `backend/src/main.py`

```python
import logging
from src.config.logger_config import logger

# Get logger for module
logger = logging.getLogger(__name__)

@app.get('/api/health')
async def health_check():
    """Health check endpoint"""
    logger.info('Health check requested')
    return {'status': 'healthy'}

@app.post('/api/images')
async def generate_image(request: ImageRequest):
    """Generate image"""
    user_email = 'user@example.com'

    # Log with context
    logger.info(
        f'Image generation started',
        extra={'user_email': user_email, 'prompt_length': len(request.prompt)}
    )

    try:
        result = await image_service.generate_image(request)
        logger.info(
            f'Image generated successfully',
            extra={'user_email': user_email, 'image_id': result.id}
        )
        return result
    except Exception as e:
        logger.error(
            f'Image generation failed: {str(e)}',
            exc_info=True,
            extra={'user_email': user_email}
        )
        raise
```

### Log Levels in Different Environments

```python
# Environment-specific configuration
LOG_LEVELS = {
    'development': 'DEBUG',    # Detailed diagnostic info
    'staging': 'INFO',         # Normal operations only
    'production': 'WARNING',   # Only problems and up
}

# Set in .env or environment
ENVIRONMENT=production
LOG_LEVEL=WARNING
```

---

## Frontend Logging Setup

### Angular Logger Service

**File**: `frontend/src/app/common/services/logger.service.ts`

```typescript
import { Injectable } from '@angular/core';

/**
 * Centralized logging service for frontend
 *
 * Usage:
 *   this.logger.info('User logged in', { userId: user.id });
 *   this.logger.error('API request failed', error);
 */
@Injectable({ providedIn: 'root' })
export class LoggerService {
  private isDevelopment = !environment.production;

  // Log levels
  private logLevels = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
  };

  constructor() {
    this.configureLogging();
  }

  /**
   * Configure logging based on environment
   */
  private configureLogging(): void {
    if (this.isDevelopment) {
      // Development: enable all logs
      (window as any).__logLevel = this.logLevels.debug;
    } else {
      // Production: only warn and error
      (window as any).__logLevel = this.logLevels.warn;
    }
  }

  /**
   * Debug level logging (development only)
   */
  debug(message: string, data?: any): void {
    if ((window as any).__logLevel <= this.logLevels.debug) {
      console.debug(`[DEBUG] ${message}`, data);
      this.sendToBackend('DEBUG', message, data);
    }
  }

  /**
   * Info level logging
   */
  info(message: string, data?: any): void {
    if ((window as any).__logLevel <= this.logLevels.info) {
      console.info(`[INFO] ${message}`, data);
      this.sendToBackend('INFO', message, data);
    }
  }

  /**
   * Warning level logging
   */
  warn(message: string, data?: any): void {
    if ((window as any).__logLevel <= this.logLevels.warn) {
      console.warn(`[WARN] ${message}`, data);
      this.sendToBackend('WARNING', message, data);
    }
  }

  /**
   * Error level logging
   */
  error(message: string, error?: any): void {
    if ((window as any).__logLevel <= this.logLevels.error) {
      console.error(`[ERROR] ${message}`, error);
      this.sendToBackend('ERROR', message, {
        message: error?.message,
        stack: error?.stack,
        name: error?.name,
      });
    }
  }

  /**
   * Send logs to backend for aggregation
   * (Optional - for production error tracking)
   */
  private sendToBackend(level: string, message: string, data?: any): void {
    if (!environment.production) return; // Only in production

    // Send to backend logging endpoint (implement as needed)
    // this.http.post('/api/logs', { level, message, data, timestamp: new Date() }).subscribe();
  }

  /**
   * Performance timing
   */
  time(label: string): () => void {
    const startTime = performance.now();
    return () => {
      const endTime = performance.now();
      const duration = (endTime - startTime).toFixed(2);
      this.debug(`${label}: ${duration}ms`);
    };
  }
}
```

### Using the Logger in Components

```typescript
import { LoggerService } from './common/services/logger.service';

@Component({...})
export class MediaGalleryComponent implements OnInit {
  constructor(private logger: LoggerService) {}

  ngOnInit(): void {
    const endTiming = this.logger.time('Gallery initialization');

    this.logger.info('Gallery component initialized', {
      itemCount: this.items.length,
    });

    // Do work...

    endTiming(); // Logs timing
  }

  async loadGallery(): Promise<void> {
    try {
      this.logger.debug('Loading gallery with filters', this.filters);
      const data = await this.api.getGallery(this.filters).toPromise();
      this.logger.info('Gallery loaded successfully', { itemCount: data.length });
    } catch (error) {
      this.logger.error('Failed to load gallery', error);
      throw error;
    }
  }
}
```

---

## Log Levels

### Level Hierarchy

```
DEBUG < INFO < WARNING < ERROR < CRITICAL
```

### When to Use Each Level

| Level | Use Case | Environment | Audience |
|-------|----------|-------------|----------|
| **DEBUG** | Detailed diagnostic info, variable values, execution flow | Development only | Developers |
| **INFO** | Confirmation that system is working as expected | Dev, Staging, Prod | Operations, Developers |
| **WARNING** | Something unexpected, non-critical issue | Staging, Production | Operations Team |
| **ERROR** | Serious problem, functionality broken | Staging, Production | Operations Team, Alerts |
| **CRITICAL** | System is broken, immediate action needed | Production only | On-Call Engineer, Alerts |

### Examples

```python
# DEBUG - Detailed diagnostic (development only)
logger.debug('Checking user roles', extra={'user_id': user_id, 'roles': user.roles})

# INFO - Normal operations
logger.info('User successfully authenticated', extra={'user_email': user_email})

# WARNING - Something unexpected but recoverable
logger.warning('Slow API response', extra={'endpoint': '/api/images', 'duration_ms': 5000})

# ERROR - Function failed
logger.error('Failed to save image to Cloud Storage', exc_info=True, extra={'image_id': image_id})

# CRITICAL - System broken
logger.critical('Database connection lost - requests failing', exc_info=True)
```

---

## Structured Logging

### Adding Context

Always include relevant context when logging:

```python
# ❌ Bad - No context
logger.info('User logged in')

# ✅ Good - With context
logger.info('User logged in', extra={
    'user_email': user_email,
    'user_id': user_id,
    'workspace_id': workspace_id,
    'timestamp': datetime.utcnow().isoformat(),
})
```

### Standard Context Fields

```python
# Common fields to include in logs
context = {
    'user_email': 'user@example.com',
    'user_id': 'firebase-uid-123',
    'workspace_id': 'ws-123',
    'request_id': 'req-abc123',        # For distributed tracing
    'duration_ms': 1234,                # For performance metrics
    'error_type': 'VertexAIError',      # For error categorization
    'retry_count': 2,                   # For retry tracking
}

logger.info('Operation completed', extra=context)
```

### Structured Logging in Services

```python
class ImageService:
    async def generate_image(self, prompt: str, user_email: str) -> dict:
        request_id = str(uuid4())
        logger.info('Image generation started', extra={
            'request_id': request_id,
            'user_email': user_email,
            'prompt_length': len(prompt),
        })

        try:
            start_time = time.time()

            # Call API
            result = await self.vertex_ai.generate_image(prompt)

            duration_ms = (time.time() - start_time) * 1000
            logger.info('Image generation succeeded', extra={
                'request_id': request_id,
                'user_email': user_email,
                'duration_ms': duration_ms,
                'image_id': result['id'],
            })

            return result

        except VertexAIError as e:
            duration_ms = (time.time() - start_time) * 1000
            logger.error('Image generation failed', exc_info=True, extra={
                'request_id': request_id,
                'user_email': user_email,
                'duration_ms': duration_ms,
                'error_code': e.code,
                'error_message': str(e),
            })
            raise
```

---

## Cloud Logging Integration

### Automatic Integration

Firebase/GCP functions automatically integrate with Cloud Logging:

```python
# Logs are automatically collected by Cloud Logging
# No additional setup needed
logger.info('This goes to Cloud Logging')
```

### Accessing Logs

**Cloud Console**:
1. Go to Google Cloud Console
2. Select your project
3. Go to Logging → Logs Explorer
4. Filter by service, severity, timestamp

**Query Examples**:

```sql
-- All errors in the last hour
resource.type="cloud_run_revision"
severity>=ERROR
timestamp>="2025-01-15T10:00:00Z"

-- Specific user's requests
resource.type="cloud_run_revision"
jsonPayload.user_email="user@example.com"

-- Performance issues
resource.type="cloud_run_revision"
jsonPayload.duration_ms>5000

-- Vertex AI API errors
resource.type="cloud_run_revision"
jsonPayload.error_type="VertexAIError"
```

### Log Retention

**Default**: 30 days

**Modify retention**:
```bash
# Configure in Cloud Console or via gcloud
gcloud logging sinks update _Default \
    --log-filter='resource.type="cloud_run_revision"' \
    --log-retention-days=90
```

---

## Debug Strategies

### Enable Debug Logging

**Development**:
```python
# Set in .env
LOG_LEVEL=DEBUG

# Or at runtime
import logging
logging.getLogger().setLevel(logging.DEBUG)
```

**Staging/Production** (temporary):
```bash
# Temporarily enable debug logging for debugging
gcloud run services update SERVICE_NAME \
    --set-env-vars LOG_LEVEL=DEBUG \
    --region REGION

# Don't forget to reset
gcloud run services update SERVICE_NAME \
    --set-env-vars LOG_LEVEL=WARNING \
    --region REGION
```

### Request Tracking

Use request IDs to trace requests across logs:

```python
from uuid import uuid4
from fastapi import Request
import contextvars

# Create context var for request ID
request_id_context: contextvars.ContextVar[str] = contextvars.ContextVar(
    'request_id',
    default=None
)

@app.middleware('http')
async def add_request_id(request: Request, call_next):
    request_id = str(uuid4())
    request_id_context.set(request_id)

    logger.info('Request started', extra={
        'request_id': request_id,
        'method': request.method,
        'path': request.url.path,
    })

    response = await call_next(request)

    logger.info('Request completed', extra={
        'request_id': request_id,
        'status_code': response.status_code,
    })

    return response

# Use in services
logger.info('Processing image', extra={
    'request_id': request_id_context.get(),
    'image_id': image_id,
})
```

### Log Aggregation

View related logs using request ID:

```sql
-- Find all logs for a specific request
resource.type="cloud_run_revision"
jsonPayload.request_id="abc-123-def"

-- Find all requests from a user
resource.type="cloud_run_revision"
jsonPayload.user_email="user@example.com"
timestamp>="2025-01-15T10:00:00Z"
```

### Sampling

In high-traffic scenarios, enable sampling to reduce costs:

```python
class SamplingFilter(logging.Filter):
    def __init__(self, sample_rate=0.1):
        self.sample_rate = sample_rate

    def filter(self, record: logging.LogRecord) -> bool:
        # Log 10% of debug messages in production
        if record.levelno == logging.DEBUG:
            return random.random() < self.sample_rate
        return True

# Add to logger
logger.addFilter(SamplingFilter(sample_rate=0.1))
```

---

## Performance & Best Practices

### Performance Impact

| Strategy | Impact | Notes |
|----------|--------|-------|
| Logging everything | High | Can slow down requests |
| JSON formatting | Medium | Cloud Logging expects JSON |
| Remote log sending | High | Network overhead |
| Debug level in prod | Very High | Never enable by default |

### Best Practices

#### 1. Don't Log Sensitive Data

```python
# ❌ Bad - Logs password
logger.info('Login attempt', extra={'email': email, 'password': password})

# ✅ Good - Only non-sensitive fields
logger.info('Login attempt', extra={'email': email, 'success': True})
```

#### 2. Avoid Logging in Loops

```python
# ❌ Bad - 1000 log entries in tight loop
for item in items:
    logger.debug(f'Processing {item.id}')

# ✅ Good - Log summary
logger.debug(f'Processing {len(items)} items')
for item in items:
    # Process without logging
    pass
logger.debug(f'Processed {len(items)} items successfully')
```

#### 3. Use Lazy String Formatting

```python
# ❌ Bad - String formatted even if not logged
logger.debug(f'User data: {expensive_function()}')

# ✅ Good - String only formatted if logged
logger.debug('User data: %s', expensive_function())

# Or use extra fields (preferred)
logger.debug('Processing user', extra={'user_id': user_id})
```

#### 4. Set Appropriate Log Levels

```python
# Development: DEBUG
# Staging: INFO
# Production: WARNING

if os.getenv('ENVIRONMENT') == 'production':
    logger.setLevel(logging.WARNING)
```

#### 5. Clear Error Messages

```python
# ❌ Bad - Vague error
logger.error('Operation failed')

# ✅ Good - Specific and actionable
logger.error('Failed to upload image to Cloud Storage', exc_info=True, extra={
    'bucket': bucket_name,
    'file_path': file_path,
    'error_code': error.code,
})
```

---

## Troubleshooting

### Issue: Logs Not Appearing in Cloud Logging

**Cause**: Service account lacks logging permissions

**Solution**:
```bash
# Grant Cloud Logging Writer role
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:SERVICE_ACCOUNT_EMAIL \
    --role=roles/logging.logWriter
```

### Issue: Logs Missing Request Context

**Cause**: Context not passed through async functions

**Solution**: Use context vars:
```python
import contextvars

request_id_var = contextvars.ContextVar('request_id')

@app.middleware('http')
async def add_context(request: Request, call_next):
    request_id_var.set(str(uuid4()))
    return await call_next(request)

# In service
logger.info('Processing', extra={'request_id': request_id_var.get()})
```

### Issue: Performance Degradation After Logging

**Cause**: Logging too much in hot paths

**Solution**:
1. Enable sampling for debug logs
2. Move debug logging to development only
3. Use lazy formatting
4. Check for excessive context data

### Issue: Expensive Logs Slowing Down Requests

**Cause**: Heavy computation in log statements

**Solution**:
```python
# ❌ Bad
logger.debug(f'Large object: {json.dumps(huge_dict, indent=2)}')

# ✅ Good
if logger.isEnabledFor(logging.DEBUG):
    logger.debug('Processing item', extra={'item_id': item_id})
```

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: Backend and frontend logging
- **Related Docs**: INFRASTRUCTURE.md, DOCKER_SETUP.md, 02_DATA_FLOW_PATTERNS.md
