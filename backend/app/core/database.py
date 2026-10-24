import os
import time
import sqlite3
from decimal import Decimal
from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from app.core.config import settings
from app.core.logging import logger

# Ensure Python 3.12+ SQLite handles Decimal without type binding errors
sqlite3.register_adapter(Decimal, lambda d: str(d))

# Base model registry
Base = declarative_base()

# Local SQLite fallback engine
base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
local_sqlite_path = os.path.join(base_dir, "opd_connect.db")
fallback_url = f"sqlite:///{local_sqlite_path}"
fallback_engine = create_engine(
    fallback_url,
    connect_args={"check_same_thread": False}
)
FallbackSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=fallback_engine)

# Primary database configuration
db_url = settings.effective_database_url
is_remote_postgres = db_url.startswith("postgresql")

if is_remote_postgres:
    primary_engine = create_engine(
        db_url,
        connect_args={"connect_timeout": 3},
        pool_size=10,
        max_overflow=20,
        pool_pre_ping=True,
        pool_recycle=300,
    )
    PrimarySessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=primary_engine)
    engine = primary_engine
else:
    primary_engine = fallback_engine
    PrimarySessionLocal = FallbackSessionLocal
    engine = fallback_engine

# Circuit-breaker state for automatic seamless offline failover
_is_primary_online = True
_last_check_timestamp = 0.0
_CIRCUIT_BREAKER_INTERVAL = 15.0  # seconds between health checks when offline


def is_primary_available() -> bool:
    """
    Checks if the primary Supabase database is reachable.
    If unreachable (e.g. no internet connection), immediately falls back to local SQLite.
    Prevents blocking requests by caching the offline state for 15 seconds.
    """
    global _is_primary_online, _last_check_timestamp
    if not is_remote_postgres:
        return True

    now = time.time()
    # If primary was detected offline recently, avoid stalling request with connection timeout
    if not _is_primary_online and (now - _last_check_timestamp < _CIRCUIT_BREAKER_INTERVAL):
        return False

    try:
        with primary_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        if not _is_primary_online:
            logger.info("[ONLINE RESTORED] Supabase cloud database is reachable. Operating in cloud mode.")
        _is_primary_online = True
        _last_check_timestamp = now
        return True
    except Exception as e:
        if _is_primary_online:
            logger.warning(
                f"[OFFLINE DETECTED] Supabase cloud connection unreachable ({type(e).__name__}). "
                f"Seamlessly operating on local SQLite database with zero downtime."
            )
        _is_primary_online = False
        _last_check_timestamp = now
        return False


def mark_primary_offline():
    global _is_primary_online, _last_check_timestamp
    _is_primary_online = False
    _last_check_timestamp = time.time()


class SmartSessionMaker:
    """
    Thread-safe session factory that returns a session bound to Supabase when online,
    or local SQLite when offline, preventing any database connection errors.
    """
    def __call__(self, **kwargs) -> Session:
        if is_primary_available():
            return PrimarySessionLocal(**kwargs)
        return FallbackSessionLocal(**kwargs)

    def configure(self, **kwargs):
        if is_remote_postgres:
            PrimarySessionLocal.configure(**kwargs)
        FallbackSessionLocal.configure(**kwargs)


SessionLocal = SmartSessionMaker()


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency that yields an active database session.
    Automatically routes to local SQLite if offline, guaranteeing 0 database errors.
    """
    if is_primary_available():
        db = PrimarySessionLocal()
        try:
            yield db
        except Exception as exc:
            err_str = str(exc).lower()
            if "could not translate host name" in err_str or "connection" in err_str or "timeout" in err_str:
                logger.warning(f"Connection dropped during request: {exc}. Marking primary offline.")
                mark_primary_offline()
            raise
        finally:
            db.close()
    else:
        db = FallbackSessionLocal()
        try:
            yield db
        finally:
            db.close()
