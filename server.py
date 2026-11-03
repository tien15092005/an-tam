"""
An Tâm - ứng dụng nhắc bố mẹ uống thuốc.
Backend thuần Python (chỉ dùng thư viện chuẩn): HTTP server + SQLite.

Chạy:  python server.py          (mặc định cổng 8000)
"""
import hashlib
import hmac
import json
import os
import random
import re
import secrets
import sqlite3
import sys
import threading
import time as _time
import traceback
from datetime import date, datetime, timedelta
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

BASE = os.path.dirname(os.path.abspath(__file__))
PUBLIC = os.path.join(BASE, "public")
DB_PATH = os.environ.get("CAREAPP_DB", os.path.join(BASE, "careapp.db"))
PORT = int(os.environ.get("PORT", "8000"))
GRACE_MIN = 60  # quá giờ uống bao nhiêu phút mà chưa xác nhận thì tính là "quên"

EMAIL_RE = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")
TIME_RE = re.compile(r"([01]\d|2[0-3]):[0-5]\d")
HEALTH_TYPES = {"bp", "hr", "sugar", "weight", "temp", "spo2"}

SCHEMA_PATH = os.path.join(BASE, "database", "schema.sql")


# ---------------------------------------------------------------- helpers

class ApiError(Exception):
    def __init__(self, status, msg):
        super().__init__(msg)
        self.status = status
        self.msg = msg


def now_iso():
    return datetime.now().isoformat(timespec="seconds")


def connect():
    db = sqlite3.connect(DB_PATH, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    return db


def hash_pw(pw):
    salt = secrets.token_bytes(16)
    h = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt, 200_000)
    return f"pbkdf2$200000${salt.hex()}${h.hex()}"


def check_pw(pw, stored):
    try:
        _, it, salt, h = stored.split("$")
        calc = hashlib.pbkdf2_hmac("sha256", pw.encode(), bytes.fromhex(salt), int(it))
        return hmac.compare_digest(calc.hex(), h)
    except Exception:
        return False


def text(body, key, required=False, maxlen=200):
    v = body.get(key)
    v = "" if v is None else str(v).strip()
    if required and not v:
        raise ApiError(400, f"Thiếu thông tin: {key}")
    if len(v) > maxlen:
        raise ApiError(400, f"'{key}' quá dài (tối đa {maxlen} ký tự)")
    return v


def new_session(db, user_id):
    token = secrets.token_urlsafe(32)
    db.execute("INSERT INTO sessions(token,user_id,created_at) VALUES (?,?,?)", (token, user_id, now_iso()))
    return token


def get_user(db, uid):
    return db.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()


def public_user(u):
    return {"id": u["id"], "role": u["role"], "name": u["name"], "email": u["email"],
            "phone": u["phone"], "active": bool(u["active"]), "created_at": u["created_at"]}


def elder_public(e, include_code=True):
    d = {"id": e["id"], "name": e["name"], "phone": e["phone"], "birth_year": e["birth_year"],
         "note": e["note"], "created_at": e["created_at"]}
    if include_code:
        d["login_code"] = e["login_code"]
    return d


def new_elder_code(db):
    while True:
        code = f"{random.SystemRandom().randint(0, 999999):06d}"
        if not db.execute("SELECT 1 FROM users WHERE login_code=?", (code,)).fetchone():
            return code


def parse_times(raw):
    if not isinstance(raw, list) or not raw:
        raise ApiError(400, "Cần ít nhất một giờ uống")
    times = sorted({str(t).strip() for t in raw})
    if len(times) > 8:
        raise ApiError(400, "Tối đa 8 lần uống mỗi ngày")
    for t in times:
        if not TIME_RE.fullmatch(t):
            raise ApiError(400, f"Giờ không hợp lệ: {t}")
    return times


# Giới hạn số lần đăng nhập sai theo IP (chống dò mã 6 số)
_fails = {}
_fails_lock = threading.Lock()


