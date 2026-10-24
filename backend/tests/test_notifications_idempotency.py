import pytest
from app.core.database import SessionLocal
from app.models.user import User, Role
from app.models.notification import Notification

def get_auth_token(client, email="rec_notif_test@opdconnect.com", password="Password@123"):
    reg_payload = {
        "email": email,
        "password": password,
        "full_name": "Notification Tester",
        "role_name": "receptionist"
    }
    client.post("/api/v1/auth/register", json=reg_payload)
    login_res = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert login_res.status_code == 200
    token = login_res.json()["data"]["access_token"]
    user_id = login_res.json()["data"]["user"]["id"]
    return {"Authorization": f"Bearer {token}"}, user_id


def test_notifications_endpoints(client):
    headers, user_id = get_auth_token(client)

    # 1. Check unread count (auto-seeds samples if none exist)
    unread_res = client.get("/api/v1/notifications/unread-count", headers=headers)
    assert unread_res.status_code == 200
    unread_count = unread_res.json()["data"]["unread_count"]
    assert unread_count >= 1

    # 2. List notifications
    list_res = client.get("/api/v1/notifications", headers=headers)
    assert list_res.status_code == 200
    items = list_res.json()["data"]
    assert len(items) >= 1
    notif_id = items[0]["id"]

    # 3. Mark single notification as read
    patch_res = client.patch(f"/api/v1/notifications/{notif_id}/read", headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["is_read"] is True

    # 4. Mark all read
    mark_all_res = client.post("/api/v1/notifications/mark-all-read", headers=headers)
    assert mark_all_res.status_code == 200

    # 5. Verify unread count is now 0
    unread_after = client.get("/api/v1/notifications/unread-count", headers=headers)
    assert unread_after.status_code == 200
    assert unread_after.json()["data"]["unread_count"] == 0


def test_backend_idempotency_replay(client):
    headers, _ = get_auth_token(client, email="idemp_test@opdconnect.com")

    idem_key = "test-idem-key-998877"
    patient_payload = {
        "full_name": "Idempotent Patient",
        "gender": "FEMALE",
        "phone": "+919112233445",
        "city": "Puducherry",
        "state": "Puducherry",
        "postal_code": "605001"
    }

    # First request with idempotency key
    res1 = client.post(
        "/api/v1/patients",
        json=patient_payload,
        headers={**headers, "X-Idempotency-Key": idem_key}
    )
    assert res1.status_code in (200, 201)
    uhid1 = res1.json()["data"]["uhid"]

    # Replayed second request with the same idempotency key and identical payload
    res2 = client.post(
        "/api/v1/patients",
        json=patient_payload,
        headers={**headers, "X-Idempotency-Key": idem_key}
    )
    # Must replay identical cached response without creating duplicate patient record or raising 409 conflict
    assert res2.status_code in (200, 201)
    uhid2 = res2.json()["data"]["uhid"]
    assert uhid1 == uhid2
