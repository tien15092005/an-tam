# Đánh giá mã nguồn độc lập – An Tâm

Ngày: 28/11/2026. Người đánh giá: một phiên Claude Code riêng, không viết phần mã nào ở đây.
Phạm vi: `backend/`, `app/` (Flutter + mã báo thức Android), `ai-service/`, `docker-compose.yml`, migration, `shared/test-vectors/`, `scripts/backup.ps1`.
Thước đo: một app chạy thật cho người dùng thật, không phải bản demo môn học.

Mọi nhận định dưới đây đều đã đọc trong mã, không dựa vào README hay tài liệu. Chỗ nào chưa chắc thì ghi **cần kiểm tra**.

## Đã chạy gì

| Lệnh | Kết quả |
|---|---|
| `./mvnw test` (backend) | 22 test đơn vị **đạt** (`SharedVectorsTest`, `HealthControllerTest`). 9 lớp test tích hợp (Care, Today, Group, Medication, Exercise, Admin, Ocr, AccountDeletion, GroupConstraints) **không chạy được** vì máy không bật Docker. Tôi không xác nhận được chúng đạt. |
| `flutter analyze` | 37 mục, toàn là `info` (import `material.dart` đã bị đánh dấu lỗi thời). Không có warning/error, nhưng lệnh trả mã thoát 1, nên một bước CI sẽ báo đỏ. |
| `flutter test` | 89 test **đạt**. |
| `pytest` (ai-service) | Không chạy: Python trên máy chưa cài pytest. |

---

## Các vấn đề, xếp từ nặng nhất

### Nghiêm trọng

#### N1. Máy người già có thể tự đăng xuất, xóa sạch lịch và ngừng báo thức mà không ai biết
- **Vị trí:** `backend/src/main/java/vn/antam/auth/TokenService.java:73`, `app/lib/features/auth/session.dart:124`, `app/lib/reminder/schedule_sync.dart:74`
- **Sai ở đâu:** Khi đổi refresh token, server đánh dấu token cũ là "đã xoay". Nếu token đã xoay được gửi lại, server coi là bị đánh cắp và thu hồi **mọi** phiên của người đó. Phía app, bất kỳ 401/403 nào lúc refresh đều gọi `signOutLocally()`, hàm này xóa lịch thuốc, xóa hàng đợi báo cáo chưa gửi (`pendingEvents`) và hủy mọi báo thức.
- **Tình huống:** Máy bà đi qua đường hầm Cloudflare, mạng 3G chập chờn. App gửi refresh, server đã xoay token và trả về, nhưng phản hồi bị rớt (hết 15 giây `receiveTimeout`). App vẫn giữ token cũ. Lần sau gửi lại token cũ → server thấy "token đã xoay" → thu hồi hết → 401 → app xóa lịch, xóa cả câu trả lời "Tôi thấy không khỏe" chưa kịp gửi, rồi im lặng. Bà không tự ghép lại máy được. Hôm đó không có chuông nào. Phía người con: sau 30 phút mới có cảnh báo "chưa xác nhận", và cảnh báo này lặp lại ở mọi cữ cho đến khi có người tới tận nơi ghép lại máy. Khôi phục database từ bản sao lưu cũ cũng gây ra đúng chuyện này cho mọi máy người già cùng lúc.
- **Cách sửa:** Cho phép dùng lại token vừa xoay trong một khoảng ngắn (ví dụ 1–2 phút, trả lại cặp token đã cấp) thay vì thu hồi tất cả. Trên máy người già, khi phiên hết hạn thì **giữ nguyên lịch và báo thức**, giữ hàng đợi, chỉ hiện màn hình "nhờ con ghép lại máy".

