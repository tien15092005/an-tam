"""Fills a running backend with made-up demo data (plan §11: fake data only in demos and screenshots).

    python scripts/seed_demo.py                      # http://localhost:8080
    python scripts/seed_demo.py https://xxxx.trycloudflare.com

Creates two caregivers, a family group, one elder with three medicines and a walking exercise, and prints the
logins and a 6-digit pairing code for the elder's phone. Everyone in it is invented.
"""
import json
import secrets
import sys
import urllib.request

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080").rstrip("/")


def call(method, path, token=None, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=None if body is None else json.dumps(body).encode("utf-8"))
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=15) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


def register(name):
    email = f"demo.{name.split()[-1].lower()}.{secrets.token_hex(3)}@antam.demo"
    password = "demo-" + secrets.token_hex(4)
    t = call("POST", "/api/auth/register", body={"email": email, "password": password, "displayName": name,
                                                 "phone": "0900000000"})
    return email, password, t["accessToken"]


def main():
    owner_email, owner_pw, owner = register("Chị Hoa")
    member_email, member_pw, member = register("Anh Nam")
    group = call("POST", "/api/groups", owner, {"name": "Nhà bà Lan (demo)"})
    gid = group["id"]
    code = call("POST", f"/api/groups/{gid}/invites", owner)["code"]
    call("POST", "/api/invites/accept", member, {"code": code})
    elder = call("POST", f"/api/groups/{gid}/elders", owner, {"callName": "Bà Lan", "birthYear": 1950})
    eid = elder["userId"]
    meds = [
        {"name": "Amlodipin", "strength": "5mg", "dosage": "1 viên", "shape": "tròn", "color": "trắng",
         "pillDescription": "Viên tròn nhỏ màu trắng", "times": ["07:30"], "note": "Uống sau ăn sáng"},
        {"name": "Metformin", "strength": "500mg", "dosage": "1 viên", "shape": "bầu dục", "color": "trắng",
         "pillDescription": "Viên dài màu trắng", "times": ["07:30", "20:00"]},
        {"name": "Vitamin D3", "dosage": "1 viên", "color": "vàng", "pillDescription": "Viên nang mềm màu vàng",
         "times": ["12:00"], "daysOfWeek": [1, 3, 5]},
    ]
    for m in meds:
        call("POST", f"/api/groups/{gid}/elders/{eid}/medications", owner, m)
    call("POST", f"/api/groups/{gid}/elders/{eid}/exercises", owner,
         {"title": "Đi bộ quanh nhà", "time": "17:00", "daysOfWeek": [1, 3, 5], "durationMin": 20, "note": "Đi chậm"})
    pairing = call("POST", f"/api/groups/{gid}/elders/{eid}/pairing-code", owner)["code"]
    print("Dữ liệu demo (tất cả là giả):")
    print(f"  Trưởng nhóm : {owner_email}  /  {owner_pw}")
    print(f"  Thành viên  : {member_email}  /  {member_pw}")
    print(f"  Mã ghép máy bà Lan (15 phút): {pairing}")


if __name__ == "__main__":
    main()
