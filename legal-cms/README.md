# Smart Legal Case Management System

[![Frontend](https://img.shields.io/badge/Frontend-law--cms--app.vercel.app-000?logo=vercel)](https://law-cms-app.vercel.app)
[![Backend](https://img.shields.io/badge/Backend-law--cms--backend.vercel.app-000?logo=vercel)](https://law-cms-backend.vercel.app)
[![API Status](https://img.shields.io/badge/API-Health%20%E2%9C%94-brightgreen)](https://law-cms-backend.vercel.app/health)
[![Database](https://img.shields.io/badge/Database-Neon%20PostgreSQL-blueviolet)](https://neon.tech)

**Live:** [https://law-cms-app.vercel.app](https://law-cms-app.vercel.app)  
**API:** [https://law-cms-backend.vercel.app](https://law-cms-backend.vercel.app)  
**Login:** `advocate.sharma@legalcms.com` / `advocate123`

---

Legal case management platform with document management, hearings tracking, and case organisation.

**Stack:** FastAPI (Python 3.12) · Flutter · PostgreSQL 16 (Neon)

## Features

- Case lifecycle management (create, update, track status)
- Document upload with description and multi-select batch delete
- File storage in PostgreSQL (BYTEA) with optional S3 backend
- Hearing scheduling and calendar view
- Client management
- JWT-based authentication
- Responsive web UI (desktop + mobile)
- OCR text extraction for uploaded documents

## Structure

| Directory    | Description                       |
|-------------|-----------------------------------|
| `backend/`  | FastAPI REST API + SQLAlchemy ORM |
| `frontend/` | Flutter web client                |
| `ml/`       | ML models (case classifier)       |
| `scripts/`  | Deployment and utility scripts    |

---

## Local Development

### Prerequisites

- Python 3.11+
- PostgreSQL 15 (or Docker Desktop)
- Tesseract OCR (optional — for document OCR)
- Flutter SDK 3.22+ (optional — frontend)

### 1. Backend Setup

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate
# macOS / Linux
# source venv/bin/activate

pip install -r requirements.txt
```

### 2. Environment Variables

```bash
cp .env.example .env
# Edit .env to match your local setup
```

Key variables in `.env`:

| Variable                    | Default         | Description                          |
|----------------------------|-----------------|--------------------------------------|
| `POSTGRES_SERVER`          | `localhost`     | PostgreSQL host                      |
| `POSTGRES_PASSWORD`        | `postgres`      | PostgreSQL password                  |
| `SECRET_KEY`               | —               | JWT signing secret (min 32 chars)    |
| `ENVIRONMENT`              | `dev`           | `dev`, `staging`, or `prod`          |
| `DEBUG`                    | `true`          | Enable debug logs (auto-disabled in prod) |
| `CORS_ORIGINS`             | `*`             | Comma-separated origins or `*`       |
| `TESSERACT_CMD`            | `/usr/bin/tesseract` | Path to Tesseract binary        |
| `SMTP_HOST`                | —               | SMTP server for email notifications  |
| `S3_BUCKET`                | —               | S3 bucket for production file uploads |

### 3. Run the Database

```bash
# Using Docker (recommended for dev)
docker compose up -d db
```

### 4. Run Migrations

```bash
cd backend
alembic upgrade head
```

### 5. Generate an Initial Migration (if models change)

```bash
cd backend
alembic revision --autogenerate -m "describe_changes"
alembic upgrade head
```

### 6. Start the Backend

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

API at `http://localhost:8000` — interactive docs at `http://localhost:8000/docs`.

### 7. Run the Frontend (optional)

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### 8. Run Tests

```bash
cd backend
pytest -v

# With coverage
pytest --cov=app --cov-report=term-missing

# With coverage threshold
pytest --cov=app --cov-fail-under=80
```

---

## ML Pipeline (optional)

```bash
cd ml
pip install -r requirements.txt
python train.py
```

---

## Full Docker Dev Environment

```bash
# Start all services (PostgreSQL + API + pgAdmin)
docker compose up -d

# Frontend via Docker
docker compose -f docker-compose.prod.yml up -d frontend nginx
```

Dev URLs:
- API: `http://localhost:8000`
- Docs: `http://localhost:8000/docs`
- pgAdmin: `http://localhost:5050` (email: `admin@legalcms.local`, password: `admin`)

---

## Deployment

### Vercel (Current)

Deployed on Vercel (serverless functions) with a Neon PostgreSQL database.  
File uploads are stored directly in PostgreSQL (`BYTEA` column) — no external storage needed.

| Service   | URL |
|-----------|-----|
| Frontend  | [https://law-cms-app.vercel.app](https://law-cms-app.vercel.app) |
| Backend   | [https://law-cms-backend.vercel.app](https://law-cms-backend.vercel.app) |
| Health    | [https://law-cms-backend.vercel.app/health](https://law-cms-backend.vercel.app/health) |

**Limitations (serverless):**
- OCR requires Tesseract binary (not available on Vercel)
- Background scheduler disabled (reminders/digests)
- Cold starts on first request (~5–10s)

### Render (Recommended for Full Features)

To deploy with persistent storage, OCR, and scheduled tasks:

1. Push to GitHub
2. Go to [render.com](https://render.com) → New Blueprint
3. Connect your repo and select `legal-cms/backend/render.yaml`
4. Set `SECRET_KEY` as an environment variable

### Docker (Self-Hosted)

#### Prerequisites

- Docker & Docker Compose on the host
- A domain name pointing to the server
- Ports 80 and 443 open

#### 1. Clone & Configure

```bash
git clone <repo-url> /opt/legal-cms
cd /opt/legal-cms

cp backend/.env.example backend/.env
nano backend/.env
```

**Required production `.env` changes:**
```ini
ENVIRONMENT=prod
DEBUG=false
SECRET_KEY=<generate-a-strong-64-char-key>
POSTGRES_PASSWORD=<strong-db-password>
CORS_ORIGINS=https://yourdomain.com
```

#### 2. Update Nginx Domain

Edit `docker/nginx.prod.conf` — replace `legalcms.example.com` with your domain.

#### 3. Obtain SSL Certificate

```bash
chmod +x scripts/init-ssl.sh
./scripts/init-ssl.sh yourdomain.com admin@yourdomain.com
```

#### 4. Deploy

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

#### 5. Verify

```bash
curl https://yourdomain.com/health
# → {"status": "ok"}
```

---

## Production Architecture

```
                         ┌──────────┐
                         │  Certbot  │
                         │ (renewal) │
                         └────┬─────┘
                              │
  ┌─────────┐   :443    ┌─────▼──────┐   :8000   ┌──────────┐   :5432   ┌──────────┐
  │  Client  │──────────►│   nginx     │──────────►│ Backend  │──────────►│PostgreSQL│
  │ (browser)│          │ (SSL term)  │           │ (uvicorn)│          │  (data)  │
  └─────────┘           └─────▲──────┘           └──────────┘           └──────────┘
                         :80  │                      │
                         ┌────┴─────┐                 │
                         │ Frontend │                 │
                         │ (Flutter │                 │
                         │  web)    │                 │
                         └──────────┘          ┌──────▼──────┐
                                                │  ./uploads  │
                                                │ (or S3)     │
                                                └─────────────┘
```

### File Storage

- **Development:** Local filesystem under `./uploads/`
- **Production:** Set `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` in `.env` for S3-backed storage

---

## Environment Reference

| Variable                    | Default             | Prod Required | Description                              |
|----------------------------|---------------------|---------------|------------------------------------------|
| `POSTGRES_SERVER`          | `localhost`         | yes           | PostgreSQL host                          |
| `POSTGRES_USER`            | `postgres`          | yes           | PostgreSQL user                          |
| `POSTGRES_PASSWORD`        | `postgres`          | yes           | PostgreSQL password                      |
| `POSTGRES_DB`              | `legal_cms`         | yes           | Database name                            |
| `SECRET_KEY`               | —                   | yes           | JWT signing secret (min 32 chars)        |
| `ALGORITHM`                | `HS256`             | —             | JWT algorithm                            |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60`             | —             | Token expiry                             |
| `TESSERACT_CMD`            | `/usr/bin/tesseract`| —             | Tesseract OCR binary path                |
| `UPLOAD_DIR`               | `./uploads`         | —             | Local upload directory                   |
| `MAX_UPLOAD_SIZE_MB`       | `50`                | —             | Max file upload size                     |
| `SMTP_HOST`                | —                   | optional      | SMTP server for email                    |
| `SMTP_PORT`                | `587`               | optional      | SMTP port                                |
| `SMTP_TLS`                 | `true`              | optional      | SMTP TLS flag                            |
| `SMTP_USER`                | —                   | optional      | SMTP username                            |
| `SMTP_PASSWORD`            | —                   | optional      | SMTP password                            |
| `SMTP_FROM`                | `noreply@legalcms.local` | optional | Sender email address               |
| `APP_NAME`                 | `Legal CMS`         | —             | Application name                         |
| `DEBUG`                    | `true`              | —             | Debug mode (always false in prod)        |
| `ENVIRONMENT`              | `dev`               | yes           | `dev`, `staging`, or `prod`              |
| `CORS_ORIGINS`             | `*`                 | yes           | Comma-separated allowed origins          |
| `S3_BUCKET`                | —                   | optional      | S3 bucket for file uploads               |
| `S3_ACCESS_KEY`            | —                   | optional      | S3 access key                            |
| `S3_SECRET_KEY`            | —                   | optional      | S3 secret key                            |
| `S3_REGION`                | `us-east-1`         | optional      | S3 region                                |
| `S3_ENDPOINT`              | —                   | optional      | S3 endpoint (custom/MinIO)               |

---

## Useful Commands

```bash
# Backend
uvicorn app.main:app --reload                     # Dev server
alembic upgrade head                               # Run migrations
alembic revision --autogenerate -m "desc"          # New migration
pytest -v                                           # Run tests
pytest --cov=app --cov-report=term-missing         # Coverage

# Docker
docker compose up -d                                # Start dev stack
docker compose -f docker-compose.prod.yml up -d     # Start prod stack
docker compose logs -f api                          # Tail backend logs

# ML
cd ml && python case_classifier/train.py            # Train classifier

# Certificates
./scripts/init-ssl.sh domain.com email@domain.com   # First-time SSL
# Renewal is automatic via certbot container
```