#### N2. Một múi giờ gõ sai làm hỏng cảnh báo "chưa xác nhận" của **mọi gia đình**
- **Vị trí:** `backend/src/main/java/vn/antam/group/ElderProfile.java:48`, `backend/src/main/java/vn/antam/group/GroupDtos.java:36`, `backend/src/main/java/vn/antam/care/DoseSweeper.java:67` và `:81`
- **Sai ở đâu:** Trường `timezone` của người già chỉ bị giới hạn ≤ 40 ký tự, không kiểm tra có phải múi giờ hợp lệ không. `DoseSweeper.sweep()` duyệt **tất cả** người già trong **một** transaction và gọi `ZoneId.of(...)`. Gặp chuỗi sai là ném `DateTimeException`, cả lượt quét rollback.
- **Tình huống:** Bất kỳ ai cũng đăng ký được tài khoản, tạo nhóm, thêm người già với `"timezone": "Asia/HoChiMinh"` (gõ thiếu gạch dưới) hoặc cố tình đặt sai. Từ phút đó, mỗi phút lượt quét đều lỗi và không gia đình nào nhận cảnh báo "chưa uống thuốc" nữa. Trong khi đó các API "Hôm nay", lịch, `/me/schedule` của nhóm đó trả 500.
- **Cách sửa:** Kiểm tra bằng `ZoneId.of` khi nhận yêu cầu (hoặc chỉ cho chọn từ danh sách), thêm migration sửa dữ liệu cũ. Trong sweeper, bọc từng người già bằng try/catch (hoặc transaction riêng) để một hồ sơ lỗi không chặn người khác.

### Cao

#### C1. Giới hạn số lần thử theo IP thực ra là giới hạn chung cho cả hệ thống
- **Vị trí:** `backend/src/main/java/vn/antam/auth/AuthController.java:53,69`, `backend/src/main/java/vn/antam/group/GroupController.java:70`, `backend/src/main/java/vn/antam/auth/AuthService.java:56,73-74`
- **Sai ở đâu:** IP lấy từ `getRemoteAddr()`, và `application.properties` không cấu hình `server.forward-headers-strategy`. Theo cách chạy trong tài liệu (cloudflared trên laptop → `localhost:8080` → container Docker), mọi request đều mang cùng một địa chỉ (gateway của Docker).
- **Tình huống:** Chỉ cần 10 mã ghép máy sai trong 10 phút, từ bất kỳ đâu, là **không người già nào** ghép máy được trong 10 phút. Có 20 lần đăng nhập sai là mọi người con bị chặn đăng nhập. Kẻ xấu chỉ cần gửi vài request mỗi phút là khóa cả hệ thống. Ngược lại, nếu sau này có người bật `forward-headers-strategy` mà không giới hạn proxy tin cậy, kẻ tấn công tự đặt `X-Forwarded-For` để vượt giới hạn.
- **Cách sửa:** Đọc IP thật từ header của Cloudflare (`CF-Connecting-IP`), và chỉ tin header đó khi request đến từ đường hầm. Giới hạn theo người dùng hoặc thiết bị, đừng chỉ theo IP. Giới hạn chung `pair:global` cũng là một cách để khóa cả hệ thống, nên đổi sang cơ chế làm chậm (backoff) thay vì chặn hẳn.

#### C2. Thông báo đẩy khẩn cấp bị bỏ sau khoảng 15 giây FCM trục trặc
- **Vị trí:** `backend/src/main/java/vn/antam/notification/OutboxEntry.java:21,89`, `backend/src/main/java/vn/antam/common/Jobs.java:49`, `backend/src/main/java/vn/antam/notification/OutboxDispatcher.java:46-65`
- **Sai ở đâu:** Mỗi bản ghi được thử tối đa 5 lần, mỗi lần cách 3 giây, không có thời gian chờ tăng dần (`next_attempt_at`). Hết 5 lần là đánh dấu `FAILED` và không bao giờ gửi lại. Mọi lệnh gọi FCM chạy bên trong **một** transaction cho cả lô 50 bản ghi. Một lỗi runtime không phải `FirebaseMessagingException` sẽ rollback cả lô, kể cả những tin đã gửi đi.
- **Tình huống:** FCM hoặc mạng laptop chập chờn 20 giây đúng lúc ông báo "Tôi thấy không khỏe". Cảnh báo chuyển sang `FAILED`, người con không nhận được push. Chỉ khi tự mở app mới thấy. Nếu có một bản ghi gây lỗi lạ, lô đó bị gửi lại mỗi 3 giây (người con nhận trùng) và chặn mọi tin xếp sau nó.
- **Cách sửa:** Thêm cột `next_attempt_at` với thời gian chờ tăng dần (10 giây → 1 phút → 5 phút…), giữ ít nhất vài giờ với tin khẩn. Gọi FCM ngoài transaction, đánh dấu từng bản ghi riêng, và bắt mọi `RuntimeException` theo từng bản ghi.

