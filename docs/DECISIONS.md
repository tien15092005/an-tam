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
- **Nhóm gia đình kiểu Messenger:** mỗi nhóm 1 trưởng nhóm có quyền cao nhất đặt lịch; một người con ở được nhiều nhóm; một người già chỉ ở 1 nhóm; ~~có chat chữ đơn giản, bắt buộc (08/11/2026)~~: đã bỏ ngày 24/11/2026, xem mục "Bỏ chat nhóm".
- **Thuốc:** có thêm, sửa, xóa; đổi tên chức năng thành "Quét OCR"; đọc được toa, bao bì, hóa đơn; có ảnh và mô tả hình dạng, màu để người già phân biệt.
- **Báo thức:** giọng đọc lặp liên tục đến khi xác nhận, giữ nút hoãn 10 phút; sau khi xác nhận hỏi có vấn đề gì không, báo cho các con rồi dừng.

**Mặc định do người viết kế hoạch đề xuất, chờ nhóm xác nhận:** thành viên vẫn đánh dấu giúp và xử lý cảnh báo được; có nút "Không uống được"; hết 2 phút không trả lời câu hỏi thì tự kết thúc; người con đánh dấu giúp cũng dừng báo.

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

- Nghỉ 20 giây sau mỗi lần đọc xong. Mỗi lần báo tối đa 2 phút, tối đa 3 lần báo (xem mục "Giới hạn số lần báo").
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
- **Trạng thái liều và triển khai lịch** viết 2 lần (Java ở backend, Dart ở app) và cùng chạy bộ test vector `shared/test-vectors/`. Quá 30 phút chưa xác nhận là "lỡ"; thuốc thêm sau giờ uống trong ngày thì liều đó không tính và không báo.
- **Lưu offline bằng drift (SQLite)** đúng mục 3 của kế hoạch: bảng thuốc, ảnh, thông tin đồng bộ. App cũng lưu thông tin tài khoản lần cuối để khi mất mạng người già vẫn vào thẳng trang chủ.
- **Báo thức:** đặt cho 7 ngày tới, mỗi phút có thuốc một báo thức; các thuốc cùng giờ được đọc chung. Id báo thức = 100.000.000 + số phút tính từ 1970, nên màn hình báo biết ngay thuốc nào đến giờ kể cả khi mất mạng hoặc vừa khởi động lại máy. Hàm native `replaceSchedule` hủy những báo thức không còn trong lịch (thuốc đã xóa); báo thức hoãn 10 phút dùng dải id riêng nên không bị hủy nhầm. Mỗi lần tắt báo thức app lại đặt tiếp, nên cửa sổ 7 ngày luôn được kéo dài.
- **Giới hạn đã biết (đã xử lý 10/11/2026):** nếu người già không mở app và không có báo thức nào kêu trong 7 ngày, báo thức sẽ hết. Nay có đồng bộ nền mỗi 3 giờ (xem mục Đồng bộ nền dự phòng). Điện thoại được coi là đang ở múi giờ của người già.
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

## Giai đoạn 6 (09/11/2026)

