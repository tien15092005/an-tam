# An Tâm trên iPhone (Giai đoạn 13, tùy chọn)

**Tình trạng:** chưa build, chưa chạy trên iPhone. Nhóm không có máy Mac nên không biên dịch được phần iOS. Tài liệu này ghi những gì đã chuẩn bị trong mã nguồn, những gì iPhone làm được và không làm được, và cách nhóm tự thử khi có Mac.

## Kết luận

| Vai trò | Trên iPhone |
|---|---|
| **Người con** (trưởng nhóm, thành viên) | **Dùng được** sau khi build: đăng nhập, nhóm, tab Hôm nay, đánh dấu giúp, lịch, thuốc và ảnh, Quét OCR, cài đặt |
| **Người già** | **Không hỗ trợ.** Màn hình ghép máy trên iPhone hiện "Máy của bố mẹ cần là điện thoại Android" |
| **Admin** | Dùng được (chỉ là màn hình số liệu) |

## Vì sao máy người già phải là Android

Giá trị cốt lõi của app (kế hoạch mục 2, 9) là **đổ chuông và đọc tên thuốc liên tục đến khi người già xác nhận**, kể cả khi app đã đóng, màn hình khóa, mất mạng. Trên iOS:

| Cần cho người già | Android (đã làm) | iOS |
|---|---|---|
| Báo đúng giờ khi app đã đóng | `AlarmManager.setAlarmClock` | Được bằng thông báo cục bộ |
| Chuông kêu đến khi xác nhận | Foreground service phát liên tục | **Không.** Âm thanh của thông báo cục bộ tối đa khoảng 30 giây, rồi im |
| Đọc tên và mô tả thuốc bằng giọng nói lặp lại | TTS trong foreground service, luồng báo thức | **Không** khi app chưa được mở: iOS không cho app tự chạy mã ở nền để đọc liên tục |
| Màn hình báo hiện trên màn hình khóa | Full-screen intent | **Không.** Chỉ có banner thông báo; người già phải tự mở |
| Kêu cả khi máy để im lặng | Luồng âm thanh báo thức | Chỉ với "Critical Alerts", cần Apple cấp quyền đặc biệt (thường dành cho ứng dụng y tế, an ninh) |
| Tự tải lịch định kỳ | Đồng bộ nền 3 giờ | Không đảm bảo (Background App Refresh do iOS quyết định lúc nào chạy) |

Vì vậy, thay vì làm một bản người già "nửa vời" dễ khiến gia đình tin nhầm, app chặn rõ vai trò người già trên iPhone.

## Đã chuẩn bị trong mã nguồn

- Mọi lệnh gọi xuống phần báo thức gốc (`AlarmChannel`) không làm hỏng app trên iOS: `ringingId()` và `ringingIds()` trả "không có gì" (router hỏi mỗi lần chuyển màn hình), `AlarmChannel.supported` chỉ đúng trên Android; có test (`test/reminder/alarm_channel_test.dart`).
- `ios/Runner/Info.plist`: tên hiển thị "An Tâm", lời giải thích quyền Camera và Thư viện ảnh (bắt buộc khi chụp ảnh thuốc và Quét OCR).
- Mức iOS tối thiểu 15.5 (yêu cầu của ML Kit nhận dạng chữ).
- Thông báo đẩy: cấu hình Firebase qua `--dart-define`, nhưng trên iOS còn cần APNs (xem dưới).

## Cách thử khi có Mac

Cần: macOS, Xcode, CocoaPods, tài khoản Apple ID (miễn phí đủ để cài lên iPhone của mình 7 ngày; **Apple Developer Program trả phí** nếu muốn thông báo đẩy hoặc phát hành). Nhóm tự đăng ký và đồng ý điều khoản.

```bash
cd app && flutter pub get && cd ios && pod install && cd ..
```

Mở `ios/Runner.xcworkspace` trong Xcode, chọn Team ở **Signing & Capabilities**, cắm iPhone, rồi:

```bash
flutter run --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

iPhone chỉ gọi được địa chỉ HTTPS (đường hầm), không gọi `http://` của laptop.

**Thông báo đẩy trên iPhone** (tùy chọn): bật capability Push Notifications, tạo APNs key trong tài khoản Apple Developer, tải lên Firebase (Project settings → Cloud Messaging → Apple app configuration), rồi build với các `--dart-define` Firebase như trong SETUP.

## Cần kiểm tra khi build lần đầu

| Màn hình | Kiểm tra |
|---|---|
| Chào, đăng nhập, đồng ý | Hiện đúng, chuyển màn hình được (lỗi đã sửa: router từng gọi kênh báo thức không tồn tại trên iOS) |
| Hôm nay, Lịch, Cài đặt | Như Android |
| Thêm thuốc, chụp ảnh | iOS hỏi quyền Camera với lời giải thích tiếng Việt |
| Quét OCR | ML Kit đọc chữ trên máy; cắt ảnh bằng TOCropViewController |
| "Tôi là bố / mẹ" | Hiện thông báo cần điện thoại Android |
| Gọi điện | Mở trình gọi điện của iPhone |
