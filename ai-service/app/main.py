import hmac
import os

from fastapi import Depends, FastAPI, Header, HTTPException

app = FastAPI(title="An Tam AI service")


def require_service_token(x_service_token: str | None = Header(default=None)) -> None:
    """Only the backend may call /v1 endpoints; it sends the shared token in X-Service-Token."""
    expected = os.environ.get("AI_SERVICE_TOKEN", "")
    if not expected or not x_service_token or not hmac.compare_digest(x_service_token, expected):
        raise HTTPException(status_code=401, detail="invalid service token")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "UP"}


@app.get("/v1/ping", dependencies=[Depends(require_service_token)])
def ping() -> dict[str, str]:
    return {"status": "UP"}