- **Hàng đợi thông báo (`notification_outbox`):** mọi thông báo được ghi trong cùng giao dịch với sự kiện, một dòng cho mỗi người nhận, khóa `dedupe_key` (ví dụ `alert:42:7`) nên gửi lại báo cáo hay quét lại không tạo thông báo thứ hai. Một tác vụ nền gửi mỗi 3 giây và chạy ngay khi backend khởi động, nên thông báo tồn lúc laptop tắt sẽ đi ngay khi bật lại. Độ trễ (tạo → giao cho FCM) đo bằng Micrometer `antam.notifications.latency` ở `/actuator/metrics`.
- **FCM:** backend dùng Firebase Admin SDK 9.9.0, chỉ bật khi có biến `FIREBASE_CREDENTIALS` trỏ tới file service account (để ngoài Git, thư mục `secrets/`). App nhận cấu hình Firebase qua `--dart-define` (không cần `google-services.json` trong repo). Thiếu cấu hình thì thông báo được đóng là `DISABLED` và app tự làm mới: tab Hôm nay mỗi 30 giây và khi quay lại app. Chưa thử được với Firebase thật vì nhóm chưa tạo project.
- **firebase_messaging 17** khuyên dùng FID thay cho registration token. Backend gửi bằng `Message.setToken`, nên app vẫn dùng `getToken()` (đánh dấu `ignore: deprecated_member_use` kèm lý do). Đổi sang FID khi Admin SDK hỗ trợ gửi theo FID.
- **`NOT_CONFIRMED`:** quét mỗi phút, xét 24 giờ gần nhất, một cảnh báo cho mỗi giờ uống (chỉ mục duy nhất một phần trong PostgreSQL nên chạy hai lần vẫn chỉ có một). Nội dung ghi "chưa xác nhận", "máy có thể đang tắt hoặc mất mạng", không khẳng định đã quên. Máy người già đã ngừng kêu sau lần báo thứ 3. Cảnh báo tự đóng khi mọi thuốc của giờ đó có câu trả lời (từ người già hoặc người con đánh dấu giúp), ghi người đóng.
- **Đánh dấu giúp:** chỉ `TAKEN`, trong 7 ngày gần đây, không sớm hơn giờ uống quá 2 giờ, chỉ cho thuốc có lịch đúng giờ đó; câu trả lời đầu tiên được giữ. Hoàn tác chỉ áp dụng cho lần đánh dấu giúp, không xóa được câu trả lời của người già. Có ghi `audit_logs`.
- **Dừng báo trên máy người già:** FCM data message `DOSE_MARKED` khi có Firebase; ngoài ra màn hình báo hỏi server mỗi 20 giây khi có mạng, thấy mọi thuốc của lần báo đã có câu trả lời thì dừng và đọc "Con đã ghi nhận ... uống thuốc rồi ạ". Mất mạng thì vẫn báo đến khi người già trả lời (đúng mục 9).
- **Giao diện người con 4 tab** (Hôm nay, Lịch, Nhóm, Cài đặt) với bộ chuyển nhóm ở tiêu đề; app mở lại nhóm dùng gần nhất.
- **Lỗi bố cục tìm được khi thử:** theme đặt kích thước nút tối thiểu là `Size.fromHeight` (rộng vô hạn). Nút như vậy đặt trong `Row` làm tab Hôm nay đơ hẳn. Các nút trong hàng nay đặt `minimumSize: Size(0, 48)`; có test widget chống lặp lại.

## Giai đoạn 7 (09/11/2026)

- **Lịch tập** có bảng riêng (`exercises`, `exercise_logs`), cùng cách đánh phiên bản như thuốc (đổi giờ hoặc ngày sau khi đã có lịch sử thì đóng bản cũ, tạo bản mới cùng `series_id`).
- **Một báo thức mỗi phút cho cả thuốc và bài tập:** không phải sửa phần Java; id báo thức vẫn là phút. Chỉ có bài tập thì màn hình báo hiện "Đến giờ tập thể dục" và nút **TÔI ĐI TẬP ĐÂY**, không hỏi vấn đề. Trùng giờ với thuốc thì đọc thuốc trước, bài tập sau; thẻ bài tập có nút riêng.
- **Lịch tuần, tháng:** API `GET /calendar?from&to` (tối đa 62 ngày) trả số đếm theo ngày, tính bằng cùng hàm trạng thái với tab Hôm nay. Chấm màu theo việc tệ nhất trong ngày (đỏ chưa xác nhận, cam không uống được, xanh lá uống đủ, xanh đậm còn lần sắp tới); mỗi ô có nhãn TalkBack bằng chữ. Bấm ngày mở bottom sheet chi tiết; trưởng nhóm thêm thuốc hoặc lịch tập bắt đầu từ ngày đó.
- Không thêm thư viện lịch; lưới lịch tự vẽ để kiểm soát nhãn trợ năng.

