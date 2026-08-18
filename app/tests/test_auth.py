def _valid_register_payload(email, password="pass1234!"):
    return {
        "email": email,
        "password": password,
        "password_confirm": password,
        "name": "테스트유저",
        "phone": "01011112222",
        "postcode": "12345",
        "address": "서울시 테스트구 테스트로",
        "address_detail": "1층",
        "terms_agreed": True,
        "privacy_agreed": True,
    }


def test_register_success(client):
    res = client.post("/auth/register", json=_valid_register_payload("new@example.com"))
    assert res.status_code == 201
    body = res.json()
    assert body["email"] == "new@example.com"
    assert body["is_admin"] is False


def test_register_duplicate_email_fails(client):
    client.post("/auth/register", json=_valid_register_payload("dup@example.com"))
    res = client.post("/auth/register", json=_valid_register_payload("dup@example.com"))
    assert res.status_code == 400


def test_login_success(client):
    client.post("/auth/register", json=_valid_register_payload("login@example.com"))
    res = client.post(
        "/auth/login",
        data={"username": "login@example.com", "password": "pass1234!"},
    )
    assert res.status_code == 200
    assert "access_token" in res.json()


def test_login_wrong_password_fails(client):
    client.post("/auth/register", json=_valid_register_payload("login2@example.com"))
    res = client.post(
        "/auth/login",
        data={"username": "login2@example.com", "password": "wrongpass1!"},
    )
    assert res.status_code == 401


def test_me_requires_auth(client):
    res = client.get("/auth/me")
    assert res.status_code == 401


def test_me_returns_current_user(client, user_token):
    res = client.get("/auth/me", headers={"Authorization": f"Bearer {user_token}"})
    assert res.status_code == 200
    assert res.json()["email"] == "user@example.com"
