# Kịch bản demo nghiệm thu

Theo mục 13 của kế hoạch. Cần 3 máy: **A** trưởng nhóm, **B** thành viên, **C** máy người già (nên là Samsung thật). Chỉ dùng dữ liệu giả (`scripts/seed_demo.py` hoặc tự nhập tên giả).

## Chuẩn bị (trước buổi demo 30 phút)

1. Laptop: `docker compose up -d`, kiểm tra `/api/health` có `"ai":"UP"`.
2. Mở đường hầm: `cloudflared tunnel --url http://localhost:8080`, dán địa chỉ vào cả 3 máy (**Cài đặt máy chủ**).
3. Máy C: mở **Kiểm tra máy**, bật đủ các mục (thông báo, báo thức, màn hình khóa, pin không giới hạn, giọng tiếng Việt).
4. In sẵn 1 toa thuốc giả, 1 vỏ hộp và 1 hóa đơn (không có thông tin thật).
5. Tắt bớt ứng dụng trên laptop nếu chạy máy ảo (máy cần trên 4 GB RAM trống).

## Các bước

| # | Ai | Làm | Thấy gì |
|---|---|---|---|
| 1 | A | Đăng ký, tạo nhóm "Nhà bà Lan" | Tab Hôm nay trống, gợi ý thêm bố mẹ |
| 2 | A | Cài đặt → Mời anh chị em → gửi mã cho B | Mã 10 ký tự, hết hạn sau 7 ngày |
| 3 | B | Đăng ký, Nhập mã mời | Vào nhóm, là Thành viên |
| 4 | A | Thêm bố / mẹ "Bà Lan", tạo mã ghép máy | Mã 6 số, hết hạn 15 phút |
| 5 | C | Tôi là bố / mẹ, nhập mã | Trang chính chữ lớn |
| 6 | A, B | Cài đặt: xem danh sách bố mẹ và các con | Cả hai máy thấy đủ thành viên |
| 7 | A | Lịch → Thêm thuốc → **Quét OCR** vỏ hộp, rồi hóa đơn | Màn hình duyệt, ô vàng chỗ giấy không ghi; tự điền giờ; tích "Dùng ảnh này cho người già" |
| 8 | A | Chụp ảnh viên thuốc, thêm mô tả, đặt giờ cách 3 phút | Thuốc trong danh sách |
| 9 | B | Thử sửa thuốc | Không có nút sửa (API cũng từ chối) |
| 10 | C | Bật chế độ máy bay, vuốt tắt app | |
| 11 | C | Đến giờ | Đổ chuông, hiện ảnh, đọc tên và mô tả liên tục, kể cả khi màn hình khóa |
| 12 | C | ĐÃ UỐNG RỒI → "Mất thuốc" | Báo dừng; không có thông báo lỗi dù mất mạng |
| 13 | C | Tắt chế độ máy bay, mở app | Báo cáo tự gửi |
| 14 | A, B | | Cảnh báo đỏ ở tab Hôm nay; thông báo đẩy nếu đã cài Firebase |
| 15 | B | Bấm "Đã xử lý" | A thấy "đã xử lý" kèm tên B |
| 16 | A | Đặt thêm 1 giờ cách 3 phút, rồi để C không trả lời; B bấm **Đánh dấu** | Máy C ngừng báo trong khoảng 20 giây |
| 17 | A | Xóa một thuốc | Máy C không còn báo thuốc đó |
| 18 | C | Khởi động lại điện thoại | Báo thức tiếp theo vẫn kêu |
| 19 | Laptop | `docker compose stop ai-service` | |
| 20 | A | Quét OCR | Thông báo "Chưa đọc được", nút **Nhập tay** vẫn dùng được |

## Dự phòng

- Quay sẵn video các bước 10–18 trên điện thoại thật (báo thức là phần dễ hỏng nhất khi demo trực tiếp).
- Nếu đường hầm lỗi: dùng chung Wi-Fi và địa chỉ `http://<IP laptop>:8080` với bản debug.
- Ảnh chụp màn hình từng giai đoạn trong `docs/screenshots/`.
