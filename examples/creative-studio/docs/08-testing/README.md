# Testing

Testing strategies, frameworks, and best practices.

## 📖 Guides in This Section

### [01_TESTING_STRATEGY_AND_PYRAMID.md](01_TESTING_STRATEGY_AND_PYRAMID.md)
**Overall testing approach and framework**

- Testing pyramid and strategy
- Unit testing with pytest (backend)
- Unit testing with Jasmine/Karma (frontend)
- Integration testing approach
- E2E testing with Cypress/Playwright
- Test fixtures and mocking
- Test data management
- Code coverage targets (80% statements, 75% branches)
- CI/CD testing pipeline
- Performance testing

**For:** All developers, QA engineers

---

### [02_UNIT_TESTS_GUIDE.md](02_UNIT_TESTS_GUIDE.md)
**Unit testing guide**

- Writing unit tests for services
- Mocking dependencies
- Parameterized tests
- Test fixtures and setup/teardown
- Backend: pytest patterns
- Frontend: Jasmine patterns
- Coverage reporting
- Continuous coverage tracking

**For:** Developers writing unit tests

---

### [03_INTEGRATION_TESTS_GUIDE.md](03_INTEGRATION_TESTS_GUIDE.md)
**Integration testing guide**

- Testing service interactions
- Database integration tests
- API endpoint testing
- Testing with real services (vs mocks)
- Test database setup and teardown
- Async test handling
- CI/CD integration test running

**For:** Backend developers, QA engineers

---

### [04_E2E_TESTS_GUIDE.md](04_E2E_TESTS_GUIDE.md)
**End-to-End testing guide**

- Overview of E2E testing tools (e.g., Cypress, Playwright)
- Writing E2E test scenarios
- Setting up test environments
- CI/CD integration for E2E tests

**For:** QA engineers, full-stack developers

---

## 🎯 Testing Strategy

### Testing Pyramid
```
         ▲
        / \
       /   \  E2E Tests (5%)
      /     \ - User workflows
     /───────\
    /         \  Integration (20%)
   /           \ - Component interaction
  /─────────────\
 /               \ Unit Tests (75%)
/                 \ - Individual functions
─────────────────────
```

---

## 📊 Test Coverage Goals

| Area | Target | Current |
|------|--------|---------|
| Backend Services | 80% | TBD |
| Backend API | 90% | TBD |
| Frontend Components | 75% | TBD |
| Overall | 80% | TBD |

---

## 🚀 Running Tests

### Backend
```bash
# Run all tests
pytest backend/tests

# Run with coverage
pytest backend/tests --cov=src

# Run specific test file
pytest backend/tests/test_services.py

# Run with verbose output
pytest backend/tests -v
```

### Frontend
```bash
# Run all tests
ng test

# Run with coverage
ng test --code-coverage

# Run in headless mode (CI)
ng test --browsers=ChromeHeadless --watch=false
```

---

## ✅ Testing Checklist

- [ ] All new features have tests
- [ ] Coverage targets met (80% statements)
- [ ] No flaky tests
- [ ] Tests run in CI/CD
- [ ] Tests pass locally before commit
- [ ] Edge cases tested
- [ ] Error cases tested

---

## 📚 Learn More

- **Testing:** [01_TESTING_STRATEGY_AND_PYRAMID.md](01_TESTING_STRATEGY_AND_PYRAMID.md)
- **Backend:** [03-backend/01_SERVICES_ARCHITECTURE.md](../03-backend/01_SERVICES_ARCHITECTURE.md)
- **Frontend:** [04-frontend/01_COMPONENTS_ARCHITECTURE.md](../04-frontend/01_COMPONENTS_ARCHITECTURE.md)
- **CI/CD:** [06-infrastructure/](../06-infrastructure/)
