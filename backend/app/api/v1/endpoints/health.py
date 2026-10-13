from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.database import get_db
from app.core.config import settings
from app.core.responses import success_response

router = APIRouter()


@router.get("", summary="Health Check", description="Checks service availability and database connectivity")
def check_health(db: Session = Depends(get_db)):
    db_status = "healthy"
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    return success_response(
        data={
            "app_name": settings.PROJECT_NAME,
            "environment": settings.ENVIRONMENT,
            "database_status": db_status,
            "version": "1.0.0",
        },
        message="Service is healthy and operational"
    )
