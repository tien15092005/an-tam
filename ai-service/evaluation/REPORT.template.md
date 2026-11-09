# Đánh giá bộ đọc giấy tờ thuốc (Giai đoạn 8)

Bộ mẫu: `evaluation/samples.jsonl`, **32 mẫu tự soạn** (14 toa thuốc, 10 bao bì, 8 hóa đơn), không có dữ liệu thật. Mỗi mẫu thuộc nhóm `dev` (dùng khi viết luật) hoặc `test` (chỉ chạy để báo cáo, không sửa luật theo nhóm này).

Chạy lại: `python -X utf8 -m evaluation.evaluate --split all --write` trong thư mục `ai-service`.

Cách tính: thuốc được ghép theo tên (không phân biệt dấu, hoa thường). Với thuốc ghép được, mỗi trường so khớp chính xác; trường mà giấy tờ không ghi thì phải để trống mới tính là đúng. **Tự bịa** đếm số lần đoán liều hoặc giờ uống khi giấy không ghi, phải bằng 0.

## Bản nền (luật, `baseline-rules-v1`)

### Nhóm dev

{{dev}}

### Nhóm test

{{test}}

## Nhận xét

- Toa thuốc: đúng mọi trường trên cả hai nhóm, kể cả bản không dấu, dòng hành chính và phần "Lời dặn" đánh số.
- Không lần nào tự bịa liều hay giờ uống. Thuốc không ghi cách dùng được trả về với liều, giờ, số ngày để trống và nằm trong `uncertain`, màn hình duyệt tô nổi bật để người con tự điền.
- Lỗi còn lại ở nhóm test (ghi trung thực, chưa sửa để không "học vẹt" theo nhóm test):
  - Hóa đơn đánh số không có dấu chấm ("1 Amlodipin 5mg 3 vỉ") giữ số thứ tự trong tên → không khớp tên.
  - Bao bì in tên và hàm lượng trên hai dòng riêng ("Atorvastatin" / "20 mg") → không nhận ra tên.
- Người con luôn sửa được mọi trường trên màn hình duyệt, nên các lỗi này không tạo thuốc sai nếu không được duyệt.

## Thử mô hình

Kế hoạch (mục 8, bước 3) cho phép thử mô hình cục bộ hoặc LLM, nhưng **dịch vụ AI bên ngoài phải được nhóm đồng ý** vì văn bản (dù đã lọc thông tin cá nhân) sẽ rời khỏi máy chủ, và có chi phí. Chưa có quyết định này nên chưa thử. Khi nhóm đồng ý, chỉ cần viết một hàm `parser(document_type, text)` mới và chạy `evaluate(split, parser=...)` để so với bảng trên; chỉ dùng nếu tốt hơn bản nền.