def check_rate(ip):
    with _fails_lock:
        recent = [t for t in _fails.get(ip, []) if t > _time.time() - 600]
        _fails[ip] = recent
        if len(recent) >= 10:
            raise ApiError(429, "Bạn đã thử sai quá nhiều lần. Vui lòng đợi 10 phút.")


def note_fail(ip):
    with _fails_lock:
        _fails.setdefault(ip, []).append(_time.time())


# ---------------------------------------------------------------- dose logic

def doses_for_day(db, elder_id, day, now=None):
    """Danh sách các lần uống thuốc trong một ngày kèm trạng thái:
    taken / skipped / missed (quá giờ chưa uống) / due (đang đến giờ) / upcoming."""
    now = now or datetime.now()
    meds = db.execute("SELECT * FROM medications WHERE elder_id=? ORDER BY id", (elder_id,)).fetchall()
    logs = {}
    for r in db.execute(
            "SELECT l.*, u.role AS by_role, u.name AS by_name FROM dose_logs l "
            "LEFT JOIN users u ON u.id = l.logged_by WHERE l.elder_id=? AND l.date=?",
            (elder_id, day.isoformat())):
        logs[(r["med_id"], r["time"])] = r
    out = []
    for m in meds:
        created = datetime.fromisoformat(m["created_at"]).replace(second=0, microsecond=0)
        ended = datetime.fromisoformat(m["ended_at"]) if m["ended_at"] else None
        for t in json.loads(m["times"]):
            due = datetime.combine(day, datetime.strptime(t, "%H:%M").time())
            log = logs.get((m["id"], t))
            if not log and (due < created or (ended and due >= ended)):
                continue
            if log:
                status = log["status"]
            elif now > due + timedelta(minutes=GRACE_MIN):
                status = "missed"
            elif now >= due:
                status = "due"
            else:
                status = "upcoming"
            out.append({
                "med_id": m["id"], "name": m["name"], "dosage": m["dosage"], "note": m["note"],
                "date": day.isoformat(), "time": t, "status": status,
                "logged_at": log["logged_at"] if log else None,
                "logged_by": ({"role": log["by_role"], "name": log["by_name"]} if log and log["by_role"] else None),
            })
    out.sort(key=lambda d: (d["time"], d["name"]))
    return out


def summarize(doses):
    c = {"total": len(doses), "taken": 0, "skipped": 0, "missed": 0, "due": 0, "upcoming": 0}
    for d in doses:
        c[d["status"]] += 1
    c["next"] = next((d for d in doses if d["status"] in ("due", "upcoming")), None)
    return c


def latest_health(db, elder_id):
    latest = {}
    for r in db.execute("SELECT * FROM health_records WHERE elder_id=? ORDER BY recorded_at DESC, id DESC", (elder_id,)):
        if r["type"] not in latest:
            latest[r["type"]] = dict(r)
    return latest


def open_alerts(db, elder_id):
    return [dict(r) for r in db.execute(
        "SELECT * FROM alerts WHERE elder_id=? AND resolved=0 ORDER BY id DESC", (elder_id,))]


def mark_dose(db, elder_id, body, user, allow_past_days):
    try:
        med_id = int(body.get("med_id"))
    except (TypeError, ValueError):
        raise ApiError(400, "Thiếu thuốc cần đánh dấu")
    t = text(body, "time", required=True, maxlen=5)
    status = text(body, "status", required=True, maxlen=10)
    day_s = text(body, "date", maxlen=10) or date.today().isoformat()
    try:
        day = date.fromisoformat(day_s)
    except ValueError:
        raise ApiError(400, "Ngày không hợp lệ")
    if day > date.today() or (date.today() - day).days > allow_past_days:
        raise ApiError(400, "Không thể đánh dấu cho ngày này")
    med = db.execute("SELECT * FROM medications WHERE id=? AND elder_id=?", (med_id, elder_id)).fetchone()
    if not med or t not in json.loads(med["times"]):
        raise ApiError(404, "Không tìm thấy lần uống thuốc này")
    if status == "clear":
        db.execute("DELETE FROM dose_logs WHERE med_id=? AND date=? AND time=?", (med_id, day_s, t))
    elif status in ("taken", "skipped"):
        db.execute(
            "INSERT INTO dose_logs(med_id,elder_id,date,time,status,logged_at,logged_by) VALUES (?,?,?,?,?,?,?) "
            "ON CONFLICT(med_id,date,time) DO UPDATE SET status=excluded.status, "
            "logged_at=excluded.logged_at, logged_by=excluded.logged_by",
            (med_id, elder_id, day_s, t, status, now_iso(), user["id"]))
    else:
        raise ApiError(400, "Trạng thái không hợp lệ")


