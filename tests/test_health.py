def test_healthcheck_returns_200(client):
    resp = client.get("/api/v1/healthcheck")
    assert resp.status_code == 200


def test_healthcheck_response_body(client):
    data = client.get("/api/v1/healthcheck").get_json()
    assert data["status"] == "healthy"
    assert "message" in data
