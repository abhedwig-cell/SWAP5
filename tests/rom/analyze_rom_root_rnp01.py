#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

TOL = 1.0e-12
PRIMARY_RE = re.compile(
    r"RNP01_PRIMARY\|STATUS=(?P<status>-?\d+)\|ROUTE=(?P<route>[^|]+)"
    r"\|NL=(?P<nl>\d+)\|BACKTRACK=(?P<back>\d+)"
    r"\|NAIVE_SUM=(?P<naive>[^|]+)\|MAXABS=(?P<maxabs>[^|]+)"
    r"\|L1=(?P<l1>[^|]+)\|L2=(?P<l2>[^|]+)"
    r"\|BAL_FLAGS=(?P<bal>\d+)\|HEAD_FLAGS=(?P<head>\d+)"
)
SHADOW_RE = re.compile(
    r"RNP01_SHADOW\|MAXIT=(?P<maxit>32|64)\|STATUS=(?P<status>-?\d+)\|ROUTE=(?P<route>[^|]+)"
    r"\|NL=(?P<nl>\d+)\|BACKTRACK=(?P<back>\d+)"
    r"\|NAIVE_SUM=(?P<naive>[^|]+)\|MAXABS=(?P<maxabs>[^|]+)"
    r"\|L1=(?P<l1>[^|]+)\|BAL_FLAGS=(?P<bal>\d+)\|HEAD_FLAGS=(?P<head>\d+)"
)
RESID_RE = re.compile(r"RNP01_RESIDUAL\|I=(?P<i>\d+)\|R=(?P<r>.+)$")


def parse_float(value: str) -> float:
    return float(value.strip().replace("D", "E").replace("d", "e"))


def parse_log(path: Path) -> dict:
    raw = path.read_text(errors="replace")
    pm = PRIMARY_RE.search(raw)
    if not pm:
        raise SystemExit(f"primary record missing in {path}")
    primary = {
        "status": int(pm["status"]),
        "route": pm["route"].strip(),
        "nonlinear_iterations": int(pm["nl"]),
        "backtracking_attempts": int(pm["back"]),
        "naive_sum": parse_float(pm["naive"]),
        "max_abs": parse_float(pm["maxabs"]),
        "l1": parse_float(pm["l1"]),
        "l2": parse_float(pm["l2"]),
        "balance_flags": int(pm["bal"]),
        "head_flags": int(pm["head"]),
    }
    residuals = [(int(m["i"]), parse_float(m["r"])) for m in RESID_RE.finditer(raw)]
    residuals.sort()
    if not residuals:
        raise SystemExit(f"residual vector missing in {path}")
    expected = list(range(1, len(residuals) + 1))
    got = [i for i, _ in residuals]
    if got != expected:
        raise SystemExit(f"residual index discontinuity in {path}")
    values = [v for _, v in residuals]
    compensated = math.fsum(values)
    l1 = math.fsum(abs(v) for v in values)
    primary["node_count"] = len(values)
    primary["compensated_sum"] = compensated
    primary["naive_minus_compensated"] = primary["naive_sum"] - compensated
    primary["cancellation_ratio"] = abs(compensated) / l1 if l1 else 0.0
    primary["summation_sensitivity"] = (
        abs(primary["naive_sum"]) <= TOL
    ) != (abs(compensated) <= TOL)

    shadows = {}
    for sm in SHADOW_RE.finditer(raw):
        maxit = int(sm["maxit"])
        shadows[str(maxit)] = {
            "status": int(sm["status"]),
            "route": sm["route"].strip(),
            "nonlinear_iterations": int(sm["nl"]),
            "backtracking_attempts": int(sm["back"]),
            "naive_sum": parse_float(sm["naive"]),
            "max_abs": parse_float(sm["maxabs"]),
            "l1": parse_float(sm["l1"]),
            "balance_flags": int(sm["bal"]),
            "head_flags": int(sm["head"]),
        }
    if set(shadows) != {"32", "64"}:
        raise SystemExit(f"shadow records incomplete in {path}")
    return {"primary": primary, "shadows": shadows}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prereg", required=True, type=Path)
    ap.add_argument("--logs", required=True, nargs="+", type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    prereg = json.loads(args.prereg.read_text())
    if prereg["state"] != "PREREGISTERED_BEFORE_RNP01_DIAGNOSTIC_RESPONSE":
        raise SystemExit("invalid preregistration state")

    cases = {}
    for path in args.logs:
        name = path.stem
        cases[name] = parse_log(path)

    classifications = {
        "SUMMATION_SENSITIVITY": any(c["primary"]["summation_sensitivity"] for c in cases.values()),
        "ITERATION_CAP_LIMITED": any(
            c["shadows"]["32"]["status"] == 0 or c["shadows"]["64"]["status"] == 0
            for c in cases.values()
        ),
        "RESIDUAL_FLOOR_PERSISTS": all(
            c["shadows"]["64"]["status"] != 0 and abs(c["shadows"]["64"]["naive_sum"]) > TOL
            for c in cases.values()
        ),
    }

    by_material = {}
    for name, case in cases.items():
        material = name.split("_", 1)[0]
        by_material.setdefault(material, []).append((case["primary"]["node_count"], abs(case["primary"]["compensated_sum"]), case["primary"]["max_abs"]))
    grid_pattern = True
    for vals in by_material.values():
        vals.sort()
        if len(vals) != 3:
            grid_pattern = False
            break
        sums = [v[1] for v in vals]
        maxs = [v[2] for v in vals]
        if not (sums[0] <= sums[1] <= sums[2] and all(m <= TOL for m in maxs)):
            grid_pattern = False
            break
    classifications["GRID_DEPENDENT_ACCUMULATION"] = grid_pattern

    result = {
        "schema": "swap5.rom_root.rnp01.result.v1",
        "work_unit": "ROM-ROOT-RNP01",
        "status": "CHARACTERIZATION_COMPLETE_NO_POLICY_DECISION",
        "frozen_total_criterion": TOL,
        "cases": cases,
        "classifications": classifications,
        "policy_decision_authorized": False,
        "c6r_reopened": False,
        "reduced_candidate_response_generated": False,
        "production_source_changed": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "classifications": classifications}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
