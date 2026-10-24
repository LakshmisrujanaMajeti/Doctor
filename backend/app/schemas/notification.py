from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class NotificationBase(BaseModel):
    title: str
    message: str
    category: str = "general"
    priority: str = "NORMAL"
    target_route: Optional[str] = None
    entity_type: Optional[str] = None
    entity_id: Optional[str] = None


class NotificationCreate(NotificationBase):
    user_id: Optional[str] = None
    target_role: Optional[str] = None


class NotificationRead(NotificationBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: Optional[str] = None
    target_role: Optional[str] = None
    is_read: bool
    read_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class UnreadCountResponse(BaseModel):
    unread_count: int