# ---------------------------------------------------------------- routing

ROUTES = []
ANY = ("admin", "child", "elder")


def api(method, pattern, roles=None):
    def deco(fn):
        ROUTES.append((method, re.compile(pattern), fn, roles))
        return fn
    return deco


class Ctx:
    def __init__(self, handler, db, url, params, body):
        self.handler = handler
        self.db = db
        self.query = {k: v[0] for k, v in parse_qs(url.query).items()}
        self.params = params
        self.body = body
        self.user = None
        self.token = None

    @property
    def ip(self):
        return self.handler.client_address[0]


def authenticate(c):
    h = c.handler.headers.get("Authorization", "")
    token = h[7:] if h.startswith("Bearer ") else ""
    row = c.db.execute(
        "SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token=?", (token,)).fetchone()
    if not row:
        raise ApiError(401, "Phiên đăng nhập đã hết hạn")
    if not row["active"]:
        raise ApiError(403, "Tài khoản đã bị khóa")
    c.user, c.token = row, token


def elder_for_child(c, elder_id):
    """Trả về hồ sơ bố/mẹ nếu người con hiện tại có quyền theo dõi."""
    e = c.db.execute(
        "SELECT u.* FROM users u JOIN family_links f ON f.elder_id = u.id "
        "WHERE u.id=? AND f.child_id=? AND u.role='elder'", (int(elder_id), c.user["id"])).fetchone()
    if not e:
        raise ApiError(404, "Không tìm thấy hồ sơ")
    return e


# ---------- auth

@api("POST", r"/api/auth/register")
def register(c):
    b = c.body
    name = text(b, "name", required=True, maxlen=80)
    email = text(b, "email", required=True, maxlen=120).lower()
    if not EMAIL_RE.fullmatch(email):
        raise ApiError(400, "Email không hợp lệ")
    pw = str(b.get("password") or "")
    if len(pw) < 6:
        raise ApiError(400, "Mật khẩu cần ít nhất 6 ký tự")
    phone = text(b, "phone", maxlen=20)
    if c.db.execute("SELECT 1 FROM users WHERE email=?", (email,)).fetchone():
        raise ApiError(409, "Email này đã được đăng ký")
    cur = c.db.execute(
        "INSERT INTO users(role,name,email,pw_hash,phone,created_at) VALUES ('child',?,?,?,?,?)",
        (name, email, hash_pw(pw), phone, now_iso()))
    return {"token": new_session(c.db, cur.lastrowid), "user": public_user(get_user(c.db, cur.lastrowid))}


@api("POST", r"/api/auth/login")
def login(c):
    check_rate(c.ip)
    email = text(c.body, "email", required=True, maxlen=120).lower()
    u = c.db.execute("SELECT * FROM users WHERE email=? AND role IN ('admin','child')", (email,)).fetchone()
    if not u or not check_pw(str(c.body.get("password") or ""), u["pw_hash"] or ""):
        note_fail(c.ip)
        raise ApiError(401, "Sai email hoặc mật khẩu")
    if not u["active"]:
        raise ApiError(403, "Tài khoản đã bị khóa")
    return {"token": new_session(c.db, u["id"]), "user": public_user(u)}


@api("POST", r"/api/auth/elder-login")
def elder_login(c):
    check_rate(c.ip)
    code = re.sub(r"\D", "", str(c.body.get("code") or ""))
    u = c.db.execute("SELECT * FROM users WHERE login_code=? AND role='elder'", (code,)).fetchone() if len(code) == 6 else None
    if not u:
        note_fail(c.ip)
        raise ApiError(401, "Mã không đúng. Nhờ con xem lại mã trong ứng dụng.")
    if not u["active"]:
        raise ApiError(403, "Tài khoản đã bị khóa")
    return {"token": new_session(c.db, u["id"]), "user": public_user(u)}


