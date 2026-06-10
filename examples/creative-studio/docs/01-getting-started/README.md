# Getting Started

Quick setup guides for local development and initial configuration.

## 📖 Guides in This Section

### [01_QUICK_START.md](01_QUICK_START.md)
**Local development setup and first steps**

- Clone and setup repository
- Local environment configuration
- Firebase and Google OAuth setup
- Running the application locally
- Testing the setup

**Time to complete:** 15-30 minutes
**For:** All developers starting the project

---

### [02_ENVIRONMENTS_SETUP.md](02_ENVIRONMENTS_SETUP.md)
**Environment variables and configuration**

- All backend environment variables
- Frontend environment configuration
- Environment-specific settings (dev, staging, production)
- Secret vs. non-secret variables
- Cloud SQL PostgreSQL configuration
- Firebase setup instructions
- OAuth credentials configuration

**For:** Developers configuring environments, DevOps engineers

---

### [03_DOCKER_LOCAL_SETUP.md](03_DOCKER_LOCAL_SETUP.md)
**Docker Compose for local development**

- Docker Compose setup
- Building Docker images
- Docker networking and service communication
- Volume mounting and live reload
- Backend Dockerfile (Python 3.12, uv)
- Frontend Dockerfile (Node 20, nginx)
- Debugging in containers

**For:** Full-stack developers, DevOps engineers

---

## 🚀 Quick Start (30 seconds)

```bash
# 1. Clone repository
git clone <repo>
cd creative-studio

# 2. Setup environment
cd backend
cp .env.template .env
# Edit .env with your GCP Project ID

# 3. Run with Docker
docker-compose up

# 4. Access application
# Frontend: http://localhost:4200
# Backend:  http://localhost:8080/api
```

👉 For detailed steps, see **[01_QUICK_START.md](01_QUICK_START.md)**

---

## ⚙️ Next Steps

1. **Setup environment:** Read [02_ENVIRONMENTS_SETUP.md](02_ENVIRONMENTS_SETUP.md)
2. **Run locally:** Follow [01_QUICK_START.md](01_QUICK_START.md)
3. **Learn architecture:** Go to [02-architecture/](../02-architecture/)
4. **Start developing:**
   - Backend? → [03-backend/](../03-backend/)
   - Frontend? → [04-frontend/](../04-frontend/)

---

## 📋 Troubleshooting

**Port already in use?**
```bash
# Change ports in docker-compose.yml
ports:
  - "4200:4200"  # Change first number
  - "8080:8080"  # Change first number
```

**Docker not running?**
```bash
# Start Docker daemon
docker daemon

# Or restart Docker service
systemctl restart docker
```

**Firebase auth not working?**
- Check GOOGLE_TOKEN_AUDIENCE in .env
- Verify OAuth credentials in Google Cloud Console
- See [02_ENVIRONMENTS_SETUP.md](02_ENVIRONMENTS_SETUP.md) for setup

**Database connection errors?**
- Verify INSTANCE_CONNECTION_NAME in .env
- For local: Use `localhost:5432`
- See [02_ENVIRONMENTS_SETUP.md#cloud-sql-postgresql-setup](02_ENVIRONMENTS_SETUP.md) for details

---

## 📚 Learn More

- **Architecture:** [02-architecture/01_SYSTEM_DESIGN.md](../02-architecture/01_SYSTEM_DESIGN.md)
- **Backend services:** [03-backend/01_SERVICES_ARCHITECTURE.md](../03-backend/01_SERVICES_ARCHITECTURE.md)
- **API reference:** [03-backend/02_API_ENDPOINTS_REFERENCE.md](../03-backend/02_API_ENDPOINTS_REFERENCE.md)
- **Deployment:** [06-infrastructure/01_GCP_PROJECT_SETUP.md](../06-infrastructure/01_GCP_PROJECT_SETUP.md)
