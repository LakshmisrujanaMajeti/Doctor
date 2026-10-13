def test_register_and_login_flow(client):
    # Register
    reg_payload = {
        "email": "testnurse@opdconnect.com",
        "password": "Password@123",
        "full_name": "Nurse Joy",
        "role_name": "nurse",
        "phone": "+1555111222"
    }
    reg_res = client.post("/api/v1/auth/register", json=reg_payload)
    assert reg_res.status_code == 200
    reg_data = reg_res.json()
    assert reg_data["status"] == "success"
    assert reg_data["data"]["email"] == "testnurse@opdconnect.com"

    # Login
    login_payload = {
        "email": "testnurse@opdconnect.com",
        "password": "Password@123"
    }
    login_res = client.post("/api/v1/auth/login", json=login_payload)
    assert login_res.status_code == 200
    login_data = login_res.json()
    assert "access_token" in login_data["data"]
    assert "refresh_token" in login_data["data"]

    access_token = login_data["data"]["access_token"]
    refresh_token = login_data["data"]["refresh_token"]

    # Test /me with access token
    headers = {"Authorization": f"Bearer {access_token}"}
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["data"]["email"] == "testnurse@opdconnect.com"

    # Test Refresh Token Rotation
    refresh_res = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert refresh_res.status_code == 200
    new_tokens = refresh_res.json()["data"]
    assert "access_token" in new_tokens
    assert "refresh_token" in new_tokens
    new_refresh_token = new_tokens["refresh_token"]
    assert new_refresh_token != refresh_token

    # Re-using old refresh token must be rejected (reuse detection)
    stale_res = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert stale_res.status_code == 401
