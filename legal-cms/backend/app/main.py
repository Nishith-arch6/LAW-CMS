import logging
import os

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from starlette.routing import Mount

from app.core.config import settings
from app.core.database import Base, engine
from app.core.logging_middleware import RequestLoggingMiddleware
from app.core.rate_limiter import limiter
from app.models import User, Client, Case, Hearing, Document, CaseNote, BlacklistedToken, Notification
from app.routers import auth, cases, clients, documents, hearings, ml, notifications, search, users
from app.routers import export, case_notes, analytics, seed

FRONTEND_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "frontend", "build", "web")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    from app.ml.classifier import load_models
    load_models()
    from app.core.scheduler import start_scheduler
    start_scheduler()
    yield
    from app.core.scheduler import stop_scheduler
    stop_scheduler()
    await engine.dispose()


app = FastAPI(title=settings.app_name, debug=settings.effective_debug, lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.effective_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(RequestLoggingMiddleware)

app.include_router(auth.router, prefix="/api/auth", tags=["Auth"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(cases.router, prefix="/api/cases", tags=["Cases"])
app.include_router(clients.router, prefix="/api/clients", tags=["Clients"])
app.include_router(documents.router, prefix="/api/documents", tags=["Documents"])
app.include_router(hearings.router, prefix="/api/hearings", tags=["Hearings"])
app.include_router(ml.router, prefix="/api/ml", tags=["ML"])
app.include_router(notifications.router, prefix="/api/notifications", tags=["Notifications"])
app.include_router(search.router, prefix="/api/search", tags=["Search"])
app.include_router(export.router, prefix="/api/export", tags=["Export"])
app.include_router(case_notes.router, prefix="/api/notes", tags=["Case Notes"])
app.include_router(analytics.router, prefix="/api/analytics", tags=["Analytics"])
app.include_router(seed.router, prefix="/api", tags=["Seed"])


@app.get("/health")
async def health_check():
    return {"status": "ok"}


# Serve frontend SPA — catch-all for non-API routes
if os.path.isdir(FRONTEND_DIR):
    @app.get("/{full_path:path}", include_in_schema=False)
    async def serve_frontend(full_path: str):
        p = full_path.rstrip("/") or "index.html"
        f = os.path.join(FRONTEND_DIR, p)
        if os.path.isdir(f):
            f = os.path.join(f, "index.html")
        if os.path.isfile(f):
            return FileResponse(f)
        index = os.path.join(FRONTEND_DIR, "index.html")
        if os.path.isfile(index):
            return FileResponse(index, media_type="text/html")
        return {"error": "not found"}
