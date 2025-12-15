# Security

Authentication, authorization, and access control documentation.

## 📖 Guides in This Section

### [03_AUTHENTICATION_FLOW.md](../03-backend/03_AUTHENTICATION_FLOW.md)
**Authentication and identity management**

- Firebase Authentication setup
- OAuth2 bearer token flow
- JWT validation and verification
- Token refresh strategies
- Just-in-Time (JIT) user provisioning
- Custom claims and user metadata
- Session management
- Logout and account termination

**For:** Backend developers, security engineers, system administrators

**Location:** `docs/03-backend/03_AUTHENTICATION_FLOW.md`

---

### [03_FIRESTORE_SECURITY_RULES.md](03_FIRESTORE_SECURITY_RULES.md)
**Firestore database security rules**

- Security rule structure
- Document-level access control
- Collection-level permissions
- User isolation and multi-tenancy
- Role-based access patterns
- Custom claim validation
- Rate limiting and DOS prevention
- Testing rules locally

**For:** Backend developers, security engineers

---

### [01_ACCESS_CONTROL_AND_RBAC.md](01_ACCESS_CONTROL_AND_RBAC.md)
**Role-based access control (RBAC)**

- Role definitions (Admin, Editor, Viewer)
- Workspace-level permissions
- Feature-level access control
- Database-level enforcement
- API endpoint authorization
- Delegation and role inheritance
- Permission matrices by role
- Audit logging of access

**For:** System architects, security engineers, developers

---

## 🔐 Security Overview

### Authentication Flow
```
User Login
    ↓
Google/Firebase Auth
    ↓
Firebase returns ID token (JWT)
    ↓
Frontend stores token (secure cookie/localStorage)
    ↓
API requests include token in Authorization header
    ↓
Backend validates token with Firebase
    ↓
Backend creates/updates user in PostgreSQL (JIT)
    ↓
Backend checks workspace permissions
    ↓
Operation executed or denied
```

### Authorization
- **User Level:** Identified by Firebase UID and email
- **Workspace Level:** User role (Admin, Editor, Viewer)
- **Feature Level:** Specific permissions per feature
- **Data Level:** Firestore rules + PostgreSQL checks

---

## 👥 Roles & Permissions

For comprehensive role definitions and permissions, see [02_USER_ROLES_AND_PERMISSIONS.md](02_USER_ROLES_AND_PERMISSIONS.md)

| Role | Capabilities |
|------|-------------|
| **Admin** | Full workspace access, user management, settings |
| **Editor** | Create/edit media, manage templates, upload assets |
| **Viewer** | View media and assets (read-only) |

---

## 🛡️ Security Best Practices

1. **Never store secrets in code** - Use Secret Manager
2. **Use HTTPS for all connections** - Cloud Run enforces this
3. **Validate all user input** - Pydantic DTOs on backend
4. **Implement rate limiting** - Firestore rules provide this
5. **Audit access logs** - Cloud Logging integration
6. **Rotate credentials regularly** - Service account keys
7. **Use service accounts** - Never personal credentials
8. **Principle of least privilege** - Minimal IAM roles

---

## 📚 Learn More

- **Authentication:** [../03-backend/03_AUTHENTICATION_FLOW.md](../03-backend/03_AUTHENTICATION_FLOW.md)
- **User Roles & Permissions:** [02_USER_ROLES_AND_PERMISSIONS.md](02_USER_ROLES_AND_PERMISSIONS.md)
- **Access Control:** [01_ACCESS_CONTROL_AND_RBAC.md](01_ACCESS_CONTROL_AND_RBAC.md)
- **Database Rules:** [03_FIRESTORE_SECURITY_RULES.md](03_FIRESTORE_SECURITY_RULES.md)
- **API Security:** [../03-backend/02_API_ENDPOINTS_REFERENCE.md](../03-backend/02_API_ENDPOINTS_REFERENCE.md)
- **Infrastructure Security:** [../06-infrastructure/01_GCP_PROJECT_SETUP.md](../06-infrastructure/01_GCP_PROJECT_SETUP.md#security-best-practices)
