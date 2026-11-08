# Nhật ký quyết định

## Công nghệ đã chốt (04/11/2026)

Nhóm chốt: **Flutter (Dart) cho app, Java Spring Boot cho backend, Python cho AI.** Thay thế các phương án trước: Expo + server Python (bản mẫu), và Kotlin + Firebase (chưa bắt đầu code).

- **Lý do của nhóm:** thống nhất theo trao đổi trong nhóm; thấy cú pháp Java đơn giản hơn Kotlin.
- **Rủi ro đã được nêu và nhóm chấp nhận:** khối lượng lớn hơn với 3 ngôn ngữ, phải tự làm đăng nhập, phân quyền, đồng bộ offline và có chỗ chạy server khi demo.
- **Cách giảm rủi ro:** deploy thử từ Giai đoạn 1; thử báo thức trên máy thật ở Giai đoạn 2; AI có bản nền và app vẫn chạy khi AI lỗi.

## Câu trả lời Giai đoạn 0

| Câu hỏi | Trả lời | Việc còn lại |
|---|---|---|
| Giảng viên | Yêu cầu Android Studio, chấp nhận Flutter | Hỏi thêm có chấm riêng backend và cách demo không |
| Hạn nộp | Chưa biết | Cập nhật khi có ngày; chưa lập lịch theo ngày |
| Điện thoại thật | Samsung, chưa rõ đời máy | Bắt buộc biết trước Giai đoạn 2 |
| Máy tính | Cả 3 người đều chạy được Android Studio (máy nhóm trưởng: RAM 15,4 GB) | Kiểm tra thêm Docker |
| Kinh nghiệm | Có người đã làm và deploy Spring Boot | Chưa hỏi kinh nghiệm Flutter và Python |
| Project Firebase | Nhóm trưởng sở hữu | Chỉ dùng cho FCM, không cần Firestore |
| Chạy backend khi demo | Laptop + đường hầm HTTPS | Xem giới hạn bên dưới |

## Chạy backend trên laptop qua đường hầm

Nhóm chọn cách này thay cho Azure for Students và Render.

**Giới hạn được chấp nhận:**

- Laptop phải bật và có mạng thì người con mới đồng bộ được và nhận được thông báo. Báo thức trên máy bố mẹ không bị ảnh hưởng.
- Khi laptop tắt, tác vụ tìm lần chưa xác nhận không chạy. Khi bật lại, tác vụ phải tự quét bù các lần đã bỏ lỡ.
- Đường hầm tạm có thể đổi địa chỉ mỗi lần chạy, nên địa chỉ server phải đổi được trong app. Chọn công cụ cụ thể ở Giai đoạn 1.
- Không phù hợp cho người dùng thật; chỉ dùng cho phát triển và demo.

## Docker Compose và REST + JSON (07/11/2026)

Nhóm giữ **Docker Compose** để chạy hệ thống và **REST + JSON** để các phần giao tiếp, không dùng gRPC.

- **Lý do chọn Docker:** cả 3 máy chạy giống nhau, một lệnh chạy toàn hệ thống, không phải tự cài PostgreSQL.
- **Lý do chọn REST + JSON:** dữ liệu nhỏ nên gRPC không mang lại lợi ích rõ rệt; REST dễ thử, dễ debug, dễ đi qua đường hầm HTTPS và dễ trình bày.
- **Khi phát triển:** có thể chỉ chạy PostgreSQL bằng Docker, backend chạy trong IDE để debug.

## Đổi phạm vi sản phẩm (08/11/2026)

Kế hoạch hiện hành: `docs/SKILL_AN_TAM.md`. File `docs/PROMPT_HOAN_THIEN_APP.md` đã cũ.

- **Bỏ** số đo sức khỏe. **Giữ** lịch tuần, lịch tháng, lịch tập thể dục.
- **Nhóm gia đình kiểu Messenger:** mỗi nhóm 1 trưởng nhóm có quyền cao nhất đặt lịch; một người con ở được nhiều nhóm; một người già chỉ ở 1 nhóm; có chat chữ đơn giản. **Chat là tính năng bắt buộc, không được cắt** (nhóm thống nhất ngày 08/11/2026).
- **Thuốc:** có thêm, sửa, xóa; đổi tên chức năng thành "Quét OCR"; đọc được toa, bao bì, hóa đơn; có ảnh và mô tả hình dạng, màu để người già phân biệt.
- **Báo thức:** giọng đọc lặp liên tục đến khi xác nhận, giữ nút hoãn 10 phút; sau khi xác nhận hỏi có vấn đề gì không, báo cho các con rồi dừng.

**Mặc định do người viết kế hoạch đề xuất, chờ nhóm xác nhận:** thành viên vẫn đánh dấu giúp và xử lý cảnh báo được; người già không thấy chat; có nút "Không uống được"; hết 2 phút không trả lời câu hỏi thì tự kết thúc; người con đánh dấu giúp cũng dừng báo.

**Giới hạn:** yêu cầu môn học trong file Word chỉ là khung báo cáo, không quy định công nghệ.

## Kết quả Giai đoạn 0 (09/11/2026)

