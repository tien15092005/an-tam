# An Tâm – Nhắc bố mẹ uống thuốc

Ứng dụng di động giúp người con ở xa theo dõi bố mẹ đã uống thuốc, đi tập thể dục chưa. Phía bố mẹ cực kỳ đơn giản: đến giờ, điện thoại đổ chuông, hiện màn hình lớn và **đọc bằng giọng tiếng Việt**, bố mẹ chỉ cần bấm một nút to để xác nhận.

Gồm 3 phần:

| Thư mục     | Là gì                                                                 |
|-------------|-----------------------------------------------------------------------|
| `mobile/`   | **App di động** React Native (Expo SDK 58) cho người con và bố mẹ     |
| `server.py` | Máy chủ API bằng Python (chỉ dùng thư viện chuẩn) + CSDL SQLite       |
| `public/`   | Trang web: trang **quản trị (admin)** và bản web mẫu ban đầu          |

## Chạy thử

Cần: **Python 3.10+**, **Node.js 20+**, và app **Expo Go** trên điện thoại (CH Play / App Store).

**1. Chạy máy chủ** (cửa sổ terminal thứ nhất, ở thư mục gốc):

```bash
python server.py
```

Lần đầu Windows có thể hỏi cho phép Python qua tường lửa → chọn **Allow** (Private network) để điện thoại kết nối được.

**2. Chạy app** (cửa sổ terminal thứ hai):

```bash
cd mobile
npm install
npx expo start
```

> Nếu PowerShell báo *"running scripts is disabled"*, dùng `npm.cmd install` và `npx.cmd expo start`.

**3. Mở trên điện thoại:** điện thoại và máy tính dùng **chung Wi-Fi**, mở Expo Go, quét mã QR trong terminal. App tự nhận địa chỉ máy chủ theo IP máy tính; nếu không kết nối được, bấm dòng *“Máy chủ: …”* ở màn hình đăng nhập để nhập tay, ví dụ `http://192.168.1.18:8000`.

Tài khoản mẫu (tạo tự động lần đầu chạy server):