@api("POST", r"/api/auth/logout", ANY)
def logout(c):
    c.db.execute("DELETE FROM sessions WHERE token=?", (c.token,))


@api("GET", r"/api/me", ANY)
def me(c):
    return public_user(c.user)


# ---------- người con (child)

@api("GET", r"/api/elders", ("child",))
def list_elders(c):
    rows = c.db.execute(
        "SELECT u.* FROM users u JOIN family_links f ON f.elder_id = u.id WHERE f.child_id=? ORDER BY u.name",
        (c.user["id"],)).fetchall()
    today = date.today()
    return [{**elder_public(e), "today": summarize(doses_for_day(c.db, e["id"], today)),
             "alerts": open_alerts(c.db, e["id"]), "latest_health": latest_health(c.db, e["id"])}
            for e in rows]


@api("POST", r"/api/elders", ("child",))
def create_elder(c):
    b = c.body
    name = text(b, "name", required=True, maxlen=60)
    by = b.get("birth_year")
    by = int(by) if str(by or "").strip().isdigit() else None
    cur = c.db.execute(
        "INSERT INTO users(role,name,phone,birth_year,note,login_code,created_at) VALUES ('elder',?,?,?,?,?,?)",
        (name, text(b, "phone", maxlen=20), by, text(b, "note", maxlen=500), new_elder_code(c.db), now_iso()))
    c.db.execute("INSERT INTO family_links(child_id,elder_id) VALUES (?,?)", (c.user["id"], cur.lastrowid))
    return elder_public(get_user(c.db, cur.lastrowid))


@api("GET", r"/api/elders/(\d+)", ("child",))
def get_elder(c):
    e = elder_for_child(c, c.params[0])
    members = c.db.execute(
        "SELECT u.id,u.name,u.email,u.phone FROM users u JOIN family_links f ON f.child_id=u.id WHERE f.elder_id=?",
        (e["id"],)).fetchall()
    return {**elder_public(e), "members": [dict(m) for m in members]}


@api("PUT", r"/api/elders/(\d+)", ("child",))
def update_elder(c):
    e = elder_for_child(c, c.params[0])
    b = c.body
    by = b.get("birth_year")
    by = int(by) if str(by or "").strip().isdigit() else None
    c.db.execute("UPDATE users SET name=?, phone=?, birth_year=?, note=? WHERE id=?",
                 (text(b, "name", required=True, maxlen=60), text(b, "phone", maxlen=20), by,
                  text(b, "note", maxlen=500), e["id"]))
    return elder_public(get_user(c.db, e["id"]))


@api("DELETE", r"/api/elders/(\d+)", ("child",))
def delete_elder(c):
    e = elder_for_child(c, c.params[0])
    c.db.execute("DELETE FROM family_links WHERE child_id=? AND elder_id=?", (c.user["id"], e["id"]))
    if not c.db.execute("SELECT 1 FROM family_links WHERE elder_id=?", (e["id"],)).fetchone():
        c.db.execute("DELETE FROM users WHERE id=?", (e["id"],))


@api("POST", r"/api/elders/(\d+)/regen-code", ("child",))
def regen_code(c):
    e = elder_for_child(c, c.params[0])
    c.db.execute("UPDATE users SET login_code=? WHERE id=?", (new_elder_code(c.db), e["id"]))
    c.db.execute("DELETE FROM sessions WHERE user_id=?", (e["id"],))  # đăng xuất thiết bị cũ
    return elder_public(get_user(c.db, e["id"]))


