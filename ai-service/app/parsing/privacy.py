"""Removes lines that identify a person before anything else looks at the text (plan §8: only filtered
text reaches the server; this is the server-side second check). Also used to keep such lines out of results."""
import re

from .text import norm

# Field labels on prescriptions and pharmacy invoices that carry personal data.
PERSONAL_LABEL = re.compile(
    r"^\W*(ho ten|ho va ten|ten benh nhan|benh nhan|nguoi benh|khach hang|ten khach|nguoi mua|"
    r"dia chi|so dien thoai|dien thoai|sdt|dt|so the|ma the|bhyt|cmnd|cccd|can cuoc|ma so|ma benh nhan|ma bn|"
    r"nam sinh|ngay sinh|tuoi|gioi tinh|can nang|chan doan|email|so ho so|ma ho so)\b"
)
PHONE = re.compile(r"(?<!\d)(?:\+?84|0)(?:[\s.-]?\d){8,10}(?!\d)")
EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+")
LONG_ID = re.compile(r"(?<!\d)\d{9,}(?!\d)")


def is_personal(line: str) -> bool:
    n = norm(line)
    return bool(PERSONAL_LABEL.match(n) or PHONE.search(line) or EMAIL.search(line) or LONG_ID.search(line))


def remove_personal_lines(text: str) -> str:
    return "\n".join(ln for ln in (text or "").splitlines() if not is_personal(ln))
