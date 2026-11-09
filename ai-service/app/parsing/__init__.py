"""Document parsers (baseline, rule-based). Entry point: ``parse(document_type, text)``."""
from .invoice import parse_invoice
from .package import parse_package
from .prescription import parse_prescription
from .privacy import remove_personal_lines
from .text import fix_ocr_digits

DOCUMENT_TYPES = ("PRESCRIPTION", "PACKAGE", "INVOICE", "OTHER")


def parse(document_type: str, text: str) -> list[dict]:
    """Personal lines are removed first, whatever the app already did."""
    clean = fix_ocr_digits(remove_personal_lines(text))
    if document_type == "PRESCRIPTION":
        return parse_prescription(clean)
    if document_type == "PACKAGE":
        return parse_package(clean)
    if document_type == "INVOICE":
        return parse_invoice(clean)
    # "Khác": try the prescription rules (they never invent times), then a package-style name.
    return parse_prescription(clean) or parse_package(clean)
