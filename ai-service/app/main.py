import hmac
import os

from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from app.parsing import parse

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


class ParseRequest(BaseModel):
    document_type: Literal["PRESCRIPTION", "PACKAGE", "INVOICE", "OTHER"]
    text: str = Field(max_length=8000)


class ParsedItem(BaseModel):
    name: str
    strength: str | None = None
    dosage: str | None = None
    times: list[str] = []
    days: int | None = None
    quantity: int | None = None
    note: str | None = None
    confidence: float
    # Fields left empty because the document does not say: the review screen highlights them.
    uncertain: list[str] = []


class ParseResponse(BaseModel):
    items: list[ParsedItem]
    engine: str


@app.post("/v1/documents/parse", dependencies=[Depends(require_service_token)])
def parse_document(req: ParseRequest) -> ParseResponse:
    """Suggestions only; nothing here is logged (the text may describe someone's illness)."""
    return ParseResponse(items=[ParsedItem(**i) for i in parse(req.document_type, req.text)], engine="baseline-rules-v1")
