from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from app.core.config import settings
from app.core.logging import logger

connect_args = {}
engine_kwargs = {}

db_url = settings.effective_database_url

if db_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False
else:
    engine_kwargs.update({
        "pool_size": 10,
        "max_overflow": 20,
        "pool_pre_ping": True,
        "pool_recycle": 300,  # 5-minute recycle for Neon DB serverless idle suspend
    })

try:
    engine = create_engine(
        db_url,
        connect_args=connect_args,
        **engine_kwargs
    )
except Exception as e:
    logger.error(f"Failed to create database engine for URL: {db_url}. Error: {e}")
    # Fallback to local SQLite if remote PostgreSQL is unreachable during network disruptions
    logger.warning("Falling back to local SQLite engine (./opd_connect.db)")
    fallback_url = "sqlite:///./opd_connect.db"
    engine = create_engine(fallback_url, connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
