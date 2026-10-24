import hashlib
import json
import threading
import time
from typing import Optional, Dict, Any, Tuple
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)


class IdempotencyRecord:
    def __init__(self, key: str, user_id: str, endpoint: str, request_hash: str):
        self.key = key
        self.user_id = user_id
        self.endpoint = endpoint
        self.request_hash = request_hash
        self.status = "IN_PROGRESS"  # IN_PROGRESS, COMPLETED, FAILED
        self.response_data: Optional[Dict[str, Any]] = None
        self.response_code: int = 200
        self.created_at: float = time.time()
        self.completed_at: Optional[float] = None


class IdempotencyManager:
    """Thread-safe server-side idempotency guard for non-repeatable create operations."""

    def __init__(self, ttl_seconds: int = 86400):
        self._lock = threading.Lock()
        self._store: Dict[str, IdempotencyRecord] = {}
        self._ttl_seconds = ttl_seconds

    def _hash_payload(self, payload: Any) -> str:
        if isinstance(payload, str):
            payload_bytes = payload.encode("utf-8")
        elif isinstance(payload, bytes):
            payload_bytes = payload
        else:
            try:
                payload_bytes = json.dumps(payload, sort_keys=True, default=str).encode("utf-8")
            except Exception:
                payload_bytes = str(payload).encode("utf-8")
        return hashlib.sha256(payload_bytes).hexdigest()

    def acquire(
        self,
        key: Optional[str],
        user_id: str,
        endpoint: str,
        payload: Any = None,
    ) -> Tuple[bool, Optional[Dict[str, Any]], int]:
        """
        Check if an idempotency key can proceed or return cached response.
        Returns:
            (can_proceed: bool, cached_response: Optional[dict], response_code: int)
        """
        if not key or not key.strip():
            # No idempotency key provided; operation proceeds normally
            return (True, None, 200)

        clean_key = key.strip()
        composite_key = f"{user_id}:{clean_key}"
        req_hash = self._hash_payload(payload)
        now = time.time()

        with self._lock:
            # Clean expired keys periodically
            self._prune_expired_locked(now)

            if composite_key in self._store:
                record = self._store[composite_key]

                # Check payload match
                if record.request_hash != req_hash:
                    logger.warning(f"Idempotency key '{clean_key}' reused with mismatched payload by user {user_id}")
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="Idempotency key was previously used with a different request payload.",
                    )

                if record.status == "IN_PROGRESS":
                    # Lock concurrency: ongoing request
                    # If stuck > 60 seconds, treat as stale and allow retry
                    if now - record.created_at < 60:
                        raise HTTPException(
                            status_code=status.HTTP_409_CONFLICT,
                            detail="A duplicate request with this idempotency key is already in progress. Please retry in a moment.",
                            headers={"Retry-After": "2"},
                        )
                    else:
                        logger.warning(f"Expiring stale in-progress lock for idempotency key '{clean_key}'")

                elif record.status == "COMPLETED":
                    # Cache hit: return identical original response
                    logger.info(f"⚡ [IDEMPOTENCY HIT] Returning cached response for key '{clean_key}'")
                    return (False, record.response_data, record.response_code)

            # Record new in-progress operation
            rec = IdempotencyRecord(clean_key, user_id, endpoint, req_hash)
            self._store[composite_key] = rec
            return (True, None, 200)

    def store_result(
        self,
        key: Optional[str],
        user_id: str,
        response_data: Dict[str, Any],
        status_code: int = 200,
    ) -> None:
        if not key or not key.strip():
            return

        from fastapi.encoders import jsonable_encoder
        encoded_data = jsonable_encoder(response_data)

        composite_key = f"{user_id}:{key.strip()}"
        with self._lock:
            if composite_key in self._store:
                record = self._store[composite_key]
                record.status = "COMPLETED"
                record.response_data = encoded_data
                record.response_code = status_code
                record.completed_at = time.time()

    def mark_failed(self, key: Optional[str], user_id: str) -> None:
        if not key or not key.strip():
            return

        composite_key = f"{user_id}:{key.strip()}"
        with self._lock:
            # On failure, remove or mark failed so legitimate retry is permitted
            self._store.pop(composite_key, None)

    def _prune_expired_locked(self, now: float) -> None:
        expired = [
            k for k, rec in self._store.items()
            if (now - rec.created_at) > self._ttl_seconds
        ]
        for k in expired:
            del self._store[k]


# Global singleton instance
idempotency_manager = IdempotencyManager(ttl_seconds=86400)
