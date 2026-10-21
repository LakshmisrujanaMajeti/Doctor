from datetime import datetime
from typing import Any, Optional, Dict, Generic, TypeVar
from pydantic import BaseModel, Field

DataT = TypeVar("DataT")


class ResponseMeta(BaseModel):
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat() + "Z")
    version: str = "v1"


class ApiResponse(BaseModel, Generic[DataT]):
    status: str = "success"
    message: str = "Operation completed successfully"
    data: Optional[DataT] = None
    meta: ResponseMeta = Field(default_factory=ResponseMeta)


class ErrorDetail(BaseModel):
    code: str
    details: Optional[Any] = None


class ApiErrorResponse(BaseModel):
    status: str = "error"
    message: str
    error: ErrorDetail
    meta: ResponseMeta = Field(default_factory=ResponseMeta)


def success_response(
    data: Any = None,
    message: str = "Operation completed successfully",
    status_code: int = 200,
    meta: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    response_meta = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "version": "v1",
    }
    if meta:
        response_meta.update(meta)

    return {
        "status": "success",
        "message": message,
        "data": data,
        "meta": response_meta,
    }
