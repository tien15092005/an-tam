"""Plan §8 required prescription cases, plus packaging, invoices and the no-guessing rule."""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.parsing import parse
from app.parsing.prescription import parse_prescription
from app.parsing.privacy import remove_personal_lines


def full_name(item: dict) -> str:
    return f"{item['name']} {item['strength']}" if item["strength"] else item["name"]


REQUIRED = [
    ("1. Amlodipin 5mg  30 viên\nNgày uống 1 lần, mỗi lần 1 viên, sáng sau ăn",
     "Amlodipin 5mg", "1 viên", ["07:30"], 30, "Uống sau ăn"),
    ("2) Metformin 500mg x 60 viên\nSáng 1 viên, Tối 1 viên, uống trong bữa ăn",
     "Metformin 500mg", "1 viên", ["07:30", "20:00"], 30, "Uống trong bữa ăn"),
    ("3. Paracetamol 500mg  SL: 10 viên  Ngày 2 lần, mỗi lần 1 viên. Dùng 5 ngày",
     "Paracetamol 500mg", "1 viên", ["07:30", "19:30"], 5, None),
    ("4. Vitamin B1 B6 B12 hộp 30 viên - Ngày uống 1 lần",
     "Vitamin B1 B6 B12", None, ["07:30"], 30, None),
    ("5. Omeprazol 20mg 14 viên. Uống 1 viên/lần, 2 lần/ngày trước ăn 30 phút",
     "Omeprazol 20mg", "1 viên", ["07:30", "19:30"], 7, "Uống trước ăn"),
    ("6. Losartan 50mg\nSáng: 1/2 viên",
     "Losartan 50mg", "1/2 viên", ["07:30"], None, None),
]


@pytest.mark.parametrize("text,name,dosage,times,days,note", REQUIRED)
def test_required_prescription_cases(text, name, dosage, times, days, note):
    [item] = parse_prescription(text)
    assert full_name(item) == name
    assert item["dosage"] == dosage
    assert item["times"] == times
    assert item["days"] == days
    assert item["note"] == note


def test_the_whole_list_at_once_with_header_and_advice():
    text = "ĐƠN THUỐC\nHọ tên: Nguyễn Văn A   Tuổi: 70\nChẩn đoán: Tăng huyết áp\n" + \
        "\n".join(r[0] for r in REQUIRED) + "\nLời dặn:\n1. Ăn nhạt, tập thể dục nhẹ\n2. Tái khám sau 1 tháng"
    items = parse_prescription(text)
    assert [full_name(i) for i in items] == [r[1] for r in REQUIRED]


def test_without_diacritics_parses_the_same():
    [item] = parse_prescription("2) Metformin 500mg x 60 vien\nSang 1 vien, Toi 1 vien, uong trong bua an")
    assert (full_name(item), item["dosage"], item["times"], item["days"], item["note"]) == \
        ("Metformin 500mg", "1 viên", ["07:30", "20:00"], 30, "Uống trong bữa ăn")


@pytest.mark.parametrize("text", ["", "Họ tên: Trần Thị B\nChẩn đoán: viêm họng\nLời dặn: uống nhiều nước",
                                  "Cảm ơn quý khách", "Tái khám ngày 20/11"])
def test_text_without_medicines_gives_nothing(text):
    assert parse_prescription(text) == []


def test_never_invents_times_or_dosage_the_paper_does_not_give():
    [item] = parse_prescription("1. Atorvastatin 10mg 30 viên")
    assert item["times"] == [] and item["dosage"] is None and item["days"] is None
    assert set(item["uncertain"]) == {"times", "dosage", "days"}
    assert item["confidence"] < 0.5


def test_packaging_gives_name_and_strength_but_never_how_to_take_it():
    text = "THUỐC BÁN THEO ĐƠN\nHộp 3 vỉ x 10 viên nén bao phim\nAmlodipin 5mg\nSĐK: VD-12345-10\nHSD: 12/2027"
    [item] = parse("PACKAGE", text)
    assert full_name(item) == "Amlodipin 5mg"
    assert item["quantity"] == 30
    assert item["times"] == [] and item["dosage"] is None and item["days"] is None


def test_invoice_lists_medicines_and_drops_the_buyer_and_prices():
    text = ("NHÀ THUỐC AN KHANG\nHÓA ĐƠN BÁN LẺ\nKhách hàng: Lê Văn C\nSĐT: 0912 345 678\n"
            "1. Metformin 500mg  2 hộp  120.000\n2. Vitamin C 500mg 1 lọ 45.000\nTổng tiền: 165.000đ")
    items = parse("INVOICE", text)
    assert [(full_name(i), i["quantity"]) for i in items] == [("Metformin 500mg", 2), ("Vitamin C 500mg", 1)]
    assert all(i["times"] == [] for i in items)


def test_personal_lines_are_removed_before_parsing():
    text = "Họ tên: Nguyễn Văn A\nĐịa chỉ: 12 Lê Lợi\nĐT 0987654321\nBHYT: HC4790123456789\nAmlodipin 5mg 30 viên"
    kept = remove_personal_lines(text)
    assert "Nguyễn" not in kept and "0987" not in kept and "Lê Lợi" not in kept and "BHYT" not in kept
    assert "Amlodipin" in kept


def test_other_documents_use_the_same_no_guess_rules():
    [item] = parse("OTHER", "Losartan 50mg")
    assert full_name(item) == "Losartan 50mg" and item["times"] == []


client = TestClient(app)


def test_parse_endpoint_requires_the_service_token(monkeypatch):
    monkeypatch.setenv("AI_SERVICE_TOKEN", "t")
    body = {"document_type": "PRESCRIPTION", "text": "6. Losartan 50mg\nSáng: 1/2 viên"}
    assert client.post("/v1/documents/parse", json=body).status_code == 401
    r = client.post("/v1/documents/parse", json=body, headers={"X-Service-Token": "t"})
    assert r.status_code == 200
    item = r.json()["items"][0]
    assert item["name"] == "Losartan" and item["strength"] == "50mg" and item["times"] == ["07:30"]
    assert "days" in item["uncertain"]


def test_parse_endpoint_rejects_unknown_types_and_huge_text(monkeypatch):
    monkeypatch.setenv("AI_SERVICE_TOKEN", "t")
    h = {"X-Service-Token": "t"}
    assert client.post("/v1/documents/parse", json={"document_type": "X", "text": "a"}, headers=h).status_code == 422
    assert client.post("/v1/documents/parse", json={"document_type": "OTHER", "text": "a" * 9000}, headers=h).status_code == 422


def test_the_evaluation_set_never_sees_invented_dosage_or_times():
    from evaluation.evaluate import evaluate
    result = evaluate("all")
    assert result["count"] >= 30
    assert sum(c["invented"] for c in result["by_type"].values()) == 0


def test_ocr_reading_a_zero_as_the_letter_o_is_repaired():
    # Seen on the emulator with ML Kit: "Metformin 500mg" read as "Metformin 50Omg".
    [item] = parse("PRESCRIPTION", "2. Metformin 50Omg x 6O viên\nSáng 1 viên, Tối 1 viên")
    assert (item["name"], item["strength"], item["quantity"], item["days"]) == ("Metformin", "500mg", 60, 30)
    [word] = parse("PACKAGE", "Omeprazol 20mg\nHộp 2 vỉ x 7 viên")
    assert word["name"] == "Omeprazol"  # letters in words stay letters
