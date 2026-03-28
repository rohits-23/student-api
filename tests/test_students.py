import json

HEADERS = {"Content-Type": "application/json"}

STUDENT_PAYLOAD = {
    "name": "Alice Smith",
    "email": "alice@example.com",
    "age": 21,
    "grade": "A",
}


def _post(client, payload=None):
    return client.post(
        "/api/v1/students",
        data=json.dumps(payload if payload is not None else STUDENT_PAYLOAD),
        headers=HEADERS,
    )


# ── Create ────────────────────────────────────────────────────────────────────

def test_create_student_success(client):
    resp = _post(client)
    assert resp.status_code == 201
    data = resp.get_json()["data"]
    assert data["name"] == STUDENT_PAYLOAD["name"]
    assert data["email"] == STUDENT_PAYLOAD["email"]
    assert data["id"] is not None


def test_create_student_missing_name(client):
    resp = _post(client, {"email": "test@example.com"})
    assert resp.status_code == 400


def test_create_student_missing_email(client):
    resp = _post(client, {"name": "Bob"})
    assert resp.status_code == 400


def test_create_student_no_body(client):
    resp = client.post("/api/v1/students", headers=HEADERS)
    assert resp.status_code == 400


def test_create_student_duplicate_email(client):
    _post(client)
    resp = _post(client)
    assert resp.status_code == 409


# ── Read ──────────────────────────────────────────────────────────────────────

def test_get_all_students_empty(client):
    resp = client.get("/api/v1/students")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["data"] == []
    assert body["count"] == 0


def test_get_all_students_with_data(client):
    _post(client)
    resp = client.get("/api/v1/students")
    assert resp.status_code == 200
    assert resp.get_json()["count"] == 1


def test_get_student_by_id_success(client):
    created_id = _post(client).get_json()["data"]["id"]
    resp = client.get(f"/api/v1/students/{created_id}")
    assert resp.status_code == 200
    assert resp.get_json()["data"]["id"] == created_id


def test_get_student_not_found(client):
    assert client.get("/api/v1/students/99999").status_code == 404


# ── Update ────────────────────────────────────────────────────────────────────

def test_update_student_success(client):
    created_id = _post(client).get_json()["data"]["id"]
    resp = client.put(
        f"/api/v1/students/{created_id}",
        data=json.dumps({"name": "Alice Johnson", "grade": "A+"}),
        headers=HEADERS,
    )
    assert resp.status_code == 200
    updated = resp.get_json()["data"]
    assert updated["name"] == "Alice Johnson"
    assert updated["grade"] == "A+"


def test_update_student_not_found(client):
    resp = client.put(
        "/api/v1/students/99999",
        data=json.dumps({"name": "Ghost"}),
        headers=HEADERS,
    )
    assert resp.status_code == 404


def test_update_student_email_conflict(client):
    _post(client)
    other_id = _post(
        client, {"name": "Bob", "email": "bob@example.com"}
    ).get_json()["data"]["id"]
    resp = client.put(
        f"/api/v1/students/{other_id}",
        data=json.dumps({"email": STUDENT_PAYLOAD["email"]}),
        headers=HEADERS,
    )
    assert resp.status_code == 409


# ── Delete ────────────────────────────────────────────────────────────────────

def test_delete_student_success(client):
    created_id = _post(client).get_json()["data"]["id"]
    assert client.delete(f"/api/v1/students/{created_id}").status_code == 200
    assert client.get(f"/api/v1/students/{created_id}").status_code == 404


def test_delete_student_not_found(client):
    assert client.delete("/api/v1/students/99999").status_code == 404
