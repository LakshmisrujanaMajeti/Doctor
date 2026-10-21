from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


TimestampedSchema = BaseSchema
