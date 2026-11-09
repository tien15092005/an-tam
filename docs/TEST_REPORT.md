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
| CI trên GitHub | Đạt | Lần chạy đầu tiên (commit `bc9fcab`, 09/11/2026): App, Backend (gồm test PostgreSQL qua Testcontainers), AI service đều xanh |
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

## Giai đoạn 4: Thuốc, ảnh, mô tả (09/11/2026)

**Test tự động:** backend **46/46 đạt** (`mvnw test`, gồm 7 test `MedicationTest` và 20 test vector); app **30/30 đạt** (`flutter test`, gồm cùng 20 test vector và 5 test đặt báo thức); `flutter analyze` không có lỗi.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Test vector đạt ở Dart và Java | Đạt | `shared/test-vectors/dose-status.json` (13 trường hợp, gồm qua nửa đêm, phút thứ 60/61, thuốc thêm sau giờ uống) và `schedule-expansion.json` (7 trường hợp) chạy ở `SharedVectorsTest` (Java) và `test/domain/shared_vectors_test.dart` (Dart) |
| Thành viên không sửa được thuốc | Đạt | `MedicationTest`: thành viên và người già nhận 403 khi thêm, sửa, xóa, tải ảnh; người ngoài nhận 404; ai trong nhóm cũng xem được. Trên app, thành viên không thấy nút thêm/sửa |
| Xóa thuốc thì hủy báo và lịch sử còn nguyên | Đạt | Test: thuốc biến mất khỏi lịch, nhật ký uống còn, có audit `MEDICATION_DELETED`. Máy ảo: trước khi xóa có báo thức Amlodipin 21:00 và 03:58 các ngày; sau khi xóa và mở lại app chỉ còn Metformin 04:06; database còn bản ghi `active = f`; ảnh cũ bị xóa khỏi máy |
| Tắt mạng vẫn báo và vẫn thấy ảnh | Đạt | Máy ảo: tắt Wi-Fi và dữ liệu, tắt tiến trình app, khóa màn hình → báo thức kêu đúng 04:06:00, giọng tiếng Việt đọc lặp, hiện đúng thuốc (`phase4-alarm-offline.png`). Mở app khi vẫn mất mạng → vào thẳng trang chủ, có dòng báo mất mạng, ảnh lấy từ máy (`phase4-home-offline.png`) |
| Người con thêm thuốc thì máy người già báo đúng giờ | Đạt | Thêm thuốc qua API, mở lại app người già → trang chủ hiện thuốc kèm ảnh (`phase4-elder-home.png`), Android đặt đúng báo thức 03:58 và 04:06. Form thêm thuốc trên app người con lưu được (`phase4-form-empty.png`, `phase4-caregiver-list.png`) |

**Lỗi phát hiện và đã sửa trong lúc thử:**

- Sửa giờ uống bị lỗi trùng khóa `medication_times_unique` (Hibernate chèn giờ mới trước khi xóa giờ cũ). Nay chỉ xóa giờ bị bỏ và thêm giờ mới.
- Mất mạng thì app kẹt ở vòng xoay sau khi tắt báo thức (màn hình đầu chờ `/api/me`). Nay dùng thông tin tài khoản đã lưu khi không kết nối được server.
- Build Android lần thứ hai bị lỗi "Unable to delete directory": đường dẫn file quá 260 ký tự khi đi qua thư mục OneDrive (xem DECISIONS).

**Lưu ý khi thử:** `adb shell am force-stop` (giống bấm "Buộc dừng" trong Cài đặt) làm Android hủy mọi báo thức của app. Đây là quy định của Android; lần mở app tiếp theo sẽ đặt lại. Vuốt app khỏi danh sách đa nhiệm hay bị hệ thống tắt ngầm (`am kill`) thì báo thức vẫn kêu.

**Chưa làm / chưa thử:**

- FCM báo đổi lịch khi app đóng: cần file Firebase của nhóm.
- Chưa chọn ảnh bằng camera trên máy ảo (ảnh thử được tải lên qua API).
- Bấm "ĐÃ UỐNG RỒI" chưa ghi lại lần uống; việc này thuộc Giai đoạn 5.
- Chưa thử trên Samsung thật.

## Giai đoạn 5: Trải nghiệm người già (09/11/2026)

