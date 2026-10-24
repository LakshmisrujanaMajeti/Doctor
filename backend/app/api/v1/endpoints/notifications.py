from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, Path
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user
from app.core.exceptions import NotFoundException, ForbiddenException
from app.models.user import User
from app.models.notification import Notification
from app.schemas.notification import (
    NotificationRead,
    UnreadCountResponse,
    NotificationCreate,
)

router = APIRouter()


def _get_user_role(user: User) -> str:
    return (user.role.name if user.role else "").lower()


def _seed_sample_notifications_if_empty(db: Session, user: User) -> None:
    role = _get_user_role(user)
    existing_count = db.query(func.count(Notification.id)).filter(
        or_(
            Notification.user_id == user.id,
            Notification.target_role == role,
            Notification.target_role == "all",
        )
    ).scalar() or 0

    if existing_count == 0:
        now = datetime.utcnow()
        sample_notifications = [
            Notification(
                user_id=user.id,
                target_role=role,
                title="OPD Queue System Active",
                message="Live queue tokens and patient consultations are operating normally today.",
                category="queue",
                priority="NORMAL",
                is_read=False,
                target_route="/queue",
                entity_type="Queue",
            ),
            Notification(
                user_id=user.id,
                target_role=role,
                title="Critical Lab Alerts Configured",
                message="Panels flagging abnormal CBC or Blood Sugar automatically trigger MD priority badges.",
                category="lab",
                priority="PRIORITY",
                is_read=False,
                target_route="/laboratory" if role in ["doctor", "lab_tech", "admin"] else "/patient/portal",
                entity_type="LabOrder",
            ),
            Notification(
                user_id=user.id,
                target_role=role,
                title="Hospital Formulary Synchronized",
                message="Pharmacy stock catalog and active e-prescriptions are synced across all counters.",
                category="pharmacy",
                priority="NORMAL",
                is_read=False,
                target_route="/pharmacy" if role in ["pharmacist", "admin"] else "/billing",
                entity_type="Pharmacy",
            ),
        ]
        db.add_all(sample_notifications)
        db.commit()


@router.get("", summary="List Authorized User Notifications")
def get_notifications(
    category: Optional[str] = Query(None, description="Filter: all, alert, queue, lab, pharmacy, billing"),
    unread_only: bool = Query(False, description="Filter only unread items"),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _seed_sample_notifications_if_empty(db, current_user)
    role = _get_user_role(current_user)

    filter_conditions = [
        or_(
            Notification.user_id == current_user.id,
            Notification.target_role == role,
            Notification.target_role == "all",
        )
    ]

    if category and category.lower() != "all":
        filter_conditions.append(Notification.category == category.lower())

    if unread_only:
        filter_conditions.append(Notification.is_read == False)

    notifications = (
        db.query(Notification)
        .filter(and_(*filter_conditions))
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .all()
    )

    return success_response(
        data=[NotificationRead.model_validate(n).model_dump() for n in notifications],
        message="Notifications retrieved successfully",
    )


@router.get("/unread-count", summary="Get Unread Notifications Count")
def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _seed_sample_notifications_if_empty(db, current_user)
    role = _get_user_role(current_user)

    count = (
        db.query(func.count(Notification.id))
        .filter(
            and_(
                or_(
                    Notification.user_id == current_user.id,
                    Notification.target_role == role,
                    Notification.target_role == "all",
                ),
                Notification.is_read == False,
            )
        )
        .scalar()
        or 0
    )

    return success_response(
        data={"unread_count": count},
        message="Unread notifications count retrieved",
    )


@router.patch("/{notification_id}/read", summary="Mark Single Notification as Read")
def mark_notification_read(
    notification_id: str = Path(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    role = _get_user_role(current_user)
    notif = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notif:
        raise NotFoundException(f"Notification '{notification_id}' not found")

    # Authorize: Must be target user or role
    if notif.user_id and notif.user_id != current_user.id and notif.target_role not in [role, "all"]:
        raise ForbiddenException("Unauthorized to update this notification")

    notif.is_read = True
    notif.read_at = datetime.utcnow()
    db.commit()
    db.refresh(notif)

    return success_response(
        data=NotificationRead.model_validate(notif).model_dump(),
        message="Notification marked as read",
    )


@router.post("/mark-all-read", summary="Mark All Notifications as Read for User")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    role = _get_user_role(current_user)
    now = datetime.utcnow()

    db.query(Notification).filter(
        and_(
            or_(
                Notification.user_id == current_user.id,
                Notification.target_role == role,
                Notification.target_role == "all",
            ),
            Notification.is_read == False,
        )
    ).update(
        {"is_read": True, "read_at": now},
        synchronize_session=False,
    )
    db.commit()

    return success_response(
        data={"marked_all_read": True},
        message="All notifications marked as read",
    )
