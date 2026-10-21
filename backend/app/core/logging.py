import logging
import sys
import json
from datetime import datetime
from app.core.config import settings


class StructuredJsonFormatter(logging.Formatter):
    """
    JSON log formatter for production and structured log viewing.
    """
    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "environment": settings.ENVIRONMENT,
        }
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        if hasattr(record, "request_id"):
            log_entry["request_id"] = record.request_id
        return json.dumps(log_entry)


def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)

    # Clear existing handlers
    logger.handlers.clear()

    handler = logging.StreamHandler(sys.stdout)
    if settings.ENVIRONMENT == "production":
        handler.setFormatter(StructuredJsonFormatter())
    else:
        standard_format = "%(asctime)s | %(levelname)-8s | %(name)s:%(lineno)d - %(message)s"
        handler.setFormatter(logging.Formatter(standard_format))

    logger.addHandler(handler)

    # Suppress verbose noise from third parties
    logging.getLogger("uvicorn.access").setLevel(logging.INFO)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)


logger = logging.getLogger("opd_connect")