| Vai trò   | Đăng nhập                                  |
|-----------|--------------------------------------------|
| Người con | `demo@antam.local` / `demo123`             |
| Bố mẹ     | chọn “Tôi là bố / mẹ” → mã `123456`        |
| Admin     | `admin@antam.local` / `admin123` (trên web <http://localhost:8000>) |

Thử trên 2 điện thoại (hoặc đăng xuất rồi đăng nhập vai trò kia) để thấy người con và bố mẹ cùng lúc.

## Tính năng

**Bố mẹ** – chữ rất to, ít nút, tương phản cao
- Đăng nhập một lần bằng mã 6 số do con tạo, không cần email/mật khẩu.
- Màn hình chính: giờ hiện tại, việc tiếp theo, danh sách thuốc + giờ tập hôm nay (✓ đã làm, ! bị quên, ⏰ đến giờ).
- **Đến giờ:** điện thoại tự báo bằng thông báo cục bộ (kể cả khi đã tắt app); khi mở app sẽ hiện màn hình báo toàn trang, rung, **đọc tên thuốc bằng giọng tiếng Việt**, nhắc lại mỗi phút.
- Nút **ĐÃ UỐNG RỒI** / **TÔI ĐI TẬP ĐÂY**, hoặc **Nhắc lại sau 10 phút**.
- Nút **Gọi cho con** và **Tôi thấy không khỏe** (gửi cảnh báo cho con).

**Người con**
- **Hôm nay:** tiến độ uống thuốc, số lần quên, buổi tập, huyết áp gần nhất; đánh dấu giúp khi đã gọi hỏi bố mẹ.
- **Lịch tuần / tháng:** chấm màu cho từng ngày (đỏ = có lần quên, xanh = đủ, cam = có lịch). Bấm một ngày để xem chi tiết và:
  - **Quét toa (OCR):** chụp ảnh toa thuốc → app đọc tên thuốc, liều, buổi sáng/trưa/chiều/tối, số ngày dùng → người con xem lại, sửa → tạo lịch nhắc bắt đầu từ ngày đã chọn.
  - **Thêm thuốc** (nhiều giờ/ngày, dùng lâu dài hoặc N ngày theo toa).
  - **Lịch tập thể dục** (đi bộ, dưỡng sinh, yoga…, chọn thứ trong tuần, thời lượng).
- **Sức khỏe:** huyết áp, nhịp tim, đường huyết, SpO₂, nhiệt độ, cân nặng – tô đỏ khi ngoài ngưỡng tham khảo.
- **Cài đặt:** nhiều hồ sơ bố/mẹ, mã đăng nhập (gửi qua Zalo/SMS), mời anh chị em cùng theo dõi.

**Admin** (web) – thống kê, tìm kiếm, khóa/mở khóa, xóa tài khoản.

Quá **60 phút** sau giờ hẹn mà chưa xác nhận thì tính là “bị quên” (`GRACE_MIN` trong `server.py`).

## Quét toa thuốc (OCR) & giọng đọc Google

Hai tính năng này dùng chung **một key Google Cloud** (tùy chọn):

| Dịch vụ Google          | Dùng cho                         | Không có key thì                         |
|-------------------------|----------------------------------|------------------------------------------|
| Cloud Vision            | Đọc chữ trên ảnh toa thuốc       | Vẫn dán/gõ chữ toa thuốc để tách được    |
| Cloud Text-to-Speech    | Giọng đọc chuẩn trên bản web     | Dùng giọng tiếng Việt có sẵn của máy     |

1. Vào <https://console.cloud.google.com>, tạo project, bật **Cloud Vision API** (và **Cloud Text-to-Speech API** nếu cần). Google yêu cầu gắn thẻ thanh toán, có hạn mức miễn phí hằng tháng.
2. **APIs & Services → Credentials → Create credentials → API key**, giới hạn key chỉ cho 2 API trên.
3. Sao chép `.env.example` thành `.env`, dán key vào `GOOGLE_API_KEY=`, chạy lại `python server.py`.

File `.env` không được đưa lên GitHub. Phần tách toa thuốc nằm ở [`prescription.py`](prescription.py) (tự viết, không cần AI): kết quả luôn để người con duyệt lại trước khi tạo lịch.

**Giọng đọc trong app di động** dùng giọng tiếng Việt của điện thoại (Android: Google Text-to-Speech, iPhone: Linh). Nếu nghe như đánh vần: *Cài đặt → Ngôn ngữ → Chuyển văn bản thành giọng nói*, tải giọng **Tiếng Việt**.

## Cơ sở dữ liệu

**SQLite**, lưu trong `careapp.db`; cấu trúc ở [`database/schema.sql`](database/schema.sql). CSDL cũ được tự nâng cấp khi chạy bản mới.

```bash
python server.py --init-db    # chỉ tạo CSDL (+ dữ liệu mẫu nếu trống), không chạy server
python server.py --reset-db   # xóa CSDL cũ, tạo lại từ đầu
```

Các bảng: `users` (3 vai trò), `sessions`, `family_links` (con ↔ bố mẹ), `medications` (có ngày bắt đầu/kết thúc theo toa), `dose_logs`, `exercises`, `exercise_logs`, `health_records`, `alerts`. Xem dữ liệu bằng [DB Browser for SQLite](https://sqlitebrowser.org/).

## Cấu trúc

```
server.py            API + CSDL
prescription.py      tách danh sách thuốc từ chữ trên toa
database/schema.sql  cấu trúc CSDL
mobile/              app Expo (React Native)
  src/app/           các màn hình (Expo Router)
    login.tsx          đăng nhập, chọn vai trò
    elder.tsx          giao diện bố mẹ + báo thức + giọng nói
    (child)/           các tab người con: Hôm nay, Lịch, Sức khỏe, Cài đặt
    ocr.tsx            quét toa thuốc
    med-form.tsx, exercise-form.tsx, health-form.tsx, elder-form.tsx
  src/components/    nút, thẻ, lịch tuần/tháng, chọn giờ…
  src/lib/           gọi API, thông báo, giọng nói, theme
public/              trang admin + bản web mẫu
```

## Kiểm tra code

```bash
cd mobile
npx tsc --noEmit     # kiểm tra kiểu
npx expo lint        # lint
```

## Hạn chế & hướng tiếp theo

- Expo Go chỉ để phát triển. Muốn cài như app thật (file APK), build bằng EAS: `npx eas-cli@latest build -p android --profile preview`.
- Màn hình báo toàn trang chỉ hiện khi app đang mở; khi app tắt, điện thoại hiện thông báo kèm âm thanh, bấm vào sẽ mở màn hình báo.
- Chưa có xác nhận bằng giọng nói (“đã uống”) trên app di động: cần thư viện nhận diện giọng nói native, phải dùng development build thay cho Expo Go.
- Người con chưa nhận push notification khi app tắt (cần Expo Push / FCM + development build).
- Giờ được tính theo múi giờ của máy chủ. Trước khi chạy thật: đổi mật khẩu admin, dùng HTTPS, thêm hết hạn phiên đăng nhập, sao lưu CSDL.
