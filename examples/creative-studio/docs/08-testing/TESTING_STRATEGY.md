# Testing Guide

## Overview

This guide covers all aspects of testing in Creative Studio, including unit tests, integration tests, and end-to-end tests for both backend and frontend.

---

## Table of Contents

1. [Testing Frameworks](#testing-frameworks)
2. [Backend Testing](#backend-testing)
3. [Frontend Testing](#frontend-testing)
4. [Running Tests](#running-tests)
5. [Writing Tests](#writing-tests)
6. [Test Coverage](#test-coverage)
7. [CI/CD Testing](#cicd-testing)

---

## Testing Frameworks

### Backend

| Framework | Purpose | Config |
|-----------|---------|--------|
| **pytest** | Unit and integration testing | `pyproject.toml` |
| **pytest-cov** | Coverage reporting | `pyproject.toml` |
| **pytest-watch** | Auto-run tests on file changes | `pyproject.toml` |

**Installation**:
```bash
cd backend
pip install -e ".[dev]"  # Installs dev dependencies including pytest
```

### Frontend

| Framework | Purpose | Config |
|-----------|---------|--------|
| **Jasmine** | Unit testing framework | `karma.conf.js` |
| **Karma** | Test runner | `karma.conf.js` |
| **Istanbul/nyc** | Coverage reporting | `angular.json` |

**Installation**:
```bash
cd frontend
npm install  # Installs dev dependencies
```

---

## Backend Testing

### Test Structure

```
backend/
├── tests/
│   ├── __init__.py
│   ├── conftest.py                 # Shared fixtures
│   ├── test_search.py              # Example tests
│   ├── auth/
│   │   ├── test_auth_guard.py      # Auth tests
│   │   └── test_token_validation.py
│   ├── services/
│   │   ├── test_image_service.py
│   │   ├── test_video_service.py
│   │   └── test_user_service.py
│   ├── controllers/
│   │   ├── test_image_controller.py
│   │   └── test_gallery_controller.py
│   └── integration/
│       ├── test_api_flows.py
│       └── test_database_operations.py
└── src/
    └── # Production code
```

### Running Backend Tests

#### Run All Tests
```bash
cd backend
pytest
```

#### Run Specific Test File
```bash
pytest tests/test_search.py
```

#### Run Specific Test Function
```bash
pytest tests/test_search.py::test_search_query
```

#### Run Tests with Coverage
```bash
pytest --cov=src --cov-report=html
# Report generated in htmlcov/index.html
```

#### Run Tests in Watch Mode
```bash
ptw  # Auto-runs tests when files change
```

#### Run Tests with Verbose Output
```bash
pytest -v
```

#### Run Tests and Stop on First Failure
```bash
pytest -x
```

### Backend Test Example

**File**: `backend/tests/test_search.py`

```python
import pytest
from unittest.mock import patch, MagicMock
from src.services.gallery_service import GalleryService
from src.users.user_model import UserModel, UserRoleEnum

class TestGallerySearch:
    """Test suite for gallery search functionality"""

    @pytest.fixture
    def gallery_service(self):
        """Fixture providing GalleryService instance"""
        return GalleryService()

    @pytest.fixture
    def mock_user(self):
        """Fixture providing a mock user"""
        return UserModel(
            id="user-123",
            email="test@example.com",
            roles=[UserRoleEnum.VIEWER],
            workspace_id="workspace-123"
        )

    def test_search_by_keyword(self, gallery_service, mock_user):
        """Test searching gallery by keyword"""
        # Arrange
        search_query = "landscape"

        # Act
        with patch.object(gallery_service, 'query') as mock_query:
            mock_query.return_value = [{"id": "media-1", "prompt": "landscape image"}]
            result = gallery_service.search(search_query, mock_user.id)

        # Assert
        assert len(result) == 1
        assert "landscape" in result[0]["prompt"]

    def test_search_empty_results(self, gallery_service, mock_user):
        """Test search returns empty list when no matches"""
        # Arrange
        search_query = "nonexistent"

        # Act
        with patch.object(gallery_service, 'query') as mock_query:
            mock_query.return_value = []
            result = gallery_service.search(search_query, mock_user.id)

        # Assert
        assert result == []

    def test_search_permission_denied(self, gallery_service, mock_user):
        """Test unauthorized user cannot search other's media"""
        # Arrange
        other_user_id = "user-999"

        # Act & Assert
        with pytest.raises(PermissionError):
            gallery_service.search("query", other_user_id)
```

### pytest Configuration

**File**: `pyproject.toml`

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "--strict-markers -ra"
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
    "slow: Slow tests",
]
```

### Running Marked Tests

```bash
# Run only unit tests
pytest -m unit

# Run integration tests
pytest -m integration

# Run all except slow tests
pytest -m "not slow"
```

---

## Frontend Testing

### Test Structure

```
frontend/src/
├── app/
│   ├── auth.interceptor.spec.ts
│   ├── common/
│   │   ├── services/
│   │   │   ├── auth.service.spec.ts
│   │   │   ├── user.service.spec.ts
│   │   │   └── gallery.service.spec.ts
│   │   └── components/
│   │       └── component.spec.ts
│   ├── gallery/
│   │   ├── media-gallery.component.spec.ts
│   │   └── media-detail.component.spec.ts
│   └── admin/
│       └── admin.component.spec.ts
└── # Component and service files
```

### Running Frontend Tests

#### Run All Tests
```bash
cd frontend
ng test
```

#### Run Tests Once (CI Mode)
```bash
ng test --watch=false
```

#### Run Specific Test File
```bash
ng test --include='**/auth.service.spec.ts'
```

#### Run Tests with Coverage
```bash
ng test --code-coverage
# Report generated in coverage/
```

#### Run Tests in Headless Mode
```bash
ng test --watch=false --browsers=ChromeHeadless
```

### Frontend Test Example

**File**: `frontend/src/app/common/services/auth.service.spec.ts`

```typescript
import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { AuthService } from './auth.service';
import { Auth } from '@angular/fire/auth';
import { Router } from '@angular/router';

describe('AuthService', () => {
  let service: AuthService;
  let httpMock: HttpTestingController;
  let authMock: jasmine.SpyObj<Auth>;
  let routerMock: jasmine.SpyObj<Router>;

  beforeEach(() => {
    const authSpy = jasmine.createSpyObj('Auth', ['signOut', 'isAuthenticated']);
    const routerSpy = jasmine.createSpyObj('Router', ['navigate']);

    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [
        AuthService,
        { provide: Auth, useValue: authSpy },
        { provide: Router, useValue: routerSpy }
      ]
    });

    service = TestBed.inject(AuthService);
    httpMock = TestBed.inject(HttpTestingController);
    authMock = TestBed.inject(Auth) as jasmine.SpyObj<Auth>;
    routerMock = TestBed.inject(Router) as jasmine.SpyObj<Router>;
  });

  afterEach(() => {
    httpMock.verify();
  });

  describe('Authentication', () => {
    it('should sign in user with Google', (done) => {
      // Arrange
      const expectedToken = 'test-token-123';

      // Act
      service.signInWithOkta().subscribe(token => {
        // Assert
        expect(token).toBe(expectedToken);
        done();
      });
    });

    it('should logout user', (done) => {
      // Arrange
      authMock.signOut.and.returnValue(Promise.resolve());

      // Act
      service.logout().then(() => {
        // Assert
        expect(authMock.signOut).toHaveBeenCalled();
        expect(routerMock.navigate).toHaveBeenCalledWith(['/login']);
        done();
      });
    });

    it('should check if user is logged in', (done) => {
      // Arrange
      authMock.isAuthenticated.and.returnValue(Promise.resolve(true));

      // Act
      service.isLoggedIn().then(result => {
        // Assert
        expect(result).toBe(true);
        done();
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle login failure', (done) => {
      // Arrange
      const errorMessage = 'Authentication failed';

      // Act & Assert
      service.signInWithOkta().subscribe(
        () => fail('should have failed'),
        (error) => {
          expect(error.message).toContain('Authentication');
          done();
        }
      );
    });
  });
});
```

### Karma Configuration

**File**: `frontend/karma.conf.js`

```javascript
module.exports = function (config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [
      require('karma-jasmine'),
      require('karma-chrome-launcher'),
      require('karma-coverage'),
      require('@angular-devkit/build-angular/plugins/karma'),
    ],
    client: {
      jasmine: {},
      clearContext: false,
    },
    jasmineHtmlReporter: {
      suppressAll: true,
    },
    coverageReporter: {
      dir: require('path').join(__dirname, './coverage/'),
      subdir: '.',
      reporters: [
        { type: 'html' },
        { type: 'text-summary' },
      ],
    },
    reporters: ['progress', 'kjhtml'],
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: ['Chrome'],
    singleRun: false,
    restartOnFileChange: true,
  });
};
```

---

## Writing Tests

### Best Practices

#### 1. Use Descriptive Names
```typescript
// ❌ Bad
it('should work', () => {});

// ✅ Good
it('should return user profile when authenticated', () => {});
```

#### 2. Use AAA Pattern (Arrange, Act, Assert)
```typescript
it('should create user on first login', () => {
  // Arrange - Set up test data
  const email = 'test@example.com';
  const name = 'Test User';

  // Act - Execute the function
  const user = userService.createIfNotExists(email, name);

  // Assert - Verify the result
  expect(user.email).toBe(email);
  expect(user.name).toBe(name);
});
```

#### 3. Mock External Dependencies
```typescript
it('should call API endpoint', (done) => {
  // Mock the HTTP request
  service.fetchData().subscribe(() => {
    const req = httpMock.expectOne('/api/data');
    expect(req.request.method).toBe('GET');
    req.flush({ data: 'test' });
    done();
  });
});
```

#### 4. Test Edge Cases
```typescript
it('should handle empty input', () => {
  expect(service.search('')).toEqual([]);
});

it('should handle null input', () => {
  expect(service.search(null)).toThrow();
});

it('should handle special characters', () => {
  const result = service.search('<script>alert("xss")</script>');
  expect(result).toBeEmpty();
});
```

#### 5. Keep Tests Independent
```typescript
// ❌ Bad - Tests depend on each other
beforeEach(() => {
  user = userService.create('test@example.com');
});

it('should fetch user', () => {
  expect(userService.get(user.id)).toBeDefined();
});

// ✅ Good - Each test is independent
it('should fetch user', () => {
  const user = userService.create('test@example.com');
  expect(userService.get(user.id)).toBeDefined();
});
```

---

## Test Coverage

### Coverage Goals

| Category | Target | Current |
|----------|--------|---------|
| **Statements** | 80% | TBD |
| **Branches** | 75% | TBD |
| **Functions** | 80% | TBD |
| **Lines** | 80% | TBD |

### Generate Coverage Report

#### Backend
```bash
cd backend
pytest --cov=src --cov-report=html --cov-report=term
```

#### Frontend
```bash
cd frontend
ng test --code-coverage --watch=false
```

### View Coverage Reports

**Backend**:
```bash
open backend/htmlcov/index.html  # macOS
xdg-open backend/htmlcov/index.html  # Linux
start backend/htmlcov/index.html  # Windows
```

**Frontend**:
```bash
open frontend/coverage/index.html  # macOS
xdg-open frontend/coverage/index.html  # Linux
start frontend/coverage/index.html  # Windows
```

---

## CI/CD Testing

### Cloud Build Pipeline

Tests run automatically on every push via Cloud Build:

```yaml
steps:
  # Backend Tests
  - name: 'gcr.io/cloud-builders/python'
    entrypoint: bash
    args:
      - -c
      - |
        cd backend
        pip install -e ".[dev]"
        pytest --cov=src --cov-report=term

  # Frontend Tests
  - name: 'node:20-alpine'
    entrypoint: npm
    args:
      - ci
      - --prefix=frontend
    env:
      - 'CI=true'

  - name: 'node:20-alpine'
    entrypoint: npm
    args:
      - run
      - 'test:ci'
      - --prefix=frontend
    env:
      - 'CI=true'
```

### Test Failure Handling

- **Build fails** if any test fails
- **Test output** available in Cloud Build logs
- **Coverage reports** uploaded as build artifacts
- **Notifications** sent on test failure

---

## Test Categories

### Unit Tests
- Test individual functions/methods in isolation
- Mock external dependencies
- Fast execution (< 1 second per test)
- Location: `tests/` and `.spec.ts` files

### Integration Tests
- Test multiple components working together
- Use real or test databases
- Test API endpoints
- Slower execution (1-10 seconds per test)
- Mark with `@pytest.mark.integration`

### End-to-End Tests
- Test complete user workflows
- Use real application instances
- Simulate user interactions
- Slowest execution (10+ seconds per test)
- Run separately or in CI only

### Performance Tests
- Measure response times
- Test with load
- Identify bottlenecks
- Mark with `@pytest.mark.slow`

---

## Debugging Tests

### Backend

```bash
# Run single test with print statements
pytest tests/test_search.py::test_search_query -s

# Run with Python debugger
pytest tests/test_search.py --pdb

# Run with detailed output
pytest -vv tests/test_search.py
```

### Frontend

```bash
# Run in debug mode (browser opens)
ng test --browsers=Chrome

# Use Chrome DevTools to debug
# 1. Open Chrome DevTools (F12)
# 2. Set breakpoints in code
# 3. Refresh the page
```

---

## Common Testing Issues

### Issue: Tests Pass Locally but Fail in CI

**Solution**:
- Ensure environment variables are set correctly
- Check for timezone dependencies
- Verify database state is isolated
- Use `--random-order-bucket=global` to randomize test order

### Issue: Flaky Tests

**Solution**:
- Increase timeout values
- Remove dependencies on external services
- Use proper mocking instead of real HTTP calls
- Avoid hardcoded delays

### Issue: Slow Test Suite

**Solution**:
- Split tests into unit, integration, and e2e
- Run unit tests on every save
- Run integration tests on commit
- Run e2e tests before release
- Use parallelization in CI

---

## Test Maintenance

### Regular Tasks

- **Weekly**: Run full test suite, review coverage
- **Monthly**: Update test dependencies, refactor brittle tests
- **Quarterly**: Review test strategy, update coverage targets

### Test Review Checklist

- [ ] New code has tests
- [ ] Tests are independent
- [ ] Tests use descriptive names
- [ ] Coverage hasn't decreased
- [ ] All tests pass locally
- [ ] No hardcoded delays or timeouts

---

## Document Information

- **Last Updated**: December 2025
- **Version**: 1.0
- **Applies To**: All test suites
- **Related Docs**: ARCHITECTURE.md, QUICK_START_GUIDE.md
