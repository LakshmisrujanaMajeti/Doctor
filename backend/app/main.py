import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.core.logging import setup_logging, logger
from app.core.exceptions import AppException
from app.core.responses import success_response
from app.core.database import Base, engine
import app.models  # noqa: F401 - ensure all schemas register on Base.metadata
from app.api.v1.api import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize logging
    setup_logging()
    logger.info(f"Starting {settings.PROJECT_NAME} in {settings.ENVIRONMENT} mode...")
    
    # Create tables if using SQLite or initial dev run
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database schemas verified/created successfully.")
    except Exception as e:
        logger.warning(f"Could not auto-create tables during startup: {e}. Alembic migrations should be used for PostgreSQL.")

    yield
    logger.info(f"Shutting down {settings.PROJECT_NAME}...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Comprehensive Outpatient Department (OPD), hospital workflow, and medical records management API.",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request timing and structured logger middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start_time) * 1000, 2)
    logger.info(
        f"{request.method} {request.url.path} -> {response.status_code} ({duration_ms}ms)"
    )
    return response


# Centralized Exception Handlers
@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "message": exc.message,
            "error": {
                "code": exc.code,
                "details": exc.details,
            },
            "meta": {
                "path": request.url.path,
                "version": "v1"
            }
        }
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = []
    for err in exc.errors():
        loc = " -> ".join([str(x) for x in err.get("loc", [])])
        errors.append({"field": loc, "message": err.get("msg")})

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "status": "error",
            "message": "Request validation failed",
            "error": {
                "code": "VALIDATION_ERROR",
                "details": errors,
            },
            "meta": {
                "path": request.url.path,
                "version": "v1"
            }
        }
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "message": exc.detail if isinstance(exc.detail, str) else "HTTP error occurred",
            "error": {
                "code": f"HTTP_{exc.status_code}",
                "details": exc.detail if not isinstance(exc.detail, str) else None,
            },
            "meta": {
                "path": request.url.path,
                "version": "v1"
            }
        }
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception(f"Unhandled exception on {request.method} {request.url.path}: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "status": "error",
            "message": "An internal server error occurred",
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "details": str(exc) if settings.DEBUG else None,
            },
            "meta": {
                "path": request.url.path,
                "version": "v1"
            }
        }
    )


# Root Health Check
@app.get("/health", tags=["Health"])
def root_health():
    return success_response(
        data={"app": settings.PROJECT_NAME, "status": "running"},
        message="Service is healthy"
    )


# Mount API v1
app.include_router(api_router, prefix=settings.API_V1_PREFIX)
