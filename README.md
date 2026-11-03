# An Tâm – Nhắc bố mẹ uống thuốc

Ứng dụng giúp người con theo dõi bố mẹ đã uống thuốc chưa. Bố mẹ dùng giao diện cực đơn giản: đến giờ, điện thoại đổ chuông + **giọng nói tiếng Việt** nhắc uống thuốc, bấm một nút to (hoặc nói “đã uống”) để xác nhận.

> Bản hiện tại là **bản mẫu (prototype)** dạng web app / PWA để nhóm demo và chốt luồng nghiệp vụ.

## Chạy thử

Chỉ cần Python 3.10+ (không cần cài thêm thư viện):

```bash
python server.py
```

Mở <http://localhost:8000>. Lần chạy đầu sẽ tự tạo dữ liệu mẫu:

| Vai trò   | Đăng nhập                              |
|-----------|----------------------------------------|
| Admin     | `admin@antam.local` / `admin123`       |
| Người con | `demo@antam.local` / `demo123`         |
| Bố mẹ     | chọn “Tôi là bố / mẹ” → mã `123456`    |

Đổi cổng: `PORT=9000 python server.py`.

## Cơ sở dữ liệu

Dùng **SQLite** (có sẵn trong Python), lưu trong file `careapp.db`. Cấu trúc bảng nằm ở [`database/schema.sql`](database/schema.sql).

```bash
python server.py --init-db    # chỉ tạo CSDL (+ dữ liệu mẫu nếu đang trống), không chạy server
python server.py --reset-db   # xóa CSDL cũ, tạo lại từ đầu
```

Các bảng: `users` (3 vai trò), `sessions`, `family_links` (con ↔ bố mẹ), `medications`, `dose_logs` (lần uống đã xác nhận), `health_records`, `alerts`.
Mở file `careapp.db` bằng [DB Browser for SQLite](https://sqlitebrowser.org/) để xem dữ liệu. File này không được đưa lên Git (xem `.gitignore`).

## 3 loại tài khoản

**Bố mẹ** (`elder.html`) – không cần email/mật khẩu, chỉ nhập mã 6 số một lần.
- Lần đầu: xin quyền **thông báo** và **micro**.
- Màn hình: giờ to, lần uống tiếp theo, danh sách thuốc hôm nay với biểu tượng ✓ / ⏰ / !.
- Đến giờ: màn hình báo toàn trang, chuông, rung, giọng đọc tên thuốc; nhắc lại mỗi phút đến khi xác nhận.
- Xác nhận bằng nút **“ĐÃ UỐNG RỒI”** hoặc nói “đã uống”; nói “lát nữa” hoặc bấm nút để hoãn 10 phút.
- Nút **Gọi cho con** và **Tôi thấy không khỏe** (gửi cảnh báo cho con).

**Người con** (`child.html`)
- Tạo hồ sơ bố/mẹ → nhận mã đăng nhập 6 số.
- Quản lý đơn thuốc (tên, liều, nhiều giờ uống/ngày).
- Theo dõi hôm nay: đã uống / quên uống / sắp tới, đánh dấu giúp nếu đã gọi điện hỏi.
- Sức khỏe: huyết áp, nhịp tim, đường huyết, SpO₂, nhiệt độ, cân nặng – tô đỏ khi ngoài ngưỡng.
- Lịch sử 14 ngày, tỉ lệ uống đúng giờ.
- Mời anh chị em cùng theo dõi (theo email).
- Thông báo trên trình duyệt khi bố mẹ quên thuốc hoặc bấm “không khỏe”.

**Admin** (`admin.html`) – thống kê, tìm kiếm, khóa/mở khóa, xóa tài khoản.

Quá **60 phút** sau giờ uống mà chưa xác nhận thì tính là “quên” (`GRACE_MIN` trong `server.py`).

## Cấu trúc

```
server.py          # API + phục vụ file tĩnh, SQLite (careapp.db)
database/
  schema.sql       # cấu trúc CSDL
public/
  index.html/js    # đăng nhập, chọn vai trò
  elder.html/js    # giao diện bố mẹ + giọng nói
  child.html/js    # giao diện người con
  admin.html/js    # quản trị
  common.js        # gọi API, tiện ích chung
  style.css, sw.js, manifest.json, icon.svg
```

## Hạn chế của bản web & hướng tiếp theo

- **Thử trên điện thoại:** thông báo, micro và service worker chỉ chạy trên `localhost` hoặc **HTTPS**. Để thử qua mạng LAN, dùng một đường hầm HTTPS (vd. `cloudflared tunnel --url http://localhost:8000` hoặc ngrok).
- **Nhắc khi app đóng:** trình duyệt chỉ nhắc chắc chắn khi trang đang mở. Bản thật nên làm app di động (Flutter / React Native) dùng báo thức cục bộ (local notification / AlarmManager) để nhắc cả khi tắt màn hình, kèm push (FCM) để báo cho người con.
- **Giọng đọc:** dùng giọng tiếng Việt có sẵn trên máy (Android/Chrome thường có). Có thể thay bằng file ghi âm giọng của chính người con.
- **Nhận diện giọng nói** hiện chỉ có trên Chrome/Edge.
- Giờ được tính theo múi giờ của máy chủ.
- Trước khi chạy thật: đổi mật khẩu admin, dùng HTTPS, thêm hết hạn phiên đăng nhập, sao lưu CSDL.
