"""Pharmacy invoices: a list of medicine names and quantities, usually no times (plan §8). Buyer details,
totals and prices are dropped."""
import re

from .privacy import is_personal
from .text import ITEM_START, STRENGTH, lines_of, norm, split_name_strength

SKIP = re.compile(
    r"^\W*(hoa don|nha thuoc|quay thuoc|dia chi|mst|ma so thue|ngay|gio|so hd|so hoa don|thu ngan|nhan vien|"
    r"stt|ten (hang|thuoc|san pham)|tong|thanh tien|tien|chiet khau|giam gia|khach|vat|thue|cam on|hen gap|"
    r"phuong thuc|tien mat|chuyen khoan|the|in luc|website|hotline)"
)
UNIT_WORDS = r"(?:hop|vi|vien|goi|chai|lo|tuyp|ong|cai)"
PRICE = re.compile(r"\d{1,3}(?:[.,]\d{3})+(?:\s*(?:d|vnd|dong))?|\d+\s*(?:d|vnd|dong)\b")


def parse_invoice(text: str) -> list[dict]:
    items = []
    for ln in lines_of(text):
        if is_personal(ln):
            continue
        body = ITEM_START.sub("", ln).strip()
        n = norm(body)
        if SKIP.match(n) or not re.search(r"[a-z]{3,}", n):
            continue
        # Drop prices first so they are not read as quantities.
        n_clean = PRICE.sub(" ", n)
        sm = re.search(STRENGTH, n_clean)
        qm = re.search(rf"(?:x\s*)?(\d{{1,3}})\s*{UNIT_WORDS}\b", n_clean[sm.end():] if sm else n_clean) \
            or re.search(r"\s(\d{1,3})\s*$", n_clean.strip() if not sm else n_clean[sm.end():].rstrip())
        if not sm and not qm:
            continue
        if sm:
            name_part = body[: sm.end()]
        else:
            cut = re.search(rf"\s(?:x\s*)?\d{{1,3}}\s*{UNIT_WORDS}\b|\s\d", n)
            name_part = body[: cut.start()] if cut else body
        name, strength = split_name_strength(name_part)
        if len(name) < 2:
            continue
        items.append({
            "name": name,
            "strength": strength,
            "dosage": None,
            "times": [],
            "days": None,
            "quantity": int(qm.group(1)) if qm else None,
            "note": None,
            "confidence": 0.6 if strength else 0.4,
            "uncertain": ["dosage", "times", "days"],
        })
    return items[:20]