**Test tự động:** backend **60/60 đạt** (thêm 14 test `CareTest`); app **69/69 đạt** (thêm 33 test nhận dạng giọng nói, 6 test hàng đợi offline trên SQLite thật trong bộ nhớ); `flutter analyze` không có lỗi.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Chỉ dừng đúng các trường hợp mục 9 | Đạt (trừ "người con đánh dấu giúp", thuộc Giai đoạn 6) | Máy ảo: bấm Back vẫn ở màn hình báo; bấm Home thì máy vẫn đọc tiếp (lượt 3 lúc 05:32:18); thông báo có cờ `ONGOING`, `NO_CLEAR` nên không vuốt bỏ được. Chỉ dừng khi bấm ĐÃ UỐNG RỒI, KHÔNG UỐNG ĐƯỢC hoặc Nhắc lại sau 10 phút |
| Mỗi câu trả lời tạo đúng cảnh báo | Đạt | `CareTest.eachProblemRaisesItsOwnAlert` chạy đủ 5 loại; "Không có gì" và không trả lời thì không có cảnh báo. Máy ảo: báo thức 2 thuốc lúc 05:31 → ĐÃ UỐNG HẾT RỒI → "Mất thuốc" → server có 1 cảnh báo `LOST_MEDICINE` ghi "Amlodipin, Vitamin B, liều 05:31" và 2 nhật ký `TAKEN / ISSUE` (`phase5-alarm-multi.png`, `phase5-question.png`, `phase5-after-lost.png`) |
| Offline đồng bộ không trùng | Đạt | Test: gửi lại cùng báo cáo → `duplicate: true`, vẫn 2 nhật ký và 1 cảnh báo; 4 bản gửi song song → 1 bản ghi. Máy ảo: tắt mạng, tắt app → báo thức 05:39 → KHÔNG UỐNG ĐƯỢC → "Hết thuốc", rồi "Tôi thấy không khỏe" ở trang chính; server chưa nhận gì. Bật mạng, mở app → server nhận đúng `OUT_OF_MEDICINE` và `UNWELL`; mở app thêm lần nữa vẫn mỗi loại 1 bản ghi |
| "Chưa uống" không tính là đã uống | Đạt | `voice_intent_test`: "chưa uống", "uống chưa nhỉ", "không, chưa uống", "quên uống rồi", "ko uống"... không bao giờ ra "đã uống"; câu không rõ thì không ghi. KHÔNG UỐNG ĐƯỢC được ghi `NOT_TAKEN` ở cả máy (trang chính hiện "Không uống được") và server |
| TalkBack và cỡ chữ 200% | Đạt trên máy ảo | Cỡ chữ 200%: chữ tự xuống dòng, không có lỗi tràn bố cục trong log (`phase5-home-200*.png`). TalkBack: mỗi thẻ thuốc là một mục đọc liền ("05:31, Amlodipin, 1 viên, Đã uống"), đồng hồ đọc thành "Bây giờ là 5 giờ 46 phút...", ảnh có nhãn "Ảnh thuốc ..." (`phase5-talkback.png`). Trạng thái luôn có biểu tượng, chữ và màu |
| Một người từ 55 tuổi trở lên ngoài nhóm tự làm được | Chưa làm | Cần nhóm mời người thử trên điện thoại thật |

**Đã thử thêm trên máy ảo:** "Gọi cho con" khi mất mạng vẫn hiện "Gọi Chi Hoa" từ danh bạ đã lưu (`phase5-call-offline.png`); "Tôi thấy không khỏe" hiện nút gọi và dòng "Nếu nguy cấp, gọi cấp cứu 115" (`phase5-unwell-offline.png`); màn hình Kiểm tra máy báo đúng mục "Không giới hạn pin" chưa bật trên máy ảo (`phase5-readiness.png`).

**Lỗi phát hiện và đã sửa trong lúc thử:**

- Sau khi ghép máy, trang chính không có thuốc và báo nhầm "không có mạng": lúc người con đăng xuất, app gọi lịch bằng tài khoản người con, server trả 403 và app hiểu là mất mạng; trang chính cũng không tự tải lịch khi vừa mở. Nay chỉ lỗi không kết nối mới là mất mạng, và trang chính tải lịch mỗi lần hiện.
- Hàng đợi bỏ qua lệnh gửi khi đang có lượt gửi khác chạy (test hàng đợi bắt được). Nay lệnh mới chờ lượt đang chạy và chạy thêm một lượt.
- Danh bạ các con chỉ được lưu khi mở danh sách lúc có mạng, nên lần đầu mất mạng không gọi được. Nay lưu mỗi lần đồng bộ.
- "Không sao đâu con" bị hiểu là "đau" (sau khi bỏ dấu, "đâu" và "đau" giống nhau). Nay "đau" chỉ được tính khi đi kèm từ rõ nghĩa ("bị đau", "đau bụng"...).
- Build Android lỗi "Unable to delete directory": xem DECISIONS (tắt theo dõi file của Gradle; đường dẫn quá 260 ký tự khi Windows chưa bật Long Paths).

**Chưa làm / chưa thử:**

- Thông báo đẩy cho người con và cảnh báo `NOT_CONFIRMED` (Giai đoạn 6); người con đánh dấu giúp để dừng báo trên máy người già (Giai đoạn 6).
- Trả lời bằng giọng nói chưa thử thật: máy ảo không có micro. Logic nhận dạng câu đã có test.
- Chưa có người ngoài nhóm từ 55 tuổi thử; chưa thử trên Samsung thật.

**Vấn đề phát hiện (Giai đoạn 1):**

- Thư mục dự án nằm trong OneDrive. OneDrive giữ file trong `app/build` làm `flutter test` và build Android lỗi ngẫu nhiên. Tạm xử lý bằng cách xóa `app/build` rồi chạy lại.
- Máy ảo chạy tốt nhất ở chế độ đồ họa phần mềm; lần đầu khởi động khoảng 3 phút.