#### C3. Một ảnh nhỏ có thể làm backend hết bộ nhớ
- **Vị trí:** `backend/src/main/java/vn/antam/medication/ImageStore.java:58`
- **Sai ở đâu:** File ≤ 5 MB được đưa thẳng vào `ImageIO.read`, không kiểm tra kích thước điểm ảnh trước. Một PNG vài trăm KB có thể khai báo 50.000 × 50.000 px, và JVM sẽ cố cấp phát hàng GB.
- **Tình huống:** Ai cũng đăng ký được, tự làm trưởng nhóm, tải một "ảnh thuốc" như vậy lên. Backend gặp `OutOfMemoryError`. Toàn bộ dịch vụ, gồm cả lượt quét cảnh báo, chậm hoặc chết.
- **Cách sửa:** Dùng `ImageReader` đọc chiều rộng/cao từ header trước, từ chối nếu quá ngưỡng (ví dụ 40 triệu điểm ảnh), rồi mới giải mã (có thể giải mã thu nhỏ bằng `setSourceSubsampling`).

#### C4. "Xóa tài khoản và dữ liệu" không xóa hết dữ liệu nhận diện được và dữ liệu sức khỏe
- **Vị trí:** `backend/src/main/java/vn/antam/user/AccountController.java:76` (`purgeGroup`), `backend/src/main/java/vn/antam/group/GroupService.java:197`
- **Sai ở đâu:** `purgeGroup` chỉ xóa tên, số điện thoại, ghi chú trong `elder_profiles`, ẩn danh `users` và tắt thuốc. Những thứ sau vẫn còn: `notification_outbox.title/body` (tên gọi người già, tên người con, tên thuốc, ví dụ "Bà Lan chưa xác nhận… Metformin"), `alerts.medication_names`, `dose_logs.name_snapshot`, `medications.name/note`, `audit_logs.changes` (tên thuốc), năm sinh người già. Ngoài ra trưởng nhóm **không xóa được** một người già khỏi nhóm (chỉ xóa được người con), nên muốn xóa dữ liệu một người già thì phải xóa cả nhóm.
- **Tình huống:** Một gia đình yêu cầu xóa dữ liệu. Ai có quyền đọc database (quản trị, hoặc ai đó có bản sao lưu) vẫn ghép được "Bà Lan, sinh 1948, uống Metformin và Amlodipin 2 lần/ngày, hay báo mệt". Trường hợp hay gặp hơn: bố mất, gia đình muốn xóa hồ sơ của bố nhưng giữ hồ sơ của mẹ trong nhóm, và việc này không làm được.
- **Cách sửa:** Khi xóa nhóm, xóa hoặc ẩn danh cả `notification_outbox` (hoặc định kỳ dọn tin đã gửi sau vài ngày), `alerts.medication_names`, `audit_logs.changes`, tên trong dose log và thuốc, `birth_year`. Thêm API "xóa người già khỏi nhóm" cho trưởng nhóm, làm đúng các bước trên cho riêng người đó và thu hồi phiên trên máy họ.

#### C5. Cách vận hành hiện tại chưa chạy được cho người dùng thật
- **Vị trí:** `docker-compose.yml` (không có `restart:` và không có healthcheck cho backend), `app/lib/core/config/server_config.dart:5,20`
- **Sai ở đâu:** Backend chạy trên một laptop qua Cloudflare **Quick Tunnel**, nên địa chỉ đổi mỗi lần chạy lại. App mặc định `http://10.0.2.2:8080`, người dùng phải tự dán địa chỉ mới trên từng máy. Laptop ngủ hoặc tắt thì không ai nhận cảnh báo "chưa xác nhận". Container không tự khởi động lại sau khi laptop khởi động lại.
- **Tình huống:** Tối Chủ nhật laptop khởi động lại để cập nhật. Sáng thứ Hai địa chỉ đường hầm đã khác. Máy của bà vẫn reo chuông (vì báo thức nằm trên máy), nhưng mọi câu trả lời kẹt lại trong hàng đợi, người con không thấy gì, và không ai nhận cảnh báo. Bà không biết sửa địa chỉ máy chủ.
- **Cách sửa:** Trước khi có người dùng thật: chạy trên một máy chủ luôn bật (VPS) hoặc dùng named tunnel với tên miền cố định, build sẵn địa chỉ đó vào app (`API_BASE_URL`), thêm `restart: unless-stopped` và healthcheck cho backend, và theo dõi tối thiểu (cảnh báo khi `/api/health` tắt).

