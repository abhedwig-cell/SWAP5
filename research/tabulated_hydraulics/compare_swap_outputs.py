#!/usr/bin/env python3
"""Compare two SWAP result_output.csv files for TAB-HYD characterization."""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path
import sys

TARGETS = ["RAIN","IRRIG","INTERC","RUNOFF","DRAINAGE","DSTOR","EPOT","EACT","TPOT","TACT","QBOTTOM","GWL"]
FLUXES = {"RAIN","IRRIG","INTERC","RUNOFF","DRAINAGE","DSTOR","EPOT","EACT","TPOT","TACT","QBOTTOM"}


def read_csv(path: Path) -> tuple[list[str], list[dict[str,str]]]:
    with path.open(newline="") as f:
        reader = csv.reader(f)
        header = None
        for row in reader:
            if not row or row[0].startswith("*"):
                continue
            header = [x.strip() for x in row]
            break
        if header is None:
            raise RuntimeError(f"no CSV header in {path}")
        rows = list(csv.DictReader(f, fieldnames=header))
    return header, rows


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: compare_swap_outputs.py ANALYTIC.csv TABLE.csv OUT.json")
    pa, pt, pout = map(Path, sys.argv[1:])
    ha, a = read_csv(pa)
    ht, t = read_csv(pt)
    if len(a) != len(t):
        raise RuntimeError(f"row_count_mismatch analytic={len(a)} table={len(t)}")
    common = [v for v in TARGETS if v in ha and v in ht]
    if not common:
        raise RuntimeError("no target variables found in both outputs")

    max_abs = {v: 0.0 for v in common}
    sum_a = {v: 0.0 for v in common if v in FLUXES}
    sum_t = {v: 0.0 for v in common if v in FLUXES}
    mean_a = {v: 0.0 for v in common if v not in FLUXES}
    mean_t = {v: 0.0 for v in common if v not in FLUXES}
    state_n = {v: 0 for v in common if v not in FLUXES}
    datetime_mismatches = 0

    for ra, rt in zip(a, t):
        if ra.get("DATETIME") != rt.get("DATETIME"):
            datetime_mismatches += 1
        for v in common:
            sa, st = ra.get(v, ""), rt.get(v, "")
            if not sa or not st:
                continue
            xa, xt = float(sa), float(st)
            if not (math.isfinite(xa) and math.isfinite(xt)):
                raise RuntimeError(f"non-finite {v}: {xa}, {xt}")
            max_abs[v] = max(max_abs[v], abs(xa - xt))
            if v in FLUXES:
                sum_a[v] += xa
                sum_t[v] += xt
            else:
                mean_a[v] += xa
                mean_t[v] += xt
                state_n[v] += 1

    cumulative_diff = {v: sum_t[v] - sum_a[v] for v in sum_a}
    mean_diff = {
        v: (mean_t[v] / state_n[v] - mean_a[v] / state_n[v]) if state_n[v] else None
        for v in mean_a
    }
    payload = {
        "analytic": str(pa),
        "table": str(pt),
        "rows": len(a),
        "datetime_mismatches": datetime_mismatches,
        "variables": common,
        "max_abs_timeseries_difference": max_abs,
        "cumulative_flux_difference": cumulative_diff,
        "mean_state_difference": mean_diff,
    }
    pout.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print(json.dumps(payload, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
