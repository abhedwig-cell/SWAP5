#!/usr/bin/env python3
"""F-MACRO-ALT48: HILLSCAPE mass-based same-event SSF receipt operator.

Research-only. Standard library only.

Input: HILLSCAPE Table 7 SSF characteristics text file.
Output:
  direct_event_water_ssf_fraction = runoff_ratio * event_water_fraction

This is an observed external receipt fraction of applied rainfall.
It is NOT equated to RFM f_MB.
"""

from __future__ import annotations
import csv
import json
import math
import sys
from pathlib import Path
from statistics import mean, median


def pct(value: str) -> float:
    return float(value.strip().replace("%", "")) / 100.0


def read_table(path: Path):
    with path.open("r", encoding="latin-1", newline="") as f:
        lines = [line for line in f if line.strip()]
    # first 3 nonempty lines are licence, citation, blank/header preamble
    header_idx = next(i for i, line in enumerate(lines) if line.startswith("Study_area	"))
    reader = csv.DictReader(lines[header_idx:], delimiter="	")
    rows = []
    for row in reader:
        runoff = pct(row["Runoffratio"])
        fe = pct(row["Fe"])
        err_fe = pct(row["Error_Fe"])
        receipt = runoff * fe
        receipt_err = runoff * err_fe
        rows.append({
            "study_area": row["Study_area"],
            "moraine": row["Moraine"],
            "plot_position": row["Plot_position"],
            "plot_complexity": row["Plot_complexity"],
            "intensity_class": row["Intensity"],
            "rain_intensity_mm_h": float(row["P_mm/hr"]),
            "runoff_ratio": runoff,
            "event_water_fraction_in_ssf": fe,
            "event_water_fraction_error": err_fe,
            "same_event_ssf_receipt_fraction_of_applied_rain": receipt,
            "same_event_ssf_receipt_error": receipt_err,
            "qtotal_mm": float(row["Qtotal"]),
            "qpeak_mm_h": float(row["Qpeak"]),
            "lag_min": float(row["Tlag"]),
            "flow_duration_min": float(row["Flow_duration"]),
        })
    return rows


def paired_intensity(rows):
    groups = {}
    for r in rows:
        key = (r["study_area"], r["moraine"], r["plot_position"])
        groups.setdefault(key, []).append(r)
    out = []
    for key, vals in groups.items():
        if len(vals) < 2:
            continue
        vals = sorted(vals, key=lambda r: r["rain_intensity_mm_h"])
        out.append({
            "plot": {"study_area": key[0], "moraine": key[1], "plot_position": key[2]},
            "events": [
                {
                    "intensity_class": r["intensity_class"],
                    "rain_intensity_mm_h": r["rain_intensity_mm_h"],
                    "receipt_fraction": r["same_event_ssf_receipt_fraction_of_applied_rain"],
                }
                for r in vals
            ],
        })
    return out


def main(argv):
    if len(argv) != 2:
        raise SystemExit("usage: macropore_alt48_hillscape_receipt.py TABLE_7_SSF.txt")
    rows = read_table(Path(argv[1]))
    receipts = [r["same_event_ssf_receipt_fraction_of_applied_rain"] for r in rows]
    result = {
        "schema": "swap5.f_macro_alt48.hillscape_same_event_ssf_receipt.v1",
        "status": "RESEARCH_ONLY",
        "definition": "F_new_SSF = (Q_SSF / P_applied) * f_eventwater_in_SSF",
        "n_experiments": len(rows),
        "receipt_summary": {
            "min": min(receipts),
            "median": median(receipts),
            "mean": mean(receipts),
            "max": max(receipts),
        },
        "rows": rows,
        "paired_intensity_sequences": paired_intensity(rows),
        "qualification_boundary": [
            "This is a directly observed external same-event-water receipt fraction.",
            "It is not equal to vertical preferential-entry fraction.",
            "It is not equal to RFM f_MB because trench SSF includes lateral redistribution and incomplete capture of deep flow.",
            "It can constrain/check the product of fast entry and fast external-routing efficiency.",
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv)
