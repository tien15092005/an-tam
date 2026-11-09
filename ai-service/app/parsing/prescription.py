"""Baseline parser for Vietnamese prescriptions, grown from the prototype's prescription.py.

Safety rules (plan §8):
  * Never invent what the paper does not say. Dosage and times are filled only when written; otherwise
    they stay empty and are listed in ``uncertain`` so the review screen highlights them.
  * Times come from named sessions ("sáng", "tối") or "N lần/ngày" using the plan's fixed suggestions.
  * Everything is a suggestion: the caregiver reviews and edits every field before anything is created.
"""
import re

from .privacy import is_personal
from .text import FORMS, ITEM_START, NUM, STRENGTH, clean_name, fmt_number, lines_of, norm, split_name_strength, to_number

SESSION_TIMES = {"sang": "07:30", "trua": "11:30", "chieu": "16:30", "toi": "20:00"}
TIMES_PER_DAY = {
    1: ["07:30"],
    2: ["07:30", "19:30"],
    3: ["07:30", "11:30", "19:30"],
    4: ["07:00", "11:00", "15:00", "20:00"],
}

# Header / administrative lines: never a medicine.
SKIP_LINE = re.compile(
    r"^\W*(don thuoc|toa thuoc|ho ten|ho va ten|tuoi|gioi tinh|dia chi|chan doan|ma (so|benh)|so the|bac si|"
    r"ngay kham|benh vien|phong kham|khoa\b|so dien thoai|sdt|nam sinh|can nang|ky ten|ngay \d{1,2}\s*[/.-]\s*\d|stt|ten thuoc)"
)
# After these, the rest is advice ("1. Ăn nhạt"), not medicines.
END_OF_LIST = re.compile(r"^\W*(loi dan|ghi chu|tai kham|luu y|dan do)")
UNITS = {"vien": "viên", "goi": "gói", "ong": "ống", "nang": "viên", "vien nang": "viên", "vien nen": "viên",
         "vien nen bao phim": "viên", "vien sui": "viên", "giot": "giọt", "ml": "ml"}


def _looks_like_drug(n: str) -> bool:
    return bool(re.search(STRENGTH, n) or re.search(rf"\d+\s*{FORMS}\b", n) or re.search(r"\b(sang|toi|lan)\b", n))


def split_blocks(text: str) -> list[list[str]]:
    """One block per medicine: numbered items when the list is numbered, otherwise one per strength line."""
    lines = []
    for ln in lines_of(text):
        n = norm(ITEM_START.sub("", ln))
        if END_OF_LIST.match(n):
            break
        if SKIP_LINE.match(n) or is_personal(ln):
            continue
        lines.append(ln)
    numbered = any(ITEM_START.match(ln) and re.search(r"[a-z]{3,}", norm(ln)) for ln in lines)
    blocks: list[list[str]] = []
    cur: list[str] | None = None
    for ln in lines:
        n = norm(ln)
        starts = bool(ITEM_START.match(ln)) if numbered else bool(re.search(STRENGTH, n))
        if starts and re.search(r"[a-z]{3,}", n):
            cur = [ln]
            blocks.append(cur)
        elif cur is not None:
            cur.append(ln)
    return [b for b in blocks if _looks_like_drug(norm(" ".join(b)))]


def _name_part(first: str) -> str:
    n_first = norm(first)
    m = re.search(STRENGTH, n_first)
    if m:
        return first[: m.end()]
    cut = re.search(r"\s(x\s*\d|sl\b|so luong|hop|vi\b|lo\b|chai|tuyp|-|\d+\s*" + FORMS + r"\b)", n_first)
    return first[: cut.start()] if cut else first


def parse_block(block: list[str]) -> dict | None:
    first = ITEM_START.sub("", block[0]).strip()
    whole = " ".join([first] + block[1:])
    n_whole = norm(whole)
    n_first = norm(first)

    name, strength = split_name_strength(_name_part(first))
    if len(name) < 2:
        return None

    # "Sáng 1 viên, Tối 1/2 viên"
    sessions: list[str] = []
    per_dose: float | None = None
    for key in ("sang", "trua", "chieu", "toi"):
        sm = re.search(rf"\b{key}\b\s*:?\s*{NUM}?", n_whole)
        if sm:
            sessions.append(key)
            if sm.group(1) and per_dose is None:
                per_dose = to_number(sm.group(1))

    pm = re.search(rf"moi lan\s*:?\s*{NUM}\s*{FORMS}?", n_whole) or re.search(rf"{NUM}\s*{FORMS}\s*/\s*lan", n_whole)
    if pm:
        per_dose = to_number(pm.group(1))
    tm = (re.search(r"(?:ngay|/ngay)\D{0,12}?(\d)\s*lan", n_whole)
          or re.search(r"(\d)\s*lan\s*/\s*ngay", n_whole)
          or re.search(r"x\s*(\d)\s*lan", n_whole))
    times_per_day = int(tm.group(1)) if tm else None

    uncertain: list[str] = []
    if sessions:
        times = [SESSION_TIMES[s] for s in sessions]
    elif times_per_day in TIMES_PER_DAY:
        times = list(TIMES_PER_DAY[times_per_day])
    else:
        times = []  # not written: do not guess
        uncertain.append("times")

    # Total quantity on the first line: "30 viên", "SL: 10 viên", "x 60 viên", "hộp 30 viên".
    rest = n_first[len(norm(name)) + len(strength or ""):]
    qm = (re.search(r"(?:sl|so luong)\s*:?\s*(\d{1,4})", n_first)
          or re.search(rf"x\s*(\d{{1,4}})\s*{FORMS}\b", n_first)
          or re.search(rf"(?<!moi lan )(?<![\d/])(\d{{1,4}})\s*{FORMS}\b", rest))
    quantity = int(qm.group(1)) if qm else None

    days = None
    dm = (re.search(r"(?:dung|trong|uong|x|×)\s*(\d{1,3})\s*ngay\b", n_whole)
          or re.search(r"\b(\d{1,3})\s*ngay\b(?!\s*(?:uong|\d|lan))", n_whole))
    if dm:
        days = int(dm.group(1))
    elif quantity and times:
        days = max(1, round(quantity / (len(times) * (per_dose or 1))))
        if per_dose is None:
            uncertain.append("days")  # assumed one unit per dose
    else:
        uncertain.append("days")

    form = re.search(rf"\b{FORMS}\b", n_whole[len(n_first):] or n_whole) or re.search(rf"\b{FORMS}\b", n_whole)
    unit = UNITS.get(form.group(0) if form else "vien", "viên")
    dosage = f"{fmt_number(per_dose)} {unit}" if per_dose else None
    if dosage is None:
        uncertain.append("dosage")

    note = None
    if re.search(r"truoc (khi )?an", n_whole):
        note = "Uống trước ăn"
    elif re.search(r"trong (bua )?an", n_whole):
        note = "Uống trong bữa ăn"
    elif re.search(r"sau (khi )?an", n_whole):
        note = "Uống sau ăn"

    return {
        "name": clean_name(name),
        "strength": strength,
        "dosage": dosage,
        "times": times,
        "days": days,
        "quantity": quantity,
        "note": note,
        "confidence": round(max(0.2, 1.0 - 0.2 * len(uncertain)), 2),
        "uncertain": uncertain,
    }


def parse_prescription(text: str) -> list[dict]:
    items = []
    for block in split_blocks(text):
        item = parse_block(block)
        if item:
            items.append(item)
    return items[:20]
