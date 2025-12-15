# Testing

Testing strategies, frameworks, and best practices.

## 📖 Guides in This Section

### [TESTING_STRATEGY.md](TESTING_STRATEGY.md)
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

### [UNIT_TESTS.md](UNIT_TESTS.md) - *To be created*
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

### [INTEGRATION_TESTS.md](INTEGRATION_TESTS.md) - *To be created*
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

- **Testing:** [TESTING_STRATEGY.md](TESTING_STRATEGY.md)
- **Backend:** [03-backend/SERVICES_AND_ORM.md](../03-backend/SERVICES_AND_ORM.md)
- **Frontend:** [04-frontend/COMPONENTS.md](../04-frontend/COMPONENTS.md)
- **CI/CD:** [06-infrastructure/](../06-infrastructure/)