@api("POST", r"/api/elders/(\d+)/share", ("child",))
def share_elder(c):
    e = elder_for_child(c, c.params[0])
    email = text(c.body, "email", required=True, maxlen=120).lower()
    other = c.db.execute("SELECT * FROM users WHERE email=? AND role='child'", (email,)).fetchone()
    if not other:
        raise ApiError(404, "Chưa có tài khoản người con nào dùng email này. Hãy nhờ họ đăng ký trước.")
    c.db.execute("INSERT OR IGNORE INTO family_links(child_id,elder_id) VALUES (?,?)", (other["id"], e["id"]))


@api("GET", r"/api/elders/(\d+)/medications", ("child",))
def list_meds(c):
    e = elder_for_child(c, c.params[0])
    rows = c.db.execute("SELECT * FROM medications WHERE elder_id=? AND active=1 ORDER BY name", (e["id"],))
    return [{**dict(r), "times": json.loads(r["times"])} for r in rows]


@api("POST", r"/api/elders/(\d+)/medications", ("child",))
def create_med(c):
    e = elder_for_child(c, c.params[0])
    b = c.body
    cur = c.db.execute(
        "INSERT INTO medications(elder_id,name,dosage,note,times,created_at) VALUES (?,?,?,?,?,?)",
        (e["id"], text(b, "name", required=True, maxlen=100), text(b, "dosage", maxlen=100),
         text(b, "note", maxlen=300), json.dumps(parse_times(b.get("times"))), now_iso()))
    return {"id": cur.lastrowid}


def med_for_child(c, med_id):
    m = c.db.execute("SELECT * FROM medications WHERE id=? AND active=1", (int(med_id),)).fetchone()
    if not m:
        raise ApiError(404, "Không tìm thấy thuốc")
    elder_for_child(c, m["elder_id"])
    return m


@api("PUT", r"/api/medications/(\d+)", ("child",))
def update_med(c):
    m = med_for_child(c, c.params[0])
    b = c.body
    c.db.execute("UPDATE medications SET name=?, dosage=?, note=?, times=? WHERE id=?",
                 (text(b, "name", required=True, maxlen=100), text(b, "dosage", maxlen=100),
                  text(b, "note", maxlen=300), json.dumps(parse_times(b.get("times"))), m["id"]))


@api("DELETE", r"/api/medications/(\d+)", ("child",))
def delete_med(c):
    m = med_for_child(c, c.params[0])
    # Xóa mềm để lịch sử cũ vẫn còn
    c.db.execute("UPDATE medications SET active=0, ended_at=? WHERE id=?", (now_iso(), m["id"]))


@api("GET", r"/api/elders/(\d+)/today", ("child",))
def elder_today(c):
    e = elder_for_child(c, c.params[0])
    return doses_for_day(c.db, e["id"], date.today())


@api("POST", r"/api/elders/(\d+)/doses", ("child",))
def child_mark_dose(c):
    e = elder_for_child(c, c.params[0])
    mark_dose(c.db, e["id"], c.body, c.user, allow_past_days=7)


@api("GET", r"/api/elders/(\d+)/history", ("child",))
def elder_history(c):
    e = elder_for_child(c, c.params[0])
    days = max(1, min(int(c.query.get("days", "7") or 7), 60))
    out = []
    for i in range(days):
        day = date.today() - timedelta(days=i)
        doses = doses_for_day(c.db, e["id"], day)
        s = summarize(doses)
        done = s["taken"] + s["skipped"] + s["missed"]
        out.append({"date": day.isoformat(), "taken": s["taken"], "skipped": s["skipped"], "missed": s["missed"],
                    "pending": s["due"] + s["upcoming"], "total": s["total"],
                    "rate": round(100 * s["taken"] / done) if done else None, "doses": doses})
    return out


@api("GET", r"/api/elders/(\d+)/health", ("child",))
def list_health(c):
    e = elder_for_child(c, c.params[0])
    days = max(1, min(int(c.query.get("days", "30") or 30), 365))
    since = (datetime.now() - timedelta(days=days)).isoformat(timespec="seconds")
    rows = c.db.execute(
        "SELECT h.*, u.name AS by_name FROM health_records h LEFT JOIN users u ON u.id=h.recorded_by "
        "WHERE h.elder_id=? AND h.recorded_at>=? ORDER BY h.recorded_at DESC LIMIT 300", (e["id"], since))
    return [dict(r) for r in rows]


