# LAW CMS — Legal Case Management System

[![Frontend](https://img.shields.io/badge/Frontend-law--cms--app.vercel.app-000?logo=vercel)](https://law-cms-app.vercel.app)
[![Backend](https://img.shields.io/badge/Backend-law--cms--backend.vercel.app-000?logo=vercel)](https://law-cms-backend.vercel.app)

**Live:** [https://law-cms-app.vercel.app](https://law-cms-app.vercel.app)  
**Login:** `advocate.sharma@legalcms.com` / `advocate123`

Full-stack case management platform — FastAPI backend + Flutter frontend, deployed on Vercel with Neon PostgreSQL.

## Features

- **Cases** — full CRUD with status tracking, client linking, and timeline
- **Clients** — manage client profiles with linked cases
- **Hearings** — schedule, filter (upcoming/today/past), interactive calendar with day-tap filtering
- **Documents** — upload with descriptions, batch delete, inline viewer (image zoom, PDF download/new tab)
- **Dashboard** — stat cards (Total Cases, Active, Today's Hearings, Upcoming Week) that navigate to filtered views; recent cases and hearing tiles link to detail pages
- **Hover effects** — all clickable elements lift with elevated shadow and pointer cursor
- **Profile page**
- **JWT authentication** with backend cold-start warm-up on login

## Repo Structure

| Directory | Description |
|-----------|-------------|
| `legal-cms/backend/` | FastAPI REST API + SQLAlchemy ORM + Alembic migrations |
| `legal-cms/frontend/` | Flutter web client (Riverpod, GoRouter, Dio) |
| `legal-cms/ml/` | ML models (case classifier, NER extractor) |
| `legal-cms/scripts/` | Deployment helper scripts |

See [`legal-cms/README.md`](legal-cms/README.md) for full documentation.