## Giai đoạn 8 (09/11/2026)

- **Đọc chữ trên máy** bằng `google_mlkit_text_recognition` 0.17.1 (bản 1.0.x ra chưa đủ 2 tuần nên chưa dùng), cắt ảnh bằng `image_cropper` 13. Ảnh giấy tờ không rời máy; chỉ văn bản đã lọc dòng cá nhân (họ tên, địa chỉ, điện thoại, số thẻ, chẩn đoán, mã số dài) được gửi. AI service lọc lại lần nữa.
- **Bản nền** viết lại từ `prescription.py`: tách toa thuốc, bao bì, hóa đơn. Khác bản mẫu ở một điểm an toàn: **không tự gán giờ uống** khi giấy không ghi (bản mẫu mặc định 07:30); trường không chắc để trống, nằm trong `uncertain` và được tô vàng ở màn hình duyệt. Lưu thuốc mà chưa có giờ thì app yêu cầu chọn giờ.
- **Bộ đánh giá** 32 mẫu tự soạn, chia dev/test; kết quả trong `ai-service/evaluation/REPORT.md`. Chưa thử LLM hay mô hình ngoài vì cần nhóm đồng ý (dữ liệu rời máy chủ, có chi phí).
- **Lỗi thật khi thử trên máy ảo:** ML Kit đọc "500mg" thành "50Omg". AI service nay sửa chữ O hoặc l kẹp giữa các chữ số hoặc giữa số và đơn vị (không đụng chữ trong tên thuốc).
- **Lỗi kết nối backend → AI:** HttpClient của Java xin nâng cấp HTTP/2 (h2c), uvicorn từ chối và làm rơi thân request (lỗi 422). Backend nay ép HTTP/1.1; test kiểm tra không còn header `Upgrade`.
- AI lỗi hoặc quá 5 giây: backend trả 503 `ai_unavailable`, app đề nghị "Nhập tay".

## Giai đoạn 9 (09/11/2026)

- **WebSocket thuần của Spring** tại `/ws/chat` (không dùng STOMP cho gọn). Bắt tay đi qua bộ lọc bảo mật thường, nên cần đúng header `Authorization: Bearer` như REST. Đăng ký theo nhóm; server kiểm tra quyền khi đăng ký và **mỗi lần gửi**, nên người bị xóa khỏi nhóm không nhận thêm tin dù socket còn mở.
- Tin được đẩy **sau khi giao dịch commit**. Mất kết nối thì app thử lại với thời gian chờ tăng dần (1 → 30 giây) và tải lại trang mới nhất qua REST, nên không sót tin.
- Gửi lại không trùng nhờ `UNIQUE(sender_id, client_message_id)`. Chưa đọc tính theo `last_read_message_id`, không bao giờ lùi. Chỉ người gửi xóa được tin (nội dung bị ẩn với mọi người).
- **Tin hệ thống:** báo cáo uống thuốc, mọi cảnh báo (kèm `alert_id`, bấm mở tab Hôm nay), đánh dấu giúp, thêm, sửa, xóa thuốc và lịch tập.
- Tab Nhóm là chat; danh sách thành viên mở từ đầu trang chat và có trong tab Cài đặt. Chat chỉ dựng khi tab đang mở, để tin chỉ được đánh dấu đã đọc khi có người xem.

## Giai đoạn 10 (09/11/2026)

