from datetime import datetime
from sqlalchemy import Column, String, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class SystemConfig(Base, TimestampMixin):
    __tablename__ = "system_configs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    config_key = Column(String(100), unique=True, nullable=False, index=True)
    config_value = Column(Text, nullable=False)
    category = Column(String(50), default="GENERAL", nullable=False, index=True)  # GENERAL, HOSPITAL, BILLING, BACKUP, APPOINTMENT
    description = Column(String(255), nullable=True)

    updated_by_user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    updated_by = relationship("User")
