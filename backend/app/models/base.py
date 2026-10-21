from datetime import datetime
import uuid
from sqlalchemy import Column, String, DateTime
from app.core.database import Base


class TimestampMixin:
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


def generate_uuid() -> str:
    return str(uuid.uuid4())
