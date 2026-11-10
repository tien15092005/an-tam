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

## Giai đoạn 6: Hôm nay và thông báo (09/11/2026)

**Test tự động:** backend `TodayTest` 10 test; app thêm test model ngày, trạng thái, merge hàng đợi và một test widget bố cục dòng thời gian.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Mọi thành viên nhận báo cáo, không trùng | Đạt (đến hàng đợi thông báo) | `anElderReportReachesEveryCaregiverExactlyOnceEvenWhenResent`: gửi 3 lần cùng báo cáo → mỗi người con đúng 1 thông báo; người đánh dấu giúp không tự nhận thông báo của mình |
| Có đo độ trễ | Đạt một phần | Hàng đợi đo tạo → giao cho FCM (`antam.notifications.latency`, có test). Độ trễ FCM tới điện thoại **chưa đo** vì chưa có project Firebase |
| Tắt rồi bật laptop vẫn quét bù | Đạt | Test `afterTheLaptopWasOffTheSweepCatchesUp...`. Thật: backend khởi động lại lúc 13:50 đã tự tạo 2 cảnh báo "chưa xác nhận" cho các liều 04:06 và 08:00 bị lỡ trước đó (`phase6-today.png`) |
| Đánh dấu giúp dừng báo trên máy người già | Đạt trên máy ảo | Báo thức Vitamin C kêu 14:08:08, người con đánh dấu 14:08:12, máy người già dừng 14:08:23 (11 giây, theo vòng hỏi 20 giây); trang chính hiện "Đã uống". Đánh dấu Losartan từ giao diện người con: hiện "Chi Hoa đánh dấu giúp lúc 23:14", cảnh báo chưa xác nhận tự đóng (số cảnh báo 5 → 4) |

**Lỗi tìm được và đã sửa:** tab Hôm nay đơ khi có nút trong hàng (theme cho nút rộng vô hạn); ngay sau khi đăng nhập app báo 401 do `meProvider` bị giữ từ trước khi đăng nhập.

**Chưa làm / chưa thử:** thông báo đẩy thật (cần Firebase của nhóm, xem SETUP); Samsung thật.

## Giai đoạn 7: Lịch và lịch tập (09/11/2026)

**Test tự động:** backend `ExerciseTest` 6 test; app thêm 4 test báo thức bài tập và chấm lịch.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Chấm trạng thái đúng | Đạt | `calendarDotsCountTakenMissedAndDoneDays`; test app cho màu và nhãn TalkBack. Máy ảo: ngày 9 chấm đỏ (còn liều chưa xác nhận), các ngày sau chấm "còn lần sắp tới", trước ngày bắt đầu không có chấm (`phase7-month.png`) |
| Lịch thứ 2-4-6 báo đúng ngày | Đạt | Backend: 14 ngày liên tiếp chỉ có lịch vào T2, T4, T6. App: `buildAlarms` chỉ tạo báo thức T2, T4, T6. Máy ảo: báo thức tập 23:28:04 hiện "Đến giờ tập thể dục" và nút TÔI ĐI TẬP ĐÂY, đọc giọng tiếng Việt, bấm thì dừng và server ghi `exercise_logs` (`phase7-exercise-alarm.png`) |
| Thành viên chỉ xem | Đạt | Thành viên thêm, sửa, xóa lịch tập đều 403; giao diện ẩn nút thêm, sửa với thành viên |

## Giai đoạn 8: Quét OCR và AI (09/11/2026)

**Test tự động:** AI service 26 test (6 ca bắt buộc của kế hoạch, bản không dấu, dòng hành chính, văn bản không có thuốc, chống tự bịa, bao bì, hóa đơn, lọc thông tin cá nhân, lỗi OCR chữ O); backend `OcrTest` 2 test; app thêm test lọc thông tin cá nhân.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Bộ kiểm thử đạt | Đạt | 6 ca toa thuốc bắt buộc đúng từng trường |
| Có báo cáo so sánh bản nền và mô hình | Đạt một phần | `ai-service/evaluation/REPORT.md`: bản nền trên 32 mẫu, nhóm test: toa thuốc 12/12 đúng mọi trường, bao bì 4/5, hóa đơn 6/8, **0 lần tự bịa**. Chưa thử mô hình vì cần nhóm đồng ý dùng AI bên ngoài |
| Không tạo được thuốc khi chưa duyệt | Đạt | Không có API nào tạo thuốc từ OCR; app chỉ tạo khi bấm "Lưu" ở màn hình duyệt, và bắt chọn giờ khi giấy không ghi |
| Tắt AI vẫn nhập tay được | Đạt | Không có AI service → 503 `ai_unavailable` (test), app hiện nút "Nhập tay" |

**Thử trên máy ảo:** ảnh toa thuốc giả → cắt ảnh → ML Kit đọc trên máy → bỏ 2 dòng cá nhân (họ tên, chẩn đoán) → màn hình duyệt có Amlodipin 5mg, 1 viên, 07:30 và Metformin, 07:30 + 20:00, 30 ngày, "Uống trong bữa ăn" (`phase8-review.png`). Lưu → server có 2 thuốc nguồn `OCR_PRESCRIPTION`. Log backend và AI không chứa nội dung giấy tờ.

**Lỗi tìm được:** ML Kit đọc "500mg" thành "50Omg" (`phase8-review-ocr-error.png`) → AI service nay sửa; backend gọi AI bị 422 do xin nâng cấp h2c → ép HTTP/1.1.