#### C6. Bản sao lưu ảnh có thể bị hỏng mà không ai biết; bản sao lưu không mã hóa (cần kiểm tra)
- **Vị trí:** `scripts/backup.ps1:14`
- **Sai ở đâu:** `docker compose exec … tar -czf - media > file.tgz`. Trong **Windows PowerShell 5.1** (bản mặc định trên Windows), `>` chuyển đầu ra của chương trình ngoài thành văn bản UTF-16, nên file `.tgz` nhị phân bị hỏng. PowerShell 7.4+ thì giữ nguyên byte. Script cũng không kiểm tra lại bản sao lưu (ví dụ `tar -tzf`), và file SQL (chứa dữ liệu sức khỏe) nằm dạng thường trong `backups/`.
- **Tình huống:** Ổ laptop hỏng, nhóm mở `media-*.tgz` thì giải nén không được: mất hết ảnh viên thuốc, thứ người già dựa vào để nhận ra thuốc.
- **Cách sửa:** Cho `tar` ghi file **bên trong** container rồi `docker compose cp` ra (hoặc bắt buộc `pwsh` 7.4+), sau mỗi lần sao lưu thì kiểm tra file, và mã hóa bản sao lưu. Cần thử khôi phục thật một lần.

### Trung bình

#### T1. Máy khởi động lại sau giờ uống thuốc thì cữ đó không reo
- **Vị trí:** `app/android/app/src/main/java/vn/antam/app/alarm/AlarmScheduler.java:105`
- **Sai ở đâu:** `rearmAll` bỏ qua mọi báo thức đã qua giờ, kể cả cữ vừa qua 1 phút và các lần nhắc lại đang chờ.
- **Tình huống:** Máy hết pin lúc 7:55, bà cắm sạc, máy lên lúc 8:03. Cữ 8:00 không reo lần nào. Màn hình chính có hiện "chưa trả lời", nhưng bà không nhìn màn hình.
- **Cách sửa:** Khi khởi động lại, báo thức nào trễ dưới khoảng 30 phút thì reo ngay (hoặc đặt lại lần nhắc kế tiếp), chỉ bỏ những cái quá cũ.

#### T2. Kiểm tra độ sẵn sàng không xem âm lượng báo thức
- **Vị trí:** `app/android/app/src/main/java/vn/antam/app/MainActivity.java:151`
- **Sai ở đâu:** Màn hình sẵn sàng kiểm tra thông báo, báo thức chính xác, toàn màn hình, pin và giọng Việt, nhưng không kiểm tra âm lượng luồng `STREAM_ALARM`.
- **Tình huống:** Người già hay vặn nhỏ hoặc tắt hẳn âm lượng. Âm lượng báo thức bằng 0 thì giọng đọc và chuông dự phòng đều không nghe thấy, nhưng màn hình vẫn báo "sẵn sàng".
- **Cách sửa:** Đọc `AudioManager.getStreamVolume(STREAM_ALARM)`, báo lỗi khi thấp hơn khoảng 50%, và có nút tăng âm lượng.

#### T3. Máy và server có thể dùng hai múi giờ khác nhau
- **Vị trí:** `app/lib/reminder/schedule_sync.dart:84` (dùng `DateTime.now()` theo giờ máy). App không đọc trường `timezone` trong `/api/me/schedule`.
- **Sai ở đâu:** Chuông reo theo múi giờ của điện thoại, còn server tính "chưa xác nhận" theo múi giờ trong hồ sơ.
- **Tình huống:** Máy cũ của bà tắt chế độ giờ tự động và đang để GMT+0. Chuông reo lúc 15:00 giờ Việt Nam cho cữ "8:00". Server báo cho người con là bà bỏ cữ 8:00 mỗi ngày.
- **Cách sửa:** Mở rộng lịch theo `timezone` server gửi về (gói `timezone`), hoặc ít nhất cảnh báo trên màn hình sẵn sàng khi múi giờ máy khác hồ sơ.

#### T4. Kẻ xấu có thể khóa đăng nhập của một người con cụ thể; đăng ký không bị giới hạn
- **Vị trí:** `backend/src/main/java/vn/antam/auth/AuthService.java:57`, `backend/src/main/java/vn/antam/auth/AttemptLimiter.java`
- **Sai ở đâu:** 8 lần sai trên một email là khóa 10 phút, ai biết email cũng làm được. `/register` không giới hạn. Map trong `AttemptLimiter` không bao giờ dọn các khóa cũ, nên kẻ gửi nhiều email ngẫu nhiên làm bộ nhớ tăng dần.
- **Cách sửa:** Làm chậm dần thay vì khóa hẳn, giới hạn đăng ký theo IP thật, dọn các khóa đã quá cửa sổ thời gian (hoặc dùng Caffeine/Bucket4j có thời hạn).

