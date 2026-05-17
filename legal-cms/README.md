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

**Stack:** FastAPI (Python 3.12) · Flutter 3.22+ · PostgreSQL 16 (Neon)

## Features

- Case lifecycle management (create, update, track status)
- Document upload with description field and multi-select batch delete
- **Document viewer** with inline image preview (pinch-to-zoom), PDF download, and "Open in new tab"
- Auto-open document viewer after successful upload
- File storage in PostgreSQL BYTEA (no external storage accounts needed)
- Hearing scheduling with interactive calendar — tap a date to see hearings
- Calendar shows upcoming, today, and past hearings with day-override filtering
- Dashboard with **clickable stat cards** (Total Cases → cases page, Today's Hearings → filtered hearings view)
- Dashboard recent cases and hearing tiles navigate to their respective detail pages
- **Hover effects** on all clickable elements (lift + elevation + pointer cursor)
- Client management
- JWT-based authentication
- Responsive web UI — desktop NavigationRail + mobile bottom NavigationBar
- Profile page
- Backend warm-up on login (reduces perceived cold-start delay)

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
- PostgreSQL 15+
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

### 3. Run Migrations

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

## Deployment

### Vercel (Production)

Deployed entirely on Vercel (serverless functions) with a Neon PostgreSQL database.  
File uploads are stored directly in PostgreSQL (`BYTEA` column) — no external storage needed.

| Service   | URL |
|-----------|-----|
| Frontend  | [https://law-cms-app.vercel.app](https://law-cms-app.vercel.app) |
| Backend   | [https://law-cms-backend.vercel.app](https://law-cms-backend.vercel.app) |
| Health    | [https://law-cms-backend.vercel.app/health](https://law-cms-backend.vercel.app/health) |

**Frontend deploy:**
```bash
cd frontend
flutter build web --dart-define=API_BASE_URL=https://law-cms-backend.vercel.app/api --release
cd build/web
npx vercel deploy --prod
```

**Backend deploy:** Automatic via Vercel Git integration on `master` branch pushes.

**Limitations (serverless):**
- OCR requires Tesseract binary (not available on Vercel)
- Background scheduler disabled (reminders/digests)
- Cold starts on first request (~5–15s) — login page fires a health-check ping to pre-warm the backend

### File Storage

- **Vercel (production):** PostgreSQL `BYTEA` column — files stored inline in the database
- **Development:** Local filesystem under `./uploads/`
- **S3 (optional):** Set `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` in `.env` for S3-backed storage

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

# Frontend
flutter build web --dart-define=API_BASE_URL=https://law-cms-backend.vercel.app/api --release
cd build/web && npx vercel deploy --prod

# ML
cd ml && python case_classifier/train.py            # Train classifier
```
