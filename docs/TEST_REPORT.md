# Báo cáo kiểm thử

## Giai đoạn 0: Chuẩn bị (09/11/2026, máy nhóm trưởng)

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| `flutter doctor` cho Android | Đạt | Android toolchain ✓ (SDK 36.0.0). Visual Studio không cần |
| App chạy trên máy ảo | Đạt | Pixel 8, API 37, `vn.antam.app/.MainActivity` hiển thị |
| Docker Compose chạy cả hệ thống | Đạt | `db`, `ai-service`, `backend` đều chạy; `/actuator/health` = `UP` (có kiểm tra database) |
| 2 thành viên còn lại | Hoãn | Theo quyết định của nhóm trưởng |

## Giai đoạn 1: Khung xuyên suốt (09/11/2026)

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Test tự động | Đạt (trên máy) | Flutter 5/5, `flutter analyze` không lỗi; backend 2/2; AI service 5/5 |
| CI trên GitHub | Chưa kiểm chứng | Đã viết `.github/workflows/ci.yml`, chưa chạy vì code chưa được đẩy lên |
| Backend gọi AI service có xác thực | Đạt | `/api/health` → `"ai":"UP"` qua Docker; AI từ chối khi thiếu hoặc sai token (test) |
| App gọi backend | Đạt | Máy ảo → `http://10.0.2.2:8080`: Máy chủ và Dịch vụ AI "Hoạt động" |
| Backend qua đường hầm HTTPS | Đạt | `curl https://<quick-tunnel>.trycloudflare.com/api/health` → `{"status":"UP","ai":"UP"}` |
| App trên máy ảo dùng đường hầm | Đạt | Địa chỉ lưu trong app là địa chỉ `https://...trycloudflare.com`, cả hai mục "Hoạt động" (`docs/screenshots/phase1-connection.png`) |
| Máy thật dùng 4G | **Chưa làm** | Chưa có điện thoại Samsung kết nối |
| Gửi thông báo FCM | **Chưa làm** | Chưa có project Firebase và file cấu hình |

## Giai đoạn 2: Thử nghiệm báo thức (09/11/2026, máy ảo Pixel 8 API 37)

Bấm "Báo sau 15 giây / 1 phút / 5 phút" trong màn hình Thử nghiệm báo thức, theo dõi log `AnTamAlarm`.

| Tình huống | Đúng giờ | Giọng đọc (ALARM) | Màn hình báo |
|---|---|---|---|
| App đang mở | Đạt | Đạt | Tự hiện |
| App ở nền, máy đang mở khóa | Đạt | Đạt | Thông báo nổi (giới hạn của Android) |
| App bị tắt (tiến trình chết, khởi động lại để báo) | Đạt | Đạt | Thông báo nổi |
| Màn hình tắt / khóa | Đạt | Đạt | Tự bật màn hình và hiện |
| Chế độ máy bay + khóa | Đạt | Đạt | Tự hiện |
| Khởi động lại máy (báo đặt trước khi tắt máy) | Đạt | Đạt | Thông báo nổi (máy ảo tự mở khóa) |
| Bấm "ĐÃ UỐNG RỒI" | Dừng ngay, service tắt | | |
| Đọc lặp khi màn hình tắt | Đạt trong khoảng 3 phút (lượt 4→10, cách nhau ~30 giây) | | |

**Chưa đạt tiêu chí DoD:**

- Chưa thử trên **Samsung thật** (bắt buộc theo kế hoạch). Chế độ tiết kiệm pin của Samsung có thể làm khác máy ảo.
- Đọc liên tục mới thử khoảng 3 phút, chưa đủ 30 phút. Nhóm trưởng quyết định bỏ qua bài thử dài trên máy ảo; cần thử lại trên Samsung.
- Lệch giờ: mọi lần báo trong vòng 1–2 giây so với giờ đặt (đo theo log), nhưng chưa thử khi máy ở chế độ Doze lâu.

**Lỗi đã sửa trong lúc thử:** màn hình báo không tự hiện khi app đang mở; kiểm tra giọng tiếng Việt báo sai; cờ "đang reo" còn sót sau khi cài lại app.

## Giai đoạn 3: Tài khoản và nhóm gia đình (09/11/2026)

**Test tự động backend: 19/19 đạt** (`mvnw test`, PostgreSQL 18 thật qua Testcontainers).

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Ma trận quyền mục 5 | Đạt | `GroupAuthorizationTest`: trưởng nhóm, thành viên, người già, người ngoài thử từng hành động; người ngoài nhận 404 |
| Một người con ở 2 nhóm và chuyển được | Đạt (API) | `aCaregiverCanBeInSeveralGroupsAndSwitchBetweenThem`; app có danh sách nhóm để chọn |
| Không thể có 2 trưởng nhóm / người già ở 2 nhóm | Đạt | `GroupConstraintsTest`: database từ chối bằng partial unique index |
| Ghép đúng trên thiết bị | Đạt một phần | Trên máy ảo: đăng ký người con → tạo nhóm → thêm "Ba Lan" → lấy mã → đăng xuất → nhập mã → vào màn hình người già (`docs/screenshots/phase3-*.png`). Chưa thử 2 máy cùng lúc |
| Mã hết hạn, đã dùng, thử quá số lần bị từ chối | Đạt | Mã dùng 1 lần; mã mới hủy mã cũ; 10 lần sai liên tiếp → 429 |
| Phiên đăng nhập | Đạt | Refresh token xoay vòng; dùng lại token đã đổi → thu hồi mọi phiên; ghép máy mới → máy cũ bị đăng xuất mà không ảnh hưởng máy mới |

**Lỗi phát hiện và đã sửa:** máy cũ thử đăng nhập lại từng làm mất phiên của máy mới (nhầm với dùng lại token bị đánh cắp); PostgreSQL 18 từ chối múi giờ `Asia/Saigon` của Java trên Windows (backend nay chạy UTC).

**Giới hạn:** khi đi qua đường hầm, mọi request có cùng địa chỉ IP nên giới hạn số lần thử theo IP thành giới hạn chung cho tất cả.

**Vấn đề phát hiện (Giai đoạn 1):**

- Thư mục dự án nằm trong OneDrive. OneDrive giữ file trong `app/build` làm `flutter test` và build Android lỗi ngẫu nhiên. Tạm xử lý bằng cách xóa `app/build` rồi chạy lại.
- Máy ảo chạy tốt nhất ở chế độ đồ họa phần mềm; lần đầu khởi động khoảng 3 phút.
