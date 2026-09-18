from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

CASE_RE = re.compile(
    r"^F_ROSS17_CASE\|CASE=(?P<case>\d+)\|ISE=(?P<ise>\d+)\|M=(?P<material>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|LIN=(?P<lin>\d+)\|RETRY=(?P<retry>\d+)\|ALT=(?P<alt>\d+)"
    r"\|MASS=(?P<mass>[0-9.Ee+\-]+)\|TEMP=(?P<temp>[0-9.Ee+\-]+)$"
)
H_RE = re.compile(r"^F_ROSS17_H\|CASE=(?P<case>\d+)\|(?P<values>.*)$")
T_RE = re.compile(r"^F_ROSS17_T\|CASE=(?P<case>\d+)\|(?P<values>.*)$")

HEAD_THRESHOLDS = {
    1: 0.002329984405367469,
    2: 0.024875926496918055,
    3: 1.0304935719866082,
}
THETA_THRESHOLDS = {
    1: 0.000014036839159875525,
    2: 0.00009940338552821837,
    3: 0.0006060020680420108,
}
DZ_CM = 10.0
N = 16


def parse(path: Path) -> dict[int, dict]:
    rows: dict[int, dict] = {}
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        m = CASE_RE.match(line)
        if m:
            d = m.groupdict()
            case = int(d["case"])
            rows[case] = {
                "case": case,
                "ise": int(d["ise"]),
                "material": d["material"].strip(),
                "forcing": d["forcing"].strip(),
                "lin": int(d["lin"]),
                "retry": int(d["retry"]),
                "alt": int(d["alt"]),
                "mass": float(d["mass"]),
                "temp": float(d["temp"]),
            }
            continue
        m = H_RE.match(line)
        if m:
            case = int(m.group("case"))
            rows.setdefault(case, {})["h"] = [float(x) for x in m.group("values").split()]
            continue
        m = T_RE.match(line)
        if m:
            case = int(m.group("case"))
            rows.setdefault(case, {})["theta"] = [float(x) for x in m.group("values").split()]
    if sorted(rows) != list(range(1, 37)):
        raise RuntimeError(f"expected cases 1..36 in {path}, got {sorted(rows)}")
    for case, row in rows.items():
        if len(row.get("h", [])) != N or len(row.get("theta", [])) != N:
            raise RuntimeError(f"case {case} missing 16-node state")
        if row["lin"] != 24 or row["retry"] != 0 or row["alt"] != 0:
            raise RuntimeError(f"case {case} work-count contract drift")
        if not math.isfinite(row["mass"]) or not math.isfinite(row["temp"]):
            raise RuntimeError(f"case {case} non-finite diagnostics")
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", type=Path, required=True)
    ap.add_argument("--candidate", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()

    base = parse(args.baseline)
    cand = parse(args.candidate)
    records = []
    max_h = 0.0
    max_theta = 0.0
    max_storage = 0.0
    max_temp_rel = 0.0
    passed = True

    for case in range(1, 37):
        b = base[case]
        c = cand[case]
        if (b["ise"], b["material"], b["forcing"]) != (c["ise"], c["material"], c["forcing"]):
            raise RuntimeError(f"case identity drift at {case}")
        ise = b["ise"]
        h_inf = max(abs(x-y) for x, y in zip(c["h"], b["h"]))
        theta_inf = max(abs(x-y) for x, y in zip(c["theta"], b["theta"]))
        storage = abs(DZ_CM * sum(x-y for x, y in zip(c["theta"], b["theta"])))
        denom = max(abs(b["temp"]), 1.0e-30)
        temp_rel = abs(c["temp"] - b["temp"]) / denom
        h_limit = max(1.0e-8, 0.01 * HEAD_THRESHOLDS[ise])
        theta_limit = max(1.0e-12, 0.01 * THETA_THRESHOLDS[ise])
        storage_limit = 1.0e-11
        temp_limit = 1.0e-8
        case_pass = (
            h_inf <= h_limit
            and theta_inf <= theta_limit
            and storage <= storage_limit
            and temp_rel <= temp_limit
        )
        passed = passed and case_pass
        max_h = max(max_h, h_inf)
        max_theta = max(max_theta, theta_inf)
        max_storage = max(max_storage, storage)
        max_temp_rel = max(max_temp_rel, temp_rel)
        records.append({
            "case": case,
            "ise": ise,
            "material": b["material"],
            "forcing": b["forcing"],
            "head_inf": h_inf,
            "head_limit": h_limit,
            "theta_inf": theta_inf,
            "theta_limit": theta_limit,
            "storage_abs_cm": storage,
            "storage_limit_cm": storage_limit,
            "temporal_indicator_relative": temp_rel,
            "temporal_indicator_relative_limit": temp_limit,
            "pass": case_pass,
        })

    result = {
        "schema": "swap5.f-ross17.scientific-equivalence.v1",
        "case_count": 36,
        "baseline_gate": "PASS",
        "candidate_gate": "PASS",
        "candidate_vs_baseline": {
            "all_cases_pass": passed,
            "max_head_inf": max_h,
            "max_theta_inf": max_theta,
            "max_storage_abs_cm": max_storage,
            "max_temporal_indicator_relative": max_temp_rel,
        },
        "records": records,
        "verdict": "SCIENTIFIC_EQUIVALENCE_PASS" if passed else "SCIENTIFIC_EQUIVALENCE_FAIL",
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    print(f"F_ROSS17_SCIENTIFIC_VERDICT={result['verdict']}")
    if not passed:
        return 2
    print("F_ROSS17_SCIENTIFIC_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
