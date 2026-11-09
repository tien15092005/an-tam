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

## Giai đoạn 4 (09/11/2026)

- **Sửa thuốc có lịch sử thì tạo phiên bản mới:** nếu thuốc đã có lần uống được ghi và giờ/ngày/liều thay đổi, bản cũ kết thúc hôm qua, bản mới bắt đầu hôm nay cùng `series_id`; ảnh chuyển sang bản mới. Chưa có lịch sử thì sửa tại chỗ.
- **Xóa thuốc là xóa mềm** (`active = false`): máy người già thôi báo, nhật ký uống và audit vẫn còn.
- **`schedule_version`** của nhóm tăng sau mọi thay đổi thuốc hoặc ảnh. Máy người già tải lại lịch khi mở app, khi quay lại app, khi kéo để làm mới và sau mỗi lần tắt báo thức. Chưa có FCM nên khi app đóng hẳn, máy người già chỉ nhận thay đổi ở lần mở app tiếp theo.
- **Ảnh thuốc:** server giải mã rồi mã hóa lại JPEG (bỏ EXIF, cạnh dài tối đa 1600px, tối đa 4 ảnh/thuốc, 5MB). Ảnh không bao giờ sửa (ảnh mới có id mới), nên máy người già tải mỗi ảnh một lần và lưu trong thư mục riêng của app.
- **Trạng thái liều và triển khai lịch** viết 2 lần (Java ở backend, Dart ở app) và cùng chạy bộ test vector `shared/test-vectors/`. Quá 60 phút chưa xác nhận là "lỡ"; thuốc thêm sau giờ uống trong ngày thì liều đó không tính và không báo.
- **Lưu offline bằng drift (SQLite)** đúng mục 3 của kế hoạch: bảng thuốc, ảnh, thông tin đồng bộ. App cũng lưu thông tin tài khoản lần cuối để khi mất mạng người già vẫn vào thẳng trang chủ.
- **Báo thức:** đặt cho 7 ngày tới, mỗi phút có thuốc một báo thức; các thuốc cùng giờ được đọc chung. Id báo thức = 100.000.000 + số phút tính từ 1970, nên màn hình báo biết ngay thuốc nào đến giờ kể cả khi mất mạng hoặc vừa khởi động lại máy. Hàm native `replaceSchedule` hủy những báo thức không còn trong lịch (thuốc đã xóa); báo thức hoãn 10 phút dùng dải id riêng nên không bị hủy nhầm. Mỗi lần tắt báo thức app lại đặt tiếp, nên cửa sổ 7 ngày luôn được kéo dài.
- **Giới hạn đã biết:** nếu người già không mở app và không có báo thức nào kêu trong 7 ngày, báo thức sẽ hết. Sẽ xử lý bằng FCM hoặc WorkManager ở Giai đoạn 6. Điện thoại được coi là đang ở múi giờ của người già.
- **Đăng xuất (hoặc server báo phiên đã hết, ví dụ đã ghép máy mới):** máy xóa lịch, ảnh và mọi báo thức, để máy cũ không kêu song song với máy mới.
- **Build Android (sửa lại ở Giai đoạn 5):** lỗi "Unable to delete directory" có 2 nguyên nhân riêng. (1) Tính năng theo dõi file của Gradle giữ khóa thư mục giữa các lần build trên Windows: đã tắt bằng `org.gradle.vfs.watch=false`. (2) Plugin như `image_picker` sinh đường dẫn dài hơn 260 ký tự trong `.transforms`; Gradle tạo được nhưng không xóa được khi Windows chưa bật Long Paths. Cách sửa gốc là bật `LongPathsEnabled` (người dùng máy tự làm, cần quyền admin; xem SETUP). Trước mắt dùng `app/tool/build_apk.ps1` để xóa các thư mục đó bằng tiền tố `\\?\` trước khi build. Kết luận ở Giai đoạn 4 rằng chỉ cần build vào đường thật là chưa đúng; thay đổi đó đã được bỏ.

## Giai đoạn 5 (09/11/2026)

- **Một báo cáo cho một lần báo:** khi người già bấm ĐÃ UỐNG RỒI / KHÔNG UỐNG ĐƯỢC, máy ghi ngay trên máy (trang chính hiện "Đã uống") và tạo một báo cáo trong hàng đợi. Báo cáo chờ câu trả lời "có vấn đề gì không" (tối đa 2 phút, quá thì là `NO_RESPONSE`) rồi gửi một lần `POST /api/me/dose-reports`, gồm mọi thuốc của lần báo đó. App bị tắt giữa chừng thì lần mở sau tự chốt `NO_RESPONSE`.
- **Không trùng khi gửi lại:** mỗi báo cáo có `clientEventId`. Id của từng nhật ký uống được suy ra từ id báo cáo và id thuốc (UUID theo tên); cảnh báo dùng chính id báo cáo; database có ràng buộc `UNIQUE`. Hai bản gửi cùng lúc thì bản đến sau nhận lỗi ràng buộc và được trả lời như một lần gửi lại. Một liều đã có câu trả lời thì giữ câu trả lời đầu tiên.
- **Câu trả lời → cảnh báo:** "Không có gì" và không trả lời thì không tạo cảnh báo; Mất thuốc, Hết thuốc, Thuốc trông khác, Không khỏe, Vấn đề khác tạo đúng loại cảnh báo tương ứng. KHÔNG UỐNG ĐƯỢC ghi `NOT_TAKEN` và hỏi lý do (không có nút "Không có gì"). Người già không thấy lỗi mạng; hàng đợi giữ thứ tự và tự gửi lại khi mở app, khi quay lại app, mỗi phút khi app đang mở và mỗi lần đồng bộ lịch.
- **Người con:** xem cảnh báo đang mở ở màn hình nhóm; người con nào cũng bấm "Đã xử lý" được và người xử lý đầu tiên được giữ lại. Màn hình thuốc có mục "Hôm nay bố mẹ đã báo". Thông báo đẩy để Giai đoạn 6, tin trong chat để Giai đoạn 9.
- **Báo thức gộp:** nếu báo thức mới kêu khi báo thức cũ chưa được trả lời, cả hai gộp vào cùng màn hình và cùng giọng đọc; danh sách id đang báo được lưu trên máy. Bấm trả lời thì danh sách được xóa ngay, để app không bị đẩy ngược lại màn hình báo.
- **Giọng nói: bấm để nói,** khác với kế hoạch (nghe tự động giữa các lượt đọc). Lý do: nghe tự động phải phối hợp micro với vòng đọc của foreground service, và không thử được trên máy ảo vì không có micro thật. Bấm để nói đơn giản hơn, rõ ràng hơn về quyền riêng tư (chỉ nghe khi bấm) mà vẫn giữ quy tắc: câu có "chưa"/"không" không bao giờ tính là đã uống, không chắc thì không ghi. Khi bấm, giọng báo thức tạm dừng 12 giây để micro không nghe chính máy. Có thể nâng lên nghe tự động sau khi thử trên Samsung.
- **Câu hỏi được đọc thành tiếng** trên luồng báo thức, 3 lần trong 2 phút. Máy không có giọng tiếng Việt thì không đọc bằng giọng tiếng Anh.
- **Gọi cho con:** danh bạ các con được lưu trên máy mỗi lần đồng bộ, nên vẫn gọi được khi mất mạng. "Tôi thấy không khỏe" hiện nút gọi con và dòng "Nếu nguy cấp, gọi cấp cứu 115"; app không đưa lời khuyên y khoa.
- **Kiểm tra máy:** thông báo, báo thức đúng giờ, màn hình khóa, pin, giọng tiếng Việt, micro (không bắt buộc). Mỗi mục có nút tới đúng trang cài đặt, kèm hướng dẫn cho Samsung. Trang chính hiện dòng nhắc khi còn thiếu mục bắt buộc.
- **Đồng bộ bị server từ chối (401/403) không còn bị coi là mất mạng.** Đăng xuất xóa cả hàng đợi, nhật ký trên máy và thông tin đồng bộ.

## Các quyết định khác

- **Nền tảng:** Android là mục tiêu nghiệm thu. iPhone là phần mở rộng tùy chọn.
- **Git:** nhóm chọn làm trực tiếp trên nhánh `main` ở Giai đoạn 0.