#### T5. Không có quên mật khẩu hay đổi mật khẩu
- **Vị trí:** cả `backend/` và `app/` không có API hay màn hình nào cho việc này.
- **Tình huống:** Trưởng nhóm quên mật khẩu thì không ai sửa được thuốc của bố mẹ nữa (chỉ trưởng nhóm có quyền) và không chuyển quyền được. Quản trị cũng không có công cụ nào để giúp.
- **Cách sửa:** Tối thiểu có "đổi mật khẩu" khi đang đăng nhập (đổi xong thu hồi các phiên khác) và một luồng đặt lại mật khẩu qua email.

#### T6. Mất máy người già: không có nút "đăng xuất máy này", phiên còn sống 365 ngày
- **Vị trí:** `backend/src/main/java/vn/antam/auth/TokenService.java:42`, `GroupService.createPairingCode` (tạo mã mới không thu hồi phiên cũ; chỉ khi mã được dùng mới thu hồi)
- **Tình huống:** Máy của ông bị mất. Người nhặt được vẫn xem được thuốc, ảnh thuốc, số điện thoại các con trong một năm, trừ khi gia đình ghép một máy khác.
- **Cách sửa:** Thêm API cho trưởng nhóm "đăng xuất máy của bố/mẹ" (gọi `revokeAll(elderId)` và xóa thiết bị FCM).

#### T7. Mã cũ không dùng nữa vẫn nằm trong repo
- **Vị trí:** `server.py` (1106 dòng), `prescription.py`, `public/`, `mobile/` (Expo), `database/`, phần "bản mẫu cũ" trong `.env.example` (`GOOGLE_API_KEY`…)
- **Vì sao đáng lo:** Người đọc mới không biết server nào là thật. Chạy nhầm `server.py` sẽ mở một server khác không qua các kiểm tra quyền của backend Java. File `.env.example` vẫn hướng dẫn đặt khóa Google không còn dùng.
- **Cách sửa:** Chuyển sang nhánh hoặc tag lưu trữ rồi xóa khỏi `main`, và bỏ biến cũ khỏi `.env.example`.

#### T8. Thiếu test ở đúng những chỗ dễ hỏng nhất
- **Vị trí:** `backend/src/test/`, `app/test/`. Mã Java báo thức trong `app/android/.../alarm/` và `sync/` không có test nào.
- **Chưa có test cho:** refresh khi mất phản hồi (N1), múi giờ sai (N2), giới hạn sau proxy (C1), retry và lỗi lạ trong outbox (C2), ảnh "bom" (C3), những gì còn lại sau khi xóa (C4), `signOutLocally` trên máy người già, background sync, khởi động lại máy (T1), engine báo thức Java (giới hạn 2 phút, 3 lần, id nhắc lại, chuông dự phòng). 9/11 lớp test backend cần Docker và không chạy được trên máy này; không có CI nào bắt buộc chạy chúng.
- **Cách sửa:** Thêm một CI (GitHub Actions có sẵn Docker) chạy `mvnw test`, `flutter test`, `pytest`. Thêm test JVM (Robolectric) cho `AlarmScheduler`/`AlarmService`, và test cho từng tình huống ở trên.

#### T9. Bản release lặng lẽ ký bằng khóa debug
- **Vị trí:** `app/android/app/build.gradle.kts:54`
- **Tình huống:** Máy build thiếu `key.properties` vẫn ra một APK "release" ký bằng khóa debug. Ai lỡ cài APK đó cho bà thì sau này không cập nhật đè được bằng bản ký đúng: phải gỡ app và ghép lại máy.
- **Cách sửa:** Làm build release báo lỗi khi thiếu khóa ký.

#### T10. Màn hình thử báo thức và chỗ đổi máy chủ nằm sẵn trong bản release
- **Vị trí:** `app/lib/app.dart:37,65`, `app/lib/features/system/connection_screen.dart:125`
- **Sai ở đâu:** `/spike/alarm` là route công khai, không cần đăng nhập, và có nút trong màn hình kết nối. Trên máy người già, ai cầm máy cũng đổi được địa chỉ máy chủ.
- **Tình huống:** Cháu nhỏ nghịch máy bà, bấm "Thử nghiệm báo thức" hoặc sửa địa chỉ máy chủ, và máy bà ngừng đồng bộ.
- **Cách sửa:** Chỉ hiện spike khi `kDebugMode`. Trên máy đã ghép thì khóa phần sửa máy chủ (ví dụ phải nhập mã do người con tạo).