- **Admin** (`SYSTEM_ADMIN`) chỉ được tạo từ `ADMIN_EMAIL`, `ADMIN_PASSWORD` khi backend khởi động; không có đăng ký admin. Admin không là thành viên nhóm nào, nên mọi API của nhóm (thuốc, ảnh, chat, liều, cảnh báo) trả 404 cho admin; có test cho từng loại.
- **Khóa tài khoản có hiệu lực ngay:** thu hồi mọi refresh token, và một bộ lọc sau bước xác thực JWT từ chối mọi request của tài khoản bị khóa (401 `account_disabled`), không phải chờ access token hết hạn.
- Admin xem tổng số người dùng theo loại, nhóm, cảnh báo đang mở, cảnh báo 7 ngày, tài khoản bị khóa; tìm tài khoản theo tên hoặc email. Không có số liệu sức khỏe.

## Giai đoạn 11 (09/11/2026)

- **Màn hình đồng ý** hiện một lần trước mọi màn hình khác (trừ báo thức đang kêu): dữ liệu thu thập, ai xem được, OCR, micro, xóa dữ liệu, và dòng "không tư vấn y khoa, nguy cấp gọi 115".
- **Xóa tài khoản:** `DELETE /api/me?confirm=true`. Trưởng nhóm còn anh chị em phải chuyển quyền trước. Rời mọi nhóm; tin nhắn của người đó bị ẩn; thiết bị và phiên bị xóa; dòng `users` được giữ ở dạng ẩn danh (không email, mật khẩu, số điện thoại) để lịch sử và khóa ngoại vẫn đúng (migration V7 cho phép trạng thái này). Nếu là người con cuối cùng, nhóm bị xóa cùng tên, số điện thoại, ghi chú sức khỏe của bố mẹ, ảnh thuốc và tin nhắn.
- **Ảnh đã xóa quá 30 ngày** được xóa khỏi ổ đĩa bằng tác vụ nền (lịch sử chỉ dùng `name_snapshot`).
- **Sao lưu:** `scripts/backup.ps1` (pg_dump và thư mục ảnh, giữ 14 bản, thư mục `backups/` không lên Git). **Dữ liệu demo giả:** `scripts/seed_demo.py`.
- **Bản phát hành:** ký bằng keystore của nhóm trưởng qua `android/key.properties` (không lên Git); thiếu thì ký bằng khóa debug và không được phát tán. Bản phát hành chỉ chấp nhận địa chỉ `https://` (Android cũng chặn HTTP ở bản này).
- **CI:** thêm `flutter test --coverage` và lưu `lcov.info`. Chưa đo độ phủ backend vì JaCoCo bản đang có chưa xác nhận hỗ trợ Java 25.

## Đồng bộ nền dự phòng (10/11/2026)

- **Vì sao:** khi chưa có Firebase, một thuốc mới thêm cho bố mẹ chỉ đến máy khi người già mở app hoặc có báo thức kêu. Kế hoạch (mục 9) yêu cầu "worker định kỳ là đường dự phòng".
- **Cách làm:** trên máy người già, một báo thức không chính xác (`setInexactRepeating`, 3 giờ, hệ thống gom chung với việc khác nên tốn ít pin) gọi `SyncReceiver`. Nếu app đang mở, việc tải lịch được giao cho chính app (tránh hai engine cùng ghi SQLite, đã gặp lỗi "database is locked"). Nếu app đã đóng, một Flutter engine không giao diện chạy hàm Dart `backgroundSync` (lib/main.dart): gửi hàng đợi, tải lịch, đặt lại 7 ngày báo thức, rồi báo xong (tối đa 50 giây). Không dùng WorkManager để khỏi thêm thư viện.
- Phần lịch của kênh `vn.antam/alarm` tách ra `AlarmChannelCore`, dùng chung cho màn hình và engine nền. Bật khi vào trang chính người già, tắt khi đăng xuất, tự đăng ký lại sau khi khởi động máy hoặc cập nhật app.
- Bản debug có hai tham số để thử: `--ez debugRunSync true` (chạy ngay) và `--ei debugSyncIntervalMin N` (rút chu kỳ).

## Giai đoạn 13: iPhone (10/11/2026)

