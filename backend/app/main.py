from contextlib import asynccontextmanager
import logging
import traceback
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.db.session import init_db
from app.api.v1 import auth, stream, search, lyrics, feed, playlists

logging.basicConfig(level=logging.INFO)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database tables on startup
    try:
        await init_db()
        logging.info("Database initialized successfully.")
    except Exception as e:
        logging.error(f"Failed to initialize database: {e}\n{traceback.format_exc()}")
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    err_msg = traceback.format_exc()
    logging.error(f"Global exception: {err_msg}")
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc), "traceback": err_msg}
    )

# Enable CORS for Flutter Android emulator (10.0.2.2), Windows localhost, and LAN clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers under /api/v1
api_prefix = settings.API_V1_STR
app.include_router(auth.router, prefix=api_prefix)
app.include_router(stream.router, prefix=api_prefix)
app.include_router(search.router, prefix=api_prefix)
app.include_router(lyrics.router, prefix=api_prefix)
app.include_router(feed.router, prefix=api_prefix)
app.include_router(playlists.router, prefix=api_prefix)

@app.get("/")
async def root():
    return {
        "app": "Yuno Music Backend",
        "version": settings.VERSION,
        "docs": "/docs",
        "status": "healthy"
    }

@app.get("/health")
async def health():
    return {"status": "ok"}