### Thấp

| # | Vị trí | Vấn đề và cách sửa |
|---|---|---|
| L1 | `auth/AuthController.java:22` | `@Size(max = 72)` đếm ký tự, còn BCrypt giới hạn 72 **byte**. Mật khẩu tiếng Việt có dấu dài có thể vượt 72 byte, và Spring Security bản mới ném lỗi, thành lỗi 500 (cần kiểm tra). Nên kiểm tra theo byte UTF-8. |
| L2 | `auth/SecurityConfig.java` (`jwtDecoder`) | Không kiểm tra `iss` của JWT. Dùng chung một khóa HS256 thì rủi ro nhỏ, nhưng nên thêm validator issuer/audience. |
| L3 | `auth/TokenService.java:70` | Đọc refresh token không khóa dòng (`SELECT … FOR UPDATE`): hai request refresh gửi cùng lúc có thể cùng thành công, nên phát hiện dùng lại không chắc chắn. |
| L4 | `migration/V1…sql:73` | Index `invites_by_code` không UNIQUE. Hai mã trùng nhau tạo cùng lúc (rất hiếm) khiến `findFirst` ghép máy vào **nhầm người già**. Nên đổi thành unique partial index trên `code_hash` (WHERE used_at IS NULL). |
| L5 | `migration/V3…sql:25` | `dose_logs_by_elder_day` trùng hoàn toàn với `dose_logs_by_elder_date` (V2). Nên bỏ một cái. |
| L6 | `health/HealthController.java` | `/api/health` công khai và mỗi lần gọi lại ping AI service. Nên cache vài giây. |
| L7 | `care/DoseSweeper.java:67` | Mỗi phút gọi `findAll()` mọi người già, có truy vấn N+1, và không có khóa nếu chạy hai backend. Ổn với vài chục gia đình, nhưng cần sửa trước khi mở rộng. |
| L8 | `notification/FcmPushSender.java` | Thông báo hiện tên người già và tên thuốc trên màn hình khóa của người con. Nên cân nhắc `VISIBILITY_PRIVATE`. |
| L9 | `common/Jobs.java` | Không có chính sách giữ dữ liệu cho `notification_outbox`, `alerts`, `audit_logs`. `purgeDeletedPhotos` xóa lại cùng các file mỗi 12 giờ mãi mãi. |
| L10 | `notification/DeviceController.java` | Ai biết FCM token của máy khác có thể chuyển token đó sang tài khoản mình. Rủi ro thấp vì token khó đoán. |
| L11 | `OutboxDispatcher.java` (chú thích) | Chú thích nói xem số liệu ở `/actuator/metrics…`, nhưng `exposure.include=health` nên đường dẫn đó không tồn tại. |
| L12 | `AndroidManifest.xml` | Không đặt `allowBackup`/`dataExtractionRules`: lịch thuốc (Drift) được Google sao lưu, còn khóa của secure storage không đi theo khi khôi phục sang máy mới, nên có thể lỗi lúc mở app (cần kiểm tra). |
| L13 | `app/lib/features/caregiver/today_tab.dart` (687 dòng), `schedule_tab.dart` (668), `elder_home_screen.dart` (570), `alarm_screen.dart` (505), `backend/.../TodayService.java` (379) | Widget và service quá lớn, khó test. Nên tách thành các widget và lớp tính toán nhỏ hơn. |
| L14 | `flutter analyze` | 37 `info` (import `material.dart` lỗi thời) làm lệnh trả mã thoát 1. Nên sửa, hoặc cấu hình mức nghiêm trọng, để dùng được làm cổng CI. |
| L15 | `docker-compose.yml` | Ảnh Docker dùng tag (`postgres:18`, `eclipse-temurin:25`), chưa ghim digest. Nên ghim để build lặp lại được. |

---

## Những gì đã làm tốt

