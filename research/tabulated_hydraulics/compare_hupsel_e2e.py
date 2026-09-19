#!/usr/bin/env python3
"""Compare paired SWAP result_output.csv files for the TAB-HYD audit."""

from __future__ import annotations
import argparse
import csv
import json
import math
from pathlib import Path


def read_output(path: Path):
    lines = path.read_text(errors="replace").splitlines()
    data_lines = [ln for ln in lines if ln.strip() and not ln.lstrip().startswith("*")]
    if not data_lines:
        raise RuntimeError(f"no data in {path}")
    delimiter = "," if "," in data_lines[0] else None
    if delimiter:
        rows = list(csv.reader(data_lines))
    else:
        rows = [ln.split() for ln in data_lines]
    header = [x.strip() for x in rows[0]]
    out = []
    for row in rows[1:]:
        if len(row) != len(header):
            continue
        rec = {}
        for k, v in zip(header, row):
            rec[k] = v.strip()
        out.append(rec)
    return header, out


def numeric(v: str):
    try:
        return float(v)
    except Exception:
        return None


def compare(a_path: Path, b_path: Path):
    ha, a = read_output(a_path)
    hb, b = read_output(b_path)
    common = [x for x in ha if x in hb]
    if len(a) != len(b):
        raise RuntimeError(f"row count differs: {len(a)} vs {len(b)}")
    metrics = {}
    for col in common:
        diffs = []
        avals = []
        bvals = []
        for ra, rb in zip(a, b):
            va, vb = numeric(ra[col]), numeric(rb[col])
            if va is None or vb is None:
                continue
            diffs.append(vb - va)
            avals.append(va)
            bvals.append(vb)
        if not diffs:
            continue
        metrics[col] = {
            "max_abs": max(abs(x) for x in diffs),
            "rmse": math.sqrt(sum(x*x for x in diffs) / len(diffs)),
            "mean_diff": sum(diffs) / len(diffs),
            "n": len(diffs),
        }
    return {"rows": len(a), "columns": common, "metrics": metrics}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("analytic", type=Path)
    ap.add_argument("table", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--label", default="")
    ns = ap.parse_args()
    report = compare(ns.analytic / "result_output.csv", ns.table / "result_output.csv")
    report["label"] = ns.label
    ns.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    focus = ["GWL","RAIN","IRRIG","RUNOFF","DRAINAGE","DRN","QBOTTOM","EPOT","EACT","TPOT","TACT","DSTOR"]
    print(f"PAIR {ns.label} rows={report['rows']}")
    for col in focus:
        if col in report["metrics"]:
            m=report["metrics"][col]
            print(f"METRIC {col} max_abs={m['max_abs']:.12g} rmse={m['rmse']:.12g} mean_diff={m['mean_diff']:.12g}")
    worst = sorted(report["metrics"].items(), key=lambda kv: kv[1]["max_abs"], reverse=True)[:10]
    for col, m in worst:
        print(f"WORST {col} max_abs={m['max_abs']:.12g} rmse={m['rmse']:.12g}")
    print("COMPARE_E2E_COMPLETED")


if __name__ == "__main__":
    main()
