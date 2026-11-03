"""
Tách danh sách thuốc từ chữ trên toa thuốc (kết quả OCR hoặc người dùng dán vào).

Toa thuốc ở Việt Nam thường có dạng:
    1. Amlodipin 5mg                         30 viên
       Ngày uống 1 lần, mỗi lần 1 viên, sáng sau ăn
    2) Metformin 500mg x 60 viên - Sáng 1 viên, Tối 1 viên
    3. Paracetamol 500mg  SL: 10 viên  Ngày 2 lần, mỗi lần 1 viên. Dùng 5 ngày

Kết quả chỉ là GỢI Ý: người con luôn được xem và sửa trước khi tạo lịch.
"""
import re
import unicodedata

# Giờ uống mặc định cho từng buổi
SESSION_TIMES = {"sang": "07:30", "trua": "11:30", "chieu": "16:30", "toi": "20:00"}
# Khi toa chỉ ghi "ngày uống N lần"
TIMES_PER_DAY = {
    1: ["07:30"],
    2: ["07:30", "19:30"],
    3: ["07:30", "11:30", "19:30"],
    4: ["07:00", "11:00", "15:00", "20:00"],
}

STRENGTH = r"\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|g|ml|ui|iu|%)\b"
NUM = r"(1/2|1/4|½|¼|\d+(?:[.,]\d+)?)"
FORMS = r"(?:vien|goi|ong|chai|lo|tuyp|giot|nang|hop|vi|ml)"
ITEM_START = re.compile(r"^\s*(\d{1,2})\s*[.)/:-]\s*(?=\S)")
# Dòng tiêu đề / thông tin hành chính, không phải thuốc
SKIP_LINE = re.compile(
    r"^(don thuoc|ho ten|ho va ten|tuoi|gioi tinh|dia chi|chan doan|ma (so|benh)|so the|bac si|"
    r"loi dan|ngay kham|tai kham|benh vien|phong kham|khoa|so dien thoai|sdt|nam sinh|can nang|ky ten)")


def strip_accents(s):
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    return s.replace("đ", "d").replace("Đ", "D")


def norm(s):
    return strip_accents(s).lower()


def to_number(x):
    x = x.replace(",", ".")
    return {"1/2": 0.5, "½": 0.5, "1/4": 0.25, "¼": 0.25}.get(x) or float(x)


def fmt_number(n):
    return {0.5: "1/2", 0.25: "1/4"}.get(n) or (str(int(n)) if n == int(n) else str(n))


def split_blocks(text):
    """Chia văn bản thành từng khối, mỗi khối là một loại thuốc."""
    lines = [ln.strip() for ln in text.replace("\r", "").split("\n")]
    lines = [ln for ln in lines if ln]
    blocks, cur = [], None
    has_numbered = any(ITEM_START.match(ln) and re.search(STRENGTH, norm(ln)) for ln in lines)
    for ln in lines:
        n = norm(ln)
        if SKIP_LINE.match(ITEM_START.sub("", n)):
            continue
        starts = ITEM_START.match(ln) if has_numbered else re.search(STRENGTH, n)
        if starts and re.search(r"[a-z]{3,}", n):
            cur = [ln]
            blocks.append(cur)
        elif cur is not None:
            cur.append(ln)
    return blocks


def parse_block(block):
    first = ITEM_START.sub("", block[0]).strip()
    whole = " ".join([first] + block[1:])
    n_whole = norm(whole)
    n_first = norm(first)

    # Tên thuốc: phần đầu dòng tới hết hàm lượng (vd "Amlodipin 5mg")
    m = re.search(STRENGTH, n_first)
    if m:
        name = first[:m.end()].strip()
    else:
        cut = re.search(r"\s(x|sl|so luong|hop|vi|lo|chai|tuyp|\d+\s*" + FORMS + r")\b", n_first)
        name = first[:cut.start()].strip() if cut else first
    name = re.sub(r"[\s:;,\-–]+$", "", name)
    name = re.sub(r"\s+", " ", name)
    if len(name) < 2:
        return None

    # Buổi uống: "sáng 1 viên", "tối 1/2 viên"
    sessions = []
    per_dose = None
    for key in ("sang", "trua", "chieu", "toi"):
        sm = re.search(rf"\b{key}\b\s*:?\s*{NUM}?", n_whole)
        if sm:
            sessions.append(key)
            if sm.group(1) and per_dose is None:
                per_dose = to_number(sm.group(1))

    pm = re.search(rf"moi lan\s*:?\s*{NUM}\s*{FORMS}?", n_whole)
    pm = pm or re.search(rf"{NUM}\s*{FORMS}\s*/\s*lan", n_whole)
    if pm:
        per_dose = to_number(pm.group(1))
    tm = re.search(r"(?:ngay|/ngay)\D{0,12}?(\d)\s*lan|(\d)\s*lan\s*/\s*ngay", n_whole)
    times_per_day = int(tm.group(1) or tm.group(2)) if tm else None

    if sessions:
        times = [SESSION_TIMES[s] for s in sessions]
    elif times_per_day in TIMES_PER_DAY:
        times = TIMES_PER_DAY[times_per_day]
    else:
        times = TIMES_PER_DAY[1]
    count_per_day = len(times)

    # Số ngày dùng: "dùng 7 ngày", "x 5 ngày", hoặc suy ra từ tổng số lượng
    days = None
    dm = re.search(r"(?:dung|trong|uong|x|×)\s*(\d{1,3})\s*ngay\b", n_whole) or \
        re.search(r"\b(\d{1,3})\s*ngay\b(?!\s*(?:uong|\d|lan))", n_whole)
    if dm:
        days = int(dm.group(1))
    else:
        n0 = n_first
        qm = (re.search(r"(?:sl|so luong)\s*:?\s*(\d{1,4})", n0)
              or re.search(rf"x\s*(\d{{1,4}})\s*{FORMS}\b", n0)
              or re.search(rf"(?<!moi lan )(?<![\d/])(\d{{1,4}})\s*{FORMS}\b", n0[len(norm(name)):]))
        total = int(qm.group(1)) if qm else None
        if total and count_per_day:
            days = max(1, round(total / (count_per_day * (per_dose or 1))))

    form = re.search(rf"\b{FORMS}\b", n_whole[len(n_first):] or n_whole)
    unit = {"vien": "viên", "goi": "gói", "ong": "ống", "nang": "viên nang", "giot": "giọt", "ml": "ml"}.get(
        form.group(0) if form else "vien", "viên")
    dosage = f"{fmt_number(per_dose)} {unit}" if per_dose else ""

    notes = []
    if re.search(r"truoc (khi )?an", n_whole):
        notes.append("Uống trước ăn")
    elif re.search(r"trong (bua )?an", n_whole):
        notes.append("Uống trong bữa ăn")
    elif re.search(r"sau (khi )?an", n_whole):
        notes.append("Uống sau ăn")

    return {"name": name, "dosage": dosage, "times": times, "days": days, "note": ", ".join(notes)}


def parse_prescription(text):
    items = []
    for block in split_blocks(text or ""):
        item = parse_block(block)
        if item:
            items.append(item)
    return items[:20]


if __name__ == "__main__":
    import json
    import sys
    print(json.dumps(parse_prescription(sys.stdin.read()), ensure_ascii=False, indent=2))