@api("POST", r"/api/elders/(\d+)/health", ("child",))
def add_health(c):
    e = elder_for_child(c, c.params[0])
    b = c.body
    typ = text(b, "type", required=True, maxlen=10)
    if typ not in HEALTH_TYPES:
        raise ApiError(400, "Loại chỉ số không hợp lệ")
    try:
        value = float(b.get("value"))
        value2 = float(b["value2"]) if typ == "bp" else None
    except (TypeError, ValueError, KeyError):
        raise ApiError(400, "Giá trị không hợp lệ")
    rec = text(b, "recorded_at", maxlen=19)
    if rec:
        try:
            rec = datetime.fromisoformat(rec).isoformat(timespec="seconds")
        except ValueError:
            raise ApiError(400, "Thời gian đo không hợp lệ")
    c.db.execute(
        "INSERT INTO health_records(elder_id,type,value,value2,note,recorded_at,recorded_by) VALUES (?,?,?,?,?,?,?)",
        (e["id"], typ, value, value2, text(b, "note", maxlen=300), rec or now_iso(), c.user["id"]))


@api("DELETE", r"/api/health/(\d+)", ("child",))
def delete_health(c):
    r = c.db.execute("SELECT * FROM health_records WHERE id=?", (int(c.params[0]),)).fetchone()
    if not r:
        raise ApiError(404, "Không tìm thấy")
    elder_for_child(c, r["elder_id"])
    c.db.execute("DELETE FROM health_records WHERE id=?", (r["id"],))


@api("POST", r"/api/alerts/(\d+)/resolve", ("child",))
def resolve_alert(c):
    a = c.db.execute("SELECT * FROM alerts WHERE id=?", (int(c.params[0]),)).fetchone()
    if not a:
        raise ApiError(404, "Không tìm thấy")
    elder_for_child(c, a["elder_id"])
    c.db.execute("UPDATE alerts SET resolved=1 WHERE id=?", (a["id"],))


# ---------- bố mẹ (elder)

@api("GET", r"/api/elder/today", ("elder",))
def elder_self_today(c):
    contacts = c.db.execute(
        "SELECT u.name, u.phone FROM users u JOIN family_links f ON f.child_id=u.id "
        "WHERE f.elder_id=? AND u.active=1 ORDER BY u.id", (c.user["id"],)).fetchall()
    return {"me": elder_public(c.user, include_code=False), "grace_minutes": GRACE_MIN,
            "server_time": now_iso(), "doses": doses_for_day(c.db, c.user["id"], date.today()),
            "contacts": [dict(x) for x in contacts]}


@api("POST", r"/api/elder/doses", ("elder",))
def elder_mark_dose(c):
    mark_dose(c.db, c.user["id"], c.body, c.user, allow_past_days=0)


@api("POST", r"/api/elder/alert", ("elder",))
def elder_alert(c):
    kind = text(c.body, "kind", maxlen=20) or "help"
    c.db.execute("INSERT INTO alerts(elder_id,kind,message,created_at) VALUES (?,?,?,?)",
                 (c.user["id"], kind, text(c.body, "message", maxlen=300), now_iso()))


# ---------- admin

@api("GET", r"/api/admin/stats", ("admin",))
def admin_stats(c):
    q = lambda sql, *a: c.db.execute(sql, a).fetchone()[0]
    today = date.today().isoformat()
    return {
        "children": q("SELECT COUNT(*) FROM users WHERE role='child'"),
        "elders": q("SELECT COUNT(*) FROM users WHERE role='elder'"),
        "medications": q("SELECT COUNT(*) FROM medications WHERE active=1"),
        "taken_today": q("SELECT COUNT(*) FROM dose_logs WHERE date=? AND status='taken'", today),
        "open_alerts": q("SELECT COUNT(*) FROM alerts WHERE resolved=0"),
        "locked": q("SELECT COUNT(*) FROM users WHERE active=0"),
    }


