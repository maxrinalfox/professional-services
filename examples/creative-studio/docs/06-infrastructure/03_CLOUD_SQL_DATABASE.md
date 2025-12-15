# Cloud SQL PostgreSQL Setup

This document details the setup and configuration of Google Cloud SQL for PostgreSQL, which serves as the primary relational database for the Creative Studio backend. It covers both the application's connection mechanism and the infrastructure provisioning using Terraform.

## 🚀 Overview

Cloud SQL provides a fully managed relational database service. For the Creative Studio, a PostgreSQL instance is used to store structured data such as user profiles, workspace information, media item metadata, and more. The application connects to Cloud SQL using the Cloud SQL Python Connector for secure and efficient communication.

## 🛠️ Application Connection (`backend/src/database.py`)

The `backend/src/database.py` file is responsible for establishing and managing the database connection using SQLAlchemy AsyncORM and the Cloud SQL Python Connector.

### Key Components:
- **SQLAlchemy AsyncORM**: Provides an asynchronous Object Relational Mapper for interacting with the PostgreSQL database.
- **`google.cloud.sql.connector.Connector`**: A client library that handles secure connections to Cloud SQL instances without requiring an authorized network or SSL certificates. It works by managing a local proxy process.
- **`get_conn_string()`**: A helper function that dynamically constructs the database connection string based on environment variables, distinguishing between local development (direct PostgreSQL connection) and Cloud SQL deployments (using the connector).
- **`DatabaseConnector` (Singleton)**: Manages the lifecycle of the Cloud SQL Connector instance, ensuring it's properly initialized and cleaned up.
- **`get_connection()`**: Provides the connection object for `create_async_engine`, routing through the Cloud SQL Connector when deployed to GCP or using a direct connection for local development.
- **`AsyncSessionLocal`**: The session factory for creating database sessions within the application.

### Connection Logic Summary:

1.  **Environment-aware connection**: The application checks environment variables (`INSTANCE_CONNECTION_NAME`, `USE_CLOUD_SQL_AUTH_PROXY`) to determine the connection method.
2.  **Cloud SQL Connector**: For GCP deployments, it utilizes the `Connector` to securely connect to the Cloud SQL instance using its instance connection name.
3.  **Local PostgreSQL**: For local development, it can connect directly to a PostgreSQL instance (e.g., via Docker Compose) using a standard connection string.

**Excerpt from `backend/src/database.py`:**
```python
from google.cloud.sql.connector import Connector, IPTypes
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from src.config.config_service import config_service

# ... (Base and get_db definitions) ...

def get_conn_string() -> str:
    # ... (connection string logic) ...

class DatabaseConnector:
    # ... (singleton connector management) ...

async def get_connection():
    # ... (connection logic using connector or direct) ...

# Create the Async Engine
if config_service.INSTANCE_CONNECTION_NAME and not config_service.USE_CLOUD_SQL_AUTH_PROXY:
    # Use the Cloud SQL Python Connector
    engine = create_async_engine(
        "postgresql+asyncpg://",
        async_creator=get_connection,
        echo=config_service.LOG_LEVEL == "DEBUG",
    )
else:
    # Use standard connection string (Local)
    engine = create_async_engine(
        get_conn_string(),
        echo=config_service.LOG_LEVEL == "DEBUG",
    )

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)
```

## 🌍 Infrastructure Provisioning (Terraform)

The Cloud SQL PostgreSQL instance is provisioned and managed using Terraform, as defined in the `infra/modules/postgresql/` directory.

### Key Terraform Files:
- **`main.tf`**: Defines the Cloud SQL instance resource (`google_sql_database_instance`), including settings like database version, tier, storage, and IP configuration. It also creates the initial PostgreSQL database (`google_sql_database`) and user (`google_sql_user`).
- **`variables.tf`**: Declares input variables for the PostgreSQL module, allowing for flexible configuration (e.g., `project_id`, `region`, `db_version`, `tier`, `db_name`, `db_user`, `db_password`).
- **`outputs.tf`**: Defines output values from the PostgreSQL module, such as the `instance_connection_name` and `database_url_secret_name`, which are crucial for the application's configuration.

### Example Terraform Usage (from `infra/environments/dev-infra-example/main.tf`):

```terraform
module "postgresql" {
  source  = "../../modules/postgresql"
  project_id = var.project_id
  region = var.region
  db_version = "POSTGRES_14"
  tier = "db-f1-micro"
  db_name = "creative-studio-db"
  db_user = "creative-studio-user"
  # db_password is typically retrieved from a secrets manager
  # or set via an environment variable in a CI/CD pipeline
}

output "instance_connection_name" {
  value = module.postgresql.instance_connection_name
}

output "database_url_secret_name" {
  value = module.postgresql.database_url_secret_name
}
```

## ⚙️ Configuration

To connect the backend application to Cloud SQL, the following environment variables (or secrets) must be configured in your Cloud Run service or local environment:

-   `INSTANCE_CONNECTION_NAME`: The connection name of your Cloud SQL instance (e.g., `project-id:region:instance-name`). This is an output from the Terraform module.
-   `DB_NAME`: The name of the database (e.g., `creative-studio-db`).
-   `DB_USER`: The database user (e.g., `creative-studio-user`).
-   `DB_PASS`: The password for the database user. **(Should be stored securely in Secret Manager and injected into Cloud Run)**
-   `DB_HOST`: For local testing *without* the Cloud SQL Connector, this would be `localhost` or the Docker service name (e.g., `postgres`).
-   `DB_PORT`: For local testing, this would typically be `5432`.
-   `USE_CLOUD_SQL_AUTH_PROXY`: Set to `True` if you are running locally and explicitly using the Cloud SQL Auth Proxy client (not the Python Connector library).

## ✅ Local Development with Cloud SQL

For local development, you have two primary options:

1.  **Local PostgreSQL via Docker Compose**: Run a local PostgreSQL instance using `docker-compose up postgres` and configure your `.env` file with `DB_HOST=localhost`, `DB_PORT=5432` (or the mapped port), and the corresponding user/password.
2.  **Cloud SQL Auth Proxy**: Use the Cloud SQL Auth Proxy client to connect to a remote Cloud SQL instance from your local machine. In this case, set `USE_CLOUD_SQL_AUTH_PROXY=True` and configure `DB_HOST` to `127.0.0.1` and `DB_PORT` to `5432` (or the proxy's listening port).

## ⚠️ Troubleshooting

-   **Connection Errors**: Ensure `INSTANCE_CONNECTION_NAME`, `DB_NAME`, `DB_USER`, and `DB_PASS` environment variables are correctly set in your Cloud Run service.
-   **Permission Issues**: Verify that the Cloud Run service account has the `Cloud SQL Client` role (`roles/cloudsql.client`) to connect to the Cloud SQL instance.
-   **Firewall Rules**: If using public IP for Cloud SQL, ensure your Cloud Run service's egress IP addresses (or a static egress IP configured via VPC Access Connector) are authorized in the Cloud SQL instance's network settings. Consider using Private IP for enhanced security.