"""Scores a document parser on evaluation/samples.jsonl (invented samples, no real patient data).

    python -m evaluation.evaluate            # test split, prints a table
    python -m evaluation.evaluate --split all --write   # also rewrites evaluation/REPORT.md

Per sample, predicted items are matched to expected items by medicine name (accent- and case-insensitive).
For matched items each field is compared exactly (an empty expected field must be predicted empty).
"Invented" counts dosage or times predicted where the document gives none: it must stay at zero.
"""
import argparse
import json
from collections import Counter
from pathlib import Path

from app.parsing import parse
from app.parsing.text import norm

HERE = Path(__file__).parent
FIELDS = ("strength", "dosage", "times", "days", "quantity")


def key(name: str) -> str:
    return " ".join(norm(name).split())


def same(field: str, got, want) -> bool:
    if field == "strength" and got and want:
        return got.replace(",", ".").lower() == want.replace(",", ".").lower()
    if field == "times":
        return list(got or []) == list(want or [])
    return got == want


def evaluate(split: str = "test", parser=parse) -> dict:
    samples = [json.loads(ln) for ln in (HERE / "samples.jsonl").read_text(encoding="utf-8").splitlines() if ln.strip()]
    if split != "all":
        samples = [s for s in samples if s["split"] == split]
    by_type: dict[str, Counter] = {}
    for s in samples:
        c = by_type.setdefault(s["type"], Counter())
        c["samples"] += 1
        got = parser(s["type"], s["text"])
        want = s["expected"]
        c["expected"] += len(want)
        c["predicted"] += len(got)
        remaining = list(got)
        for w in want:
            match = next((g for g in remaining if key(g["name"]) == key(w["name"])), None)
            if match is None:
                continue
            remaining.remove(match)
            c["matched"] += 1
            for f in FIELDS:
                c[f] += same(f, match.get(f), w.get(f))
            if w.get("dosage") is None and match.get("dosage"):
                c["invented"] += 1
            if not w.get("times") and match.get("times"):
                c["invented"] += 1
    return {"split": split, "count": len(samples), "by_type": by_type}


def table(result: dict) -> str:
    rows = ["| Loại | Mẫu | Thuốc đúng tên / cần tìm | Thừa | " + " | ".join(FIELDS) + " | Tự bịa |",
            "|---|---|---|---|" + "---|" * len(FIELDS) + "---|"]
    for t, c in sorted(result["by_type"].items()):
        m = c["matched"] or 1
        extra = c["predicted"] - c["matched"]
        cells = " | ".join(f"{100 * c[f] / m:.0f}%" for f in FIELDS)
        rows.append(f"| {t} | {c['samples']} | {c['matched']}/{c['expected']} | {extra} | {cells} | {c['invented']} |")
    return "\n".join(rows)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--split", default="test", choices=["dev", "test", "all"])
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    results = {s: evaluate(s) for s in (["dev", "test"] if args.split == "all" else [args.split])}
    for s, r in results.items():
        print(f"\n## {s} ({r['count']} mẫu)\n")
        print(table(r))
    if args.write:
        body = (HERE / "REPORT.template.md").read_text(encoding="utf-8")
        for s, r in results.items():
            body = body.replace("{{" + s + "}}", table(r))
        (HERE / "REPORT.md").write_text(body, encoding="utf-8")


if __name__ == "__main__":
    main()