@api("GET", r"/api/admin/users", ("admin",))
def admin_users(c):
    out = []
    for u in c.db.execute("SELECT * FROM users ORDER BY role, id"):
        d = public_user(u)
        if u["role"] == "elder":
            d["linked"] = [r[0] for r in c.db.execute(
                "SELECT u.name FROM users u JOIN family_links f ON f.child_id=u.id WHERE f.elder_id=?", (u["id"],))]
        elif u["role"] == "child":
            d["linked"] = [r[0] for r in c.db.execute(
                "SELECT u.name FROM users u JOIN family_links f ON f.elder_id=u.id WHERE f.child_id=?", (u["id"],))]
        out.append(d)
    return out


@api("PUT", r"/api/admin/users/(\d+)", ("admin",))
def admin_update_user(c):
    uid = int(c.params[0])
    if uid == c.user["id"]:
        raise ApiError(400, "Không thể tự khóa tài khoản của mình")
    if not get_user(c.db, uid):
        raise ApiError(404, "Không tìm thấy người dùng")
    active = 1 if c.body.get("active") else 0
    c.db.execute("UPDATE users SET active=? WHERE id=?", (active, uid))
    if not active:
        c.db.execute("DELETE FROM sessions WHERE user_id=?", (uid,))


@api("DELETE", r"/api/admin/users/(\d+)", ("admin",))
def admin_delete_user(c):
    uid = int(c.params[0])
    u = get_user(c.db, uid)
    if not u:
        raise ApiError(404, "Không tìm thấy người dùng")
    if uid == c.user["id"] or u["role"] == "admin":
        raise ApiError(400, "Không thể xóa tài khoản admin")
    if u["role"] == "child":
        # Hồ sơ bố mẹ chỉ do người này theo dõi cũng bị xóa theo
        orphans = c.db.execute(
            "SELECT elder_id FROM family_links WHERE child_id=? AND elder_id NOT IN "
            "(SELECT elder_id FROM family_links WHERE child_id<>?)", (uid, uid)).fetchall()
        for (eid,) in orphans:
            c.db.execute("DELETE FROM users WHERE id=?", (eid,))
    c.db.execute("DELETE FROM users WHERE id=?", (uid,))


# ---------------------------------------------------------------- HTTP

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "application/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".html": "text/html; charset=utf-8",
        ".json": "application/json",
        ".svg": "image/svg+xml",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PUBLIC, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        if self.path.startswith("/api/"):
            super().log_message(fmt, *args)

    def send_json(self, data, status=200):
        raw = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        self.route("GET")

    def do_POST(self):
        self.route("POST")

    def do_PUT(self):
        self.route("PUT")

    def do_DELETE(self):
        self.route("DELETE")

    def route(self, method):
        url = urlparse(self.path)
        if not url.path.startswith("/api/"):
            if method == "GET":
                return super().do_GET()
            return self.send_json({"error": "Không tìm thấy"}, 404)
        for m, rx, fn, roles in ROUTES:
            mt = rx.fullmatch(url.path)
            if m != method or not mt:
                continue
            db = connect()
            try:
                body = {}
                length = int(self.headers.get("Content-Length") or 0)
                if length:
                    if length > 1_000_000:
                        raise ApiError(413, "Dữ liệu quá lớn")
                    body = json.loads(self.rfile.read(length) or b"{}")
                    if not isinstance(body, dict):
                        raise ApiError(400, "Dữ liệu không hợp lệ")
                c = Ctx(self, db, url, mt.groups(), body)
                if roles is not None:
                    authenticate(c)
                    if c.user["role"] not in roles:
                        raise ApiError(403, "Bạn không có quyền thực hiện thao tác này")
                result = fn(c)
                db.commit()
                self.send_json({"ok": True} if result is None else result)
            except ApiError as e:
                db.rollback()
                self.send_json({"error": e.msg}, e.status)
            except json.JSONDecodeError:
                db.rollback()
                self.send_json({"error": "Dữ liệu JSON không hợp lệ"}, 400)
            except Exception:
                db.rollback()
                traceback.print_exc()
                self.send_json({"error": "Lỗi máy chủ"}, 500)
            finally:
                db.close()
            return
        self.send_json({"error": "Không tìm thấy"}, 404)


