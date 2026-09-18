from __future__ import annotations

import argparse
import json
import re
import statistics
from pathlib import Path

CASE_RE = re.compile(
    r"^F_ROSS16_CASE\|CASE=(?P<case>\d+)\|M=(?P<material>[^|]+)\|SE=(?P<se>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|REF_NL=(?P<ref_nl>\d+)\|REF_JAC=(?P<ref_jac>\d+)\|REF_LIN=(?P<ref_lin>\d+)"
    r"\|REF_BT=(?P<ref_bt>\d+)\|REF_RETRY=(?P<ref_retry>\d+)\|REF_ALT=(?P<ref_alt>\d+)"
    r"\|ROSS_LIN=(?P<ross_lin>\d+)\|ROSS_RETRY=(?P<ross_retry>\d+)\|ROSS_ALT=(?P<ross_alt>\d+)$"
)

def dist(values: list[int]) -> dict:
    return {
        "n": len(values),
        "sum": sum(values),
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
    }

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()

    rows = []
    for line in args.input.read_text(encoding="utf-8", errors="replace").splitlines():
        m = CASE_RE.match(line.strip())
        if not m:
            continue
        d = m.groupdict()
        row = {
            "case": int(d["case"]),
            "material": d["material"].strip(),
            "se": float(d["se"]),
            "forcing": d["forcing"].strip(),
        }
        for key in ("ref_nl","ref_jac","ref_lin","ref_bt","ref_retry","ref_alt","ross_lin","ross_retry","ross_alt"):
            row[key] = int(d[key])
        rows.append(row)

    if len(rows) != 36:
        raise RuntimeError(f"expected 36 case records, got {len(rows)}")
    if sorted(r["case"] for r in rows) != list(range(1,37)):
        raise RuntimeError("case ids are not exactly 1..36")

    metrics = {}
    for key in ("ref_nl","ref_jac","ref_lin","ref_bt","ref_retry","ref_alt","ross_lin","ross_retry","ross_alt"):
        metrics[key] = dist([r[key] for r in rows])

    ref_total = metrics["ref_lin"]["sum"]
    ross_total = metrics["ross_lin"]["sum"]
    result = {
        "schema": "swap5.f-ross16.work-count-result.v1",
        "case_count": 36,
        "rows": rows,
        "metrics": metrics,
        "rossfast_linear_solves_exactly_24_all_cases": all(r["ross_lin"] == 24 for r in rows),
        "reference_linear_solves_less_than_rossfast_all_cases": all(r["ref_lin"] < r["ross_lin"] for r in rows),
        "total_linear_solve_ratio_rossfast_over_reference": ross_total / ref_total if ref_total else None,
        "reference_zero_retries_all_cases": all(r["ref_retry"] == 0 for r in rows),
        "rossfast_zero_retries_all_cases": all(r["ross_retry"] == 0 for r in rows),
        "reference_zero_alternative_solver_calls_all_cases": all(r["ref_alt"] == 0 for r in rows),
        "rossfast_zero_alternative_solver_calls_all_cases": all(r["ross_alt"] == 0 for r in rows),
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    print("F_ROSS16_WORK_COUNT_SUMMARY=PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
