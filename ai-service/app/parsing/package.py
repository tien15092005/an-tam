"""Packaging, boxes and blister strips: usually the name and strength only (plan §8). Dosage and times are
almost never printed for the patient, so they are always left empty for the caregiver to fill in."""
import re

from .privacy import is_personal
from .text import FORMS, STRENGTH, clean_name, lines_of, norm, split_name_strength

# Lines that are about the product, not its name.
NOISE = re.compile(
    r"^\W*(thanh phan|chi dinh|chong chi dinh|cach dung|lieu dung|bao quan|han dung|hsd|nsx|ngay sx|so lo|lot|"
    r"sdk|so dang ky|vn-|vd-|qlvd|cong ty|cty|san xuat|nha san xuat|phan phoi|doc ky|de xa|tieu chuan|gmp|"
    r"thuoc ban theo don|rx|ke don|tac dung phu|ta duoc|xuat xu|made in|mfg|exp)"
)
PACK_COUNT = re.compile(rf"(?:hop|lo|chai|tuyp)\s*(?:(\d+)\s*vi\s*x\s*)?(\d+)\s*{FORMS}")


def parse_package(text: str) -> list[dict]:
    lines = [ln for ln in lines_of(text) if not is_personal(ln)]
    quantity = None
    for ln in lines:
        m = PACK_COUNT.search(norm(ln))
        if m:
            quantity = int(m.group(2)) * (int(m.group(1)) if m.group(1) else 1)
            break

    # The name is the first line that carries a strength (or, failing that, the most prominent short line).
    candidates = [ln for ln in lines if re.search(STRENGTH, norm(ln)) and not NOISE.match(norm(ln))]
    if not candidates:
        candidates = [ln for ln in lines if not NOISE.match(norm(ln)) and re.search(r"[a-z]{4,}", norm(ln))
                      and not PACK_COUNT.search(norm(ln)) and len(ln) <= 40]
    if not candidates:
        return []
    line = candidates[0]
    n = norm(line)
    m = re.search(STRENGTH, n)
    part = line[: m.end()] if m else line
    # "Viên nén bao phim Amlodipin 5mg" -> drop the leading form words.
    lead = re.match(rf"^\s*(?:{FORMS})\s+", norm(part))
    if lead:
        part = part[lead.end():]
    name, strength = split_name_strength(part)
    name = clean_name(re.sub(r"\(.*?\)", "", name))
    if len(name) < 2:
        return []
    return [{
        "name": name,
        "strength": strength,
        "dosage": None,
        "times": [],
        "days": None,
        "quantity": quantity,
        "note": None,
        "confidence": 0.6 if strength else 0.4,
        "uncertain": ["dosage", "times", "days"],
    }]
