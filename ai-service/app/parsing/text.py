"""Text helpers shared by the document parsers. Matching works on accent-free lower case, so text typed
without diacritics ("Sang 1 vien") parses the same as "Sáng 1 viên"."""
import re
import unicodedata

STRENGTH = r"\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|g|ml|ui|iu|%)(?![a-z])"
NUM = r"(1/2|1/4|½|¼|\d+(?:[.,]\d+)?)"
FORMS = r"(?:vien nen bao phim|vien nen|vien nang|vien sui|vien|goi|ong|chai|lo|tuyp|giot|nang|hop|vi|ml)"
ITEM_START = re.compile(r"^\s*(\d{1,2})\s*[.)/:-]\s*(?=\S)")


def strip_accents(s: str) -> str:
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    return s.replace("đ", "d").replace("Đ", "D")


def norm(s: str) -> str:
    return strip_accents(s).lower()


def to_number(x: str) -> float:
    x = x.replace(",", ".")
    return {"1/2": 0.5, "½": 0.5, "1/4": 0.25, "¼": 0.25}.get(x) or float(x)


def fmt_number(n: float) -> str:
    return {0.5: "1/2", 0.25: "1/4"}.get(n) or (str(int(n)) if n == int(n) else str(n))


def lines_of(text: str) -> list[str]:
    return [ln.strip() for ln in (text or "").replace("\r", "").split("\n") if ln.strip()]


def clean_name(s: str) -> str:
    s = re.sub(r"[\s:;,\-–]+$", "", s)
    s = re.sub(r"^[\s:;,\-–.]+", "", s)
    return re.sub(r"\s+", " ", s).strip()


def split_name_strength(name_with_strength: str) -> tuple[str, str | None]:
    """'Amlodipin 5mg' -> ('Amlodipin', '5mg'). The strength keeps the document's own spelling, spaces removed."""
    m = re.search(STRENGTH, norm(name_with_strength))
    if not m:
        return clean_name(name_with_strength), None
    name = clean_name(name_with_strength[: m.start()])
    strength = re.sub(r"\s+", "", name_with_strength[m.start(): m.end()])
    return name, strength


def fix_ocr_digits(text: str) -> str:
    """Undo the usual OCR mix-ups inside numbers: '50Omg' -> '500mg', '1O viên' -> '10 viên', '2l5mg' -> '215mg'.
    Only touches a letter wedged between digits, or between a digit and a unit, so words stay as they are."""
    text = re.sub(r"(?<=\d)[Oo](?=\d|\s*(?:mg|mcg|g|ml|vi[eê]n|vien)\b)", "0", text)
    text = re.sub(r"(?<=\d)[Oo](?=[Oo]*\s*(?:mg|mcg|g|ml)\b)", "0", text)
    return re.sub(r"(?<=\d)[lI](?=\d)", "1", text)