- Không có máy Mac nên chưa build được iOS. Đánh giá chi tiết trong `docs/IPHONE.md`.
- **Người con dùng iPhone được; máy người già phải là Android.** iOS không cho chuông kêu và đọc liên tục khi app đóng (âm thanh thông báo tối đa khoảng 30 giây, không có full-screen trên màn hình khóa, không chạy nền tùy ý). Màn hình ghép máy người già trên iPhone nói rõ điều này thay vì cho một bản không đáng tin.
- Router hỏi "có báo thức đang kêu không" mỗi lần chuyển màn hình; trên iOS lệnh này từng ném lỗi và sẽ làm app người con đứng yên. Nay các lệnh hỏi trạng thái trả "không có gì" khi không có phần báo thức gốc (có test).
- `Info.plist`: lời giải thích quyền Camera, Thư viện ảnh; mức iOS tối thiểu 15.5 theo ML Kit.

## Bỏ chat nhóm (24/11/2026)

- **Vì sao:** thầy hướng dẫn chốt chat nhóm không thiết thực. Các con đã có Zalo hay Messenger để nói chuyện; việc app cần làm là nhắc thuốc và báo kết quả.
- **Đã gỡ:** gói `backend/.../chat`, WebSocket `/ws/chat`, thư viện `spring-boot-starter-websocket`, loại thông báo `CHAT`; app bỏ tab **Nhóm** (còn 3 tab: Hôm nay, Lịch, Cài đặt) và thư viện `web_socket_channel`. Danh sách thành viên vẫn ở tab Cài đặt.
- **Database:** migration `V8__drop_chat.sql` xóa `chat_messages`, `chat_read_states` và thông báo chat đang chờ. `V6__chat.sql` giữ nguyên vì Flyway cần lịch sử migration.
- **Mất gì:** các "tin hệ thống" trong chat (ai đổi lịch, ai đánh dấu giúp). Cảnh báo và báo cáo vẫn hiện ở tab Hôm nay và qua thông báo đẩy; ai đổi lịch vẫn ghi trong `audit_logs`.
- Test: backend 83 (bớt 6 test chat), app 83 (bớt 3 test chat), đều đạt.

## Các quyết định khác

- **Nền tảng:** Android là mục tiêu nghiệm thu. iPhone là phần mở rộng tùy chọn.
- **Git:** nhóm chọn làm trực tiếp trên nhánh `main` ở Giai đoạn 0.

## Giới hạn số lần báo (25/11/2026)

Trước đây máy kêu và đọc liên tục tới khi có người bấm, và "Nhắc lại sau 10 phút" bấm được mãi. Nếu người già để quên điện thoại hoặc đang ngủ, máy kêu cả tiếng, làm phiền cả nhà và tốn pin. Cách mới, tham khảo Medisafe và Apple Health:

| Thời điểm | Máy người già | Người con |
|---|---|---|
| Tới giờ | Báo tối đa 2 phút rồi im, hiện thông báo yên lặng "Chưa xác nhận" | |
| +10 phút | Tự báo lại (lần 2), tối đa 2 phút | |
| +20 phút | Báo lần 3, không còn nút "Nhắc lại" | |
| +30 phút | Không kêu nữa. Trang chính có thẻ "Thuốc HH:MM chưa trả lời" | Cảnh báo "chưa xác nhận", có nút Gọi và Đánh dấu đã uống |

- Bấm "Nhắc lại sau 10 phút" tính là một lần báo. Tổng cộng không quá 3 lần cho mỗi giờ uống.
- Người già trả lời muộn từ trang chính vẫn được ghi nhận; cảnh báo tự đóng và các con nhận tin kèm chữ "trả lời muộn".
- Người con đánh dấu giúp hoặc người già trả lời: máy hủy các lần báo lại còn chờ.
- Thời hạn "lỡ" đổi từ 60 xuống 30 phút ở cả backend, app và `shared/test-vectors/dose-status.json`.

## Giao diện mới (25/11/2026)