- **Phân quyền theo nhóm (chống IDOR) làm cẩn thận.** Mọi endpoint của nhóm đi qua `GroupAccess` (`requireMember`/`requireCaregiver`/`requireOwner`). Tài nguyên con đều được kiểm tra thuộc đúng nhóm (thuốc, ảnh, cảnh báo, dose log, người già). Người ngoài nhận 404 thay vì 403. Tôi không tìm thấy endpoint nào bỏ sót.
- **Mã ghép máy và mã mời chỉ lưu dạng HMAC** có khóa bí mật, dùng một lần, hết hạn sau 15 phút, mã cũ bị hủy khi tạo mã mới. Ghép máy mới thì thu hồi máy cũ. Refresh token chỉ lưu SHA-256.
- **Khóa tài khoản có hiệu lực ngay** nhờ `DisabledAccountFilter` (không phải chờ access token hết hạn).
- **Không có bí mật trong lịch sử git** (đã quét `.env`, `secrets/`, keystore, khóa Google). `.gitignore` chặn đúng chỗ. Cổng Docker chỉ mở trên `127.0.0.1`. AI service cần token so sánh bằng `compare_digest`.
- **Ảnh tải lên được mã hóa lại sang JPEG** nên mất EXIF/GPS, có chặn path traversal, tên file là UUID.
- **Báo cáo từ máy người già idempotent đúng cách:** `clientEventId`, id dose log suy ra từ id báo cáo, ràng buộc unique trong DB, bắt lỗi khi hai bản trùng đến cùng lúc. Outbox thông báo nằm cùng transaction với sự kiện, có `dedupe_key`. Sweeper dùng `ON CONFLICT DO NOTHING` trên unique partial index.
- **Engine báo thức đi đúng hướng:** `setAlarmClock`, foreground service, phát trên luồng ALARM, có chuông dự phòng khi thiếu giọng Việt, giới hạn reo 2 phút, 3 lần, id nhắc lại tách khỏi id lịch, đặt lại khi khởi động máy, đổi giờ, cập nhật app. Có thêm đồng bộ định kỳ dự phòng.
- **Logic lịch và trạng thái chỉ viết hai lần (Java và Dart) nhưng dùng chung `shared/test-vectors`**, nên hai bên khó lệch nhau.
- **Schema chặt:** CHECK cho enum và khoảng giá trị, unique partial index (một trưởng nhóm, một nhóm cho mỗi người già), khóa ngoại đầy đủ, Flyway với `ddl-auto=validate`.
- **Không ghi log nội dung nhạy cảm** (văn bản OCR, nội dung thông báo). OCR lọc dòng chứa thông tin cá nhân ngay trên máy trước khi gửi.
- **Giao diện người già:** nút cao 72–100 px, chữ 22–56 px, độ tương phản màu đạt (đã có test), trạng thái có chữ và biểu tượng chứ không chỉ màu, có `Semantics` cho TalkBack. Release chặn HTTP thường.
- **Phiên bản phụ thuộc được ghim** (`pubspec.lock`, `requirements.txt` ghi version cụ thể, Spring Boot 4.1.2).

---

## Kết luận

**Chưa nên đưa cho người dùng thật.** Phần phân quyền và idempotency đạt mức chuyên nghiệp. Nhưng nhiệm vụ chính của app là "đến giờ thì máy của bố mẹ phải reo, và nếu không ai trả lời thì các con phải biết", và nhiệm vụ đó đang có những điểm hỏng mà không ai hay biết.

**Phải sửa trước khi có người dùng thật:**
1. N1: máy người già không được tự xóa lịch khi refresh lỗi; thêm khoảng chấp nhận token vừa xoay.
2. N2: kiểm tra múi giờ; một hồ sơ lỗi không được chặn cả lượt quét.
3. C1: lấy đúng IP thật sau đường hầm; bỏ giới hạn chung có thể bị lợi dụng để khóa cả hệ thống.
4. C2: outbox thử lại có thời gian chờ tăng dần và giữ tin khẩn lâu hơn.
5. C3: kiểm tra kích thước điểm ảnh trước khi giải mã.
6. C4: xóa dữ liệu cho đủ, kể cả cho từng người già.
7. C5: máy chủ có địa chỉ cố định, luôn bật, tự khởi động lại.
8. C6: sao lưu chạy được và đã thử khôi phục.
9. T1, T2: reo bù sau khi khởi động lại; kiểm tra âm lượng báo thức.
10. T8 (phần tối thiểu): một CI chạy được toàn bộ test backend, kèm test cho các mục trên.

**Có thể làm sau (trước khi mở rộng):** T3–T7, T9, T10 và các mục Thấp (L1–L15).