**Chưa làm:** thử với ảnh chụp thật (giấy in, ánh sáng thật) và với bao bì, hóa đơn thật.

## Giai đoạn 9: Chat nhóm (09/11/2026)

**Test tự động:** backend `ChatTest` 5 test, `ChatSocketTest` 1 test (WebSocket thật trên cổng ngẫu nhiên); app thêm 3 test gộp tin.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Người ngoài nhóm không kết nối hay đọc được | Đạt | Không token: bắt tay bị từ chối; người ngoài đăng ký nhóm nhận `not_found` và không nhận tin; người bị xóa khỏi nhóm không nhận thêm tin dù socket còn mở; REST trả 404 (người ngoài), 403 (người già) |
| Mất mạng rồi gửi lại không trùng | Đạt | Gửi 2 lần cùng `clientMessageId` → 1 tin; app giữ tin lỗi kèm nút gửi lại với cùng id |
| 2 máy nhận tin thời gian thực | Đạt (2 phiên) | Test: tin của trưởng nhóm tới socket của thành viên trong **80 ms**. Máy ảo: "Đang kết nối trực tiếp", tin gửi từ máy khác hiện ngay (`phase9-chat.png`). Chưa thử 2 điện thoại thật |

## Giai đoạn 10: Admin (09/11/2026)

**Test tự động:** backend `AdminTest` 3 test.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Admin không đọc được thuốc, ảnh, chat (có test) | Đạt | Admin gọi 8 API của nhóm (chi tiết nhóm, thuốc, ảnh, chat, cảnh báo, ngày, liều, lịch tập) đều 404; kết quả tìm tài khoản không có dữ liệu sức khỏe |
| Khóa tài khoản làm mất phiên | Đạt | Sau khi khóa, access token còn hạn bị từ chối ngay (401 `account_disabled`), refresh token bị thu hồi; mở khóa thì đăng nhập lại được |

## Giai đoạn 11: Hoàn thiện (09/11/2026)

**Test tự động:** backend `AccountDeletionTest` 2 test.

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Đồng ý và xóa dữ liệu | Đạt | Màn hình đồng ý hiện trước mọi màn hình trên máy ảo (`phase11-consent.png`). Xóa tài khoản: email, mật khẩu, số điện thoại bị xóa, phiên mất; người con cuối cùng xóa luôn dữ liệu cá nhân của bố mẹ, thuốc, tin nhắn; email dùng lại được |
| Sao lưu, lint, coverage, dữ liệu demo giả | Đạt | `scripts/backup.ps1`, `scripts/seed_demo.py`; `flutter analyze` sạch; CI chạy coverage cho app |
| Cài APK trên máy sạch, chạy hết kịch bản nghiệm thu | **Chưa** | Cần keystore của nhóm trưởng cho APK phát hành và 3 điện thoại thật; mục 13 của kế hoạch |

**Tổng test tự động lúc kết thúc Giai đoạn 11:** backend **89/89**, app **84/84**, AI service **26/26**, `flutter analyze` không có lỗi.

**Vấn đề môi trường:** máy nhóm trưởng thiếu RAM (còn khoảng 0,5–1 GB trống khi chạy Docker, máy ảo và Android Studio), máy ảo nhiều lần báo "System UI isn't responding". Nên tắt bớt ứng dụng khi demo, hoặc demo trên điện thoại thật.

## Đồng bộ nền dự phòng (10/11/2026, máy ảo Pixel 8)

| Kiểm tra | Kết quả |
|---|---|
| Báo thức đồng bộ được đăng ký khi vào trang chính người già | Đạt: `dumpsys alarm` có `SyncReceiver`, lặp 3 giờ |
| Tự đăng ký lại sau khi khởi động máy | Đạt: sau khi máy ảo khởi động lại, báo thức có lại sau khoảng 50 giây (BOOT_COMPLETED) |
| App đang mở | Đạt: "background sync handed to the open app", không mở engine thứ hai |
| App đã đóng hẳn (`am kill`), thêm thuốc mới từ server | Đạt: receiver khởi động engine không giao diện, log "9 medicines, offline=false, 54 alarms armed"; kho báo thức có báo thức mới cho thuốc vừa thêm (id 129904904, 14:04) mà không ai mở app |

Lỗi tìm được khi thử: lần đầu chạy engine nền lúc app đang mở báo "database is locked" → nay giao việc cho app đang mở.

## Giai đoạn 13: iPhone (10/11/2026, tùy chọn)

| Tiêu chí DoD | Kết quả | Bằng chứng |
|---|---|---|
| Ghi đúng những gì iPhone làm được và không làm được | Đạt (bằng phân tích, chưa chạy thật) | `docs/IPHONE.md`: người con và admin dùng được; người già không hỗ trợ, có lý do theo từng yêu cầu của mục 9 |
| Chạy trên iPhone | **Chưa** | Không có máy Mac. Đã sửa trước một lỗi chắc chắn gặp (router gọi kênh báo thức không có trên iOS), có test `alarm_channel_test.dart` |

**Vấn đề phát hiện (Giai đoạn 1):**

- Thư mục dự án nằm trong OneDrive. OneDrive giữ file trong `app/build` làm `flutter test` và build Android lỗi ngẫu nhiên. Tạm xử lý bằng cách xóa `app/build` rồi chạy lại.
- Máy ảo chạy tốt nhất ở chế độ đồ họa phần mềm; lần đầu khởi động khoảng 3 phút.
