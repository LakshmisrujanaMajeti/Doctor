import urllib.request
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.database import get_db
from app.core.config import settings
from app.core.responses import success_response

router = APIRouter()


@router.get("", summary="Health Check", description="Checks service availability, database, and Supabase connectivity")
def check_health(db: Session = Depends(get_db)):
    db_status = "healthy"
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    # Verify Supabase Cloud Connection
    supabase_status = "not_configured"
    supabase_details = {}
    if settings.SUPABASE_URL and settings.SUPABASE_ANON_KEY:
        try:
            req = urllib.request.Request(
                f"{settings.SUPABASE_URL.rstrip('/')}/auth/v1/settings",
                headers={"apikey": settings.SUPABASE_ANON_KEY, "User-Agent": "OPD-Connect-Backend"}
            )
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                if resp.status == 200:
                    supabase_status = "connected"
                    supabase_details = {
                        "url": settings.SUPABASE_URL,
                        "auth_service": "online",
                        "status_code": resp.status,
                    }
                else:
                    supabase_status = f"unexpected_status: {resp.status}"
        except Exception as se:
            supabase_status = f"error: {str(se)}"

    return success_response(
        data={
            "app_name": settings.PROJECT_NAME,
            "environment": settings.ENVIRONMENT,
            "database_status": db_status,
            "supabase_status": supabase_status,
            "supabase_details": supabase_details,
            "version": "1.0.0",
        },
        message="Service is healthy and operational"
    )