- **Máy nhóm trưởng: đạt.** `flutter doctor` đạt cho Android; app chạy trên máy ảo Pixel 8 (API 37); Docker Compose chạy backend, PostgreSQL, AI service, backend báo `UP`.
- **2 thành viên còn lại: hoãn** theo quyết định của nhóm trưởng, làm khi code được đẩy lên GitHub.
- Máy ảo khởi động lần đầu mất khoảng 3 phút; cách xử lý ghi trong `docs/SETUP.md`.
- Nhóm trưởng yêu cầu làm tiếp các giai đoạn mà không cần hỏi xác nhận từng bước.

## Giai đoạn 1 (09/11/2026)

- **Đường hầm:** dùng Cloudflare Quick Tunnel (`cloudflared tunnel --url http://localhost:8080`). Không cần tài khoản, nhưng địa chỉ đổi mỗi lần chạy, không có cam kết hoạt động, và chịu điều khoản dịch vụ của Cloudflare. Đủ cho phát triển và demo; dùng thật thì cần named tunnel và tên miền riêng.
- **Backend gọi AI:** qua header `X-Service-Token`, giá trị trong `.env` (`AI_SERVICE_TOKEN`). `/health` của AI để công khai cho Docker kiểm tra; mọi API `/v1/*` bắt buộc có token.
- **App:** địa chỉ máy chủ mặc định `http://10.0.2.2:8080` (máy ảo gọi laptop), đổi được trong app và lưu lại. HTTP chỉ được phép ở bản debug.
- **Thư mục dự án trong OneDrive** gây lỗi khóa file khi build. Đề xuất chuyển dự án ra ngoài OneDrive, ví dụ `C:\dev\an-tam`. Chưa chuyển.

## Giai đoạn 2: chọn cách làm báo thức (09/11/2026)

**Chọn: code Java gốc qua platform channel** (`app/android/.../alarm/`, Dart: `lib/reminder/alarm_channel.dart`).

| Phương án | Đánh giá |
|---|---|
| Gói `alarm` | Chỉ phát được file âm thanh, không đọc giọng nói lặp lại; trên iPhone không reo khi app bị đóng |
| `flutter_local_notifications` | Chỉ hiện thông báo theo giờ, không có cơ chế đọc liên tục đến khi xác nhận |
| **Java gốc** | `AlarmManager.setAlarmClock` + foreground service (loại `mediaPlayback`) phát `TextToSpeech` qua luồng **ALARM**, lặp đến khi xác nhận; thông báo full-screen; tự đặt lại khi khởi động lại máy, cập nhật app, đổi giờ |

Hành vi đã chốt trong bản thử:

- Nghỉ 20 giây sau mỗi lần đọc xong. Không giới hạn số lần đọc.
- Vuốt bỏ thông báo không làm dừng báo. Chỉ dừng khi bấm xác nhận hoặc hoãn.
- Máy không có giọng tiếng Việt thì không đọc (tránh đọc như đánh vần), vẫn rung và hiện màn hình báo.
- Khi máy đang mở khóa và người dùng ở app khác, Android chỉ cho hiện thông báo nổi (không tự bật màn hình báo); giọng đọc vẫn chạy. Màn hình báo toàn trang tự hiện khi máy khóa, màn hình tắt, hoặc khi đang mở app An Tâm.

## Giai đoạn 3 (09/11/2026)

- **Đăng nhập:** access token JWT HS256 15 phút; refresh token ngẫu nhiên 32 byte, lưu SHA-256, xoay vòng mỗi lần dùng. Người con 30 ngày, người già 365 ngày (ghép một lần, không bị đăng xuất bất ngờ). Mật khẩu băm BCrypt, tối thiểu 8 ký tự.
- **Mã ghép máy:** 6 chữ số, 15 phút, 1 lần; lưu HMAC-SHA256 với `CODES_SECRET`. Chống dò: 10 lần/10 phút mỗi IP và 300 lần/10 phút toàn hệ thống. **Mã mời:** 10 ký tự không có ký tự dễ nhầm, 7 ngày, 1 lần.
- **Phân quyền:** kiểm tra trong `GroupAccess` ở tầng service cho mọi API nhóm. Người ngoài nhóm nhận 404 để không dò được id nhóm.
- **Database chặn sai sót:** partial unique index cho "1 trưởng nhóm/nhóm" và "người già chỉ 1 nhóm"; chuyển quyền hạ trưởng nhóm cũ trước rồi mới nâng người mới.
- **Rời nhóm:** thành viên rời ngay; trưởng nhóm phải chuyển quyền trước; người con duy nhất rời thì xóa nhóm (cần xác nhận) và đăng xuất máy người già.
- **Backend chạy UTC** (`TimeZone.setDefault` + `-Duser.timezone=UTC` cho test).
- **Thư mục `app/build`** là junction tới `C:\dev\antam-build\app` để tránh OneDrive khóa file.
- **Bí mật mới** trong `.env`: `JWT_SECRET`, `CODES_SECRET`.

## Các quyết định khác

- **Nền tảng:** Android là mục tiêu nghiệm thu. iPhone là phần mở rộng tùy chọn.
- **Git:** nhóm chọn làm trực tiếp trên nhánh `main` ở Giai đoạn 0.