# ---------------------------------------------------------------- setup

def init_db():
    db = connect()
    with open(SCHEMA_PATH, encoding="utf-8") as f:
        db.executescript(f.read())
    if not db.execute("SELECT 1 FROM users LIMIT 1").fetchone():
        seed_demo(db)
    db.commit()
    db.close()


def seed_demo(db):
    """Tạo tài khoản admin + dữ liệu mẫu cho lần chạy đầu tiên."""
    now = datetime.now()
    week_ago = (now - timedelta(days=7)).replace(hour=0, minute=0, second=0).isoformat(timespec="seconds")
    db.execute("INSERT INTO users(role,name,email,pw_hash,created_at) VALUES ('admin','Quản trị viên',?,?,?)",
               ("admin@antam.local", hash_pw("admin123"), now_iso()))
    child = db.execute("INSERT INTO users(role,name,email,pw_hash,phone,created_at) VALUES ('child',?,?,?,?,?)",
                       ("Nguyễn Minh", "demo@antam.local", hash_pw("demo123"), "0901234567", now_iso())).lastrowid
    elder = db.execute(
        "INSERT INTO users(role,name,phone,birth_year,note,login_code,created_at) VALUES ('elder',?,?,?,?,?,?)",
        ("Bà Lan", "0912345678", 1952, "Huyết áp cao, tiểu đường type 2", "123456", now_iso())).lastrowid
    db.execute("INSERT INTO family_links VALUES (?,?)", (child, elder))
    meds = [("Amlodipin", "5mg - 1 viên", "Uống sau ăn sáng", ["07:30"]),
            ("Metformin", "500mg - 1 viên", "Uống trong bữa ăn", ["07:30", "19:00"]),
            ("Canxi D3", "1 viên", "", ["12:00"])]
    rnd = random.Random(7)
    for name, dosage, note, times in meds:
        mid = db.execute("INSERT INTO medications(elder_id,name,dosage,note,times,created_at) VALUES (?,?,?,?,?,?)",
                         (elder, name, dosage, note, json.dumps(times), week_ago)).lastrowid
        for i in range(1, 7):
            day = (now - timedelta(days=i)).date().isoformat()
            for t in times:
                if rnd.random() < 0.85:
                    db.execute("INSERT INTO dose_logs(med_id,elder_id,date,time,status,logged_at,logged_by) "
                               "VALUES (?,?,?,?,?,?,?)", (mid, elder, day, t, "taken", f"{day}T{t}:00", elder))
    for i in range(7, 0, -1):
        at = (now - timedelta(days=i)).replace(hour=8, minute=0, second=0).isoformat(timespec="seconds")
        db.execute("INSERT INTO health_records(elder_id,type,value,value2,recorded_at,recorded_by) VALUES (?,?,?,?,?,?)",
                   (elder, "bp", rnd.randint(125, 150), rnd.randint(78, 92), at, child))
        db.execute("INSERT INTO health_records(elder_id,type,value,recorded_at,recorded_by) VALUES (?,?,?,?,?)",
                   (elder, "sugar", round(rnd.uniform(6.0, 8.2), 1), at, child))
    print("Đã tạo dữ liệu mẫu:")
    print("  Admin     : admin@antam.local / admin123")
    print("  Người con : demo@antam.local / demo123")
    print("  Bố mẹ     : mã đăng nhập 123456 (Bà Lan)")


def main():
    # Console Windows mặc định không in được tiếng Việt
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if "--reset-db" in sys.argv:
        for suffix in ("", "-wal", "-shm", "-journal"):
            if os.path.exists(DB_PATH + suffix):
                os.remove(DB_PATH + suffix)
        print("Đã xóa CSDL cũ.")
    init_db()
    if "--init-db" in sys.argv or "--reset-db" in sys.argv:
        print(f"CSDL sẵn sàng: {DB_PATH}")
        return
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"An Tâm đang chạy tại http://localhost:{PORT}  (Ctrl+C để dừng)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
