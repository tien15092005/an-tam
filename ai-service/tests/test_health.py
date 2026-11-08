import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def service_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AI_SERVICE_TOKEN", "test-token")


def test_health_is_public() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "UP"}


def test_ping_accepts_correct_token() -> None:
    response = client.get("/v1/ping", headers={"X-Service-Token": "test-token"})
    assert response.status_code == 200


@pytest.mark.parametrize("headers", [{}, {"X-Service-Token": "wrong"}])
def test_ping_rejects_missing_or_wrong_token(headers: dict[str, str]) -> None:
    assert client.get("/v1/ping", headers=headers).status_code == 401


def test_ping_rejects_everything_when_token_not_configured(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("AI_SERVICE_TOKEN")
    assert client.get("/v1/ping", headers={"X-Service-Token": ""}).status_code == 401