- Người con còn 3 tab: **Hôm nay** (một câu tóm tắt, mục "Cần bạn xem" chỉ hiện khi có chuyện, lịch trong ngày dạng dòng), **Thuốc** (dải 7 ngày, thuốc theo buổi, nút "+ Thêm": chụp toa, nhập tay, lịch tập), **Gia đình** (bố mẹ, các con, vài mục cài đặt).
- Bỏ chữ "nhóm" khỏi giao diện: không còn chọn nhóm ở đầu màn hình, "trưởng nhóm" gọi là "người đặt lịch thuốc". Phía máy chủ vẫn lưu theo nhóm.
- Bố mẹ: thẻ "Tiếp theo" viền xanh, việc đã xong tô xanh lá, 2 nút lớn cố định ở cuối; màn báo thức nền sáng, nút ĐÃ UỐNG RỒI to nhất.
- Màu chủ đạo xanh lam đậm thay cam đất; có bản sáng và tối theo cài đặt điện thoại; chữ đạt tương phản 7:1 (chữ chính) và 4.5:1 (chữ phụ, màu trạng thái), có test kiểm tra.
- Kiểu chữ Lexend (thiết kế để dễ đọc, đủ dấu tiếng Việt) thay Be Vietnam Pro, đóng gói trong app.
- "Tôi thấy không khỏe" rút gọn thành "Tôi thấy mệt", vẫn gửi cảnh báo `UNWELL`.

## Chuông dự phòng khi thiếu giọng tiếng Việt (28/11/2026)

Khi thử trên máy thật, máy không có giọng tiếng Việt nên báo thức chỉ rung và hiện màn hình, không có tiếng. Giờ máy phát chuông báo thức mặc định (lặp lại, luồng báo thức) thay cho giọng đọc, tạm dừng khi người già đang trả lời bằng giọng nói, và tắt cùng lúc với báo thức. Vẫn nên cài giọng tiếng Việt (Kiểm tra máy nhắc mục này) để máy đọc tên thuốc.

## Sửa 2 lỗi nghiêm trọng từ bản review độc lập (28/11/2026)

Xem `docs/REVIEW.md`, mục N1 và N2.

- **N1, máy người già tự đăng xuất khi mạng chập chờn.**
  - Máy chủ: token làm mới vừa được đổi mà gửi lại trong vòng 2 phút (`antam.jwt.refresh-reuse-grace`), và token thay thế chưa từng được dùng, thì hiểu là phản hồi bị mất. Máy chủ bỏ token thay thế đó và cấp cặp mới, không thu hồi mọi phiên. Gửi lại muộn hơn, hoặc sau khi token mới đã được dùng, vẫn bị coi là token bị đánh cắp. Migration V9 lưu token thay thế (`replaced_by`).
  - App: máy người già bị máy chủ từ chối phiên thì **giữ nguyên lịch, báo thức và các câu trả lời chưa gửi**, hiện thẻ đỏ "Máy cần được ghép lại" và cho nhập mã mới. Nhập mã của cùng người già thì gửi tiếp các câu trả lời đang chờ; mã của người khác thì xóa dữ liệu cũ trước. Chỉ nút "Đăng xuất" mới xóa sạch máy. Hệ quả: máy cũ đã bị thay bằng máy mới vẫn nhắc theo lịch đã lưu, kèm thẻ đỏ.
- **N2, một múi giờ sai làm hỏng cảnh báo của mọi gia đình.**
  - Máy chủ từ chối múi giờ không hợp lệ (`invalid_timezone`). Migration V10 sửa các dòng cũ về `Asia/Ho_Chi_Minh`.
  - Mọi chỗ đọc múi giờ dùng `ElderProfile.zone()`, gặp giá trị hỏng thì dùng múi giờ mặc định.
  - Bước quét "chưa xác nhận" chạy mỗi người già trong một transaction riêng: một hồ sơ lỗi chỉ ghi log và bỏ qua, không chặn các gia đình khác.

