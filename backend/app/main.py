from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import Base, engine

# Import all models to ensure Base metadata collects them
import app.users.models
import app.facilities.models
import app.workers.models
import app.tickets.models
import app.ratings.models
import app.sla.models
import app.notifications.models
import app.history.models
import app.qr.models

# Import routers
from app.auth.router import router as auth_router
from app.users.router import router as users_router
from app.facilities.router import router as facilities_router
from app.tickets.router import router as tickets_router
from app.ratings.router import router as ratings_router
from app.workers.router import router as workers_router
from app.notifications.router import router as notifications_router
from app.sla.router import router as sla_router
from app.analytics.router import router as analytics_router
from app.history.router import router as history_router
from app.qr.router import router as qr_router
from app.face_verification.router import router as face_verification_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize all database tables
    Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Smart Public Sanitation & Drinking Water Management System - Civic Platform API",
    lifespan=lifespan
)

# Configure CORS for Flutter Web, Android, iOS, Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount all API V1 routers
api_prefix = settings.API_V1_PREFIX
app.include_router(auth_router, prefix=api_prefix)
app.include_router(users_router, prefix=api_prefix)
app.include_router(facilities_router, prefix=api_prefix)
app.include_router(tickets_router, prefix=api_prefix)
app.include_router(ratings_router, prefix=api_prefix)
app.include_router(workers_router, prefix=api_prefix)
app.include_router(notifications_router, prefix=api_prefix)
app.include_router(sla_router, prefix=api_prefix)
app.include_router(analytics_router, prefix=api_prefix)
app.include_router(history_router, prefix=api_prefix)
app.include_router(qr_router, prefix=api_prefix)
app.include_router(face_verification_router, prefix=api_prefix)

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "app_name": settings.APP_NAME,
        "version": settings.APP_VERSION
    }
