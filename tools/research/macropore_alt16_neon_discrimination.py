#!/usr/bin/env python3
"""F-MACRO-ALT16: NEON preferential-flow event discrimination preprocessor.

Research-only. Reads one or more XXXX_PF_database_00Y CSV files from the
published NEON PF database and emits compact event records required for
RFM-vs-observation discrimination.

No RFM physics is changed here. Standard library only.
"""

from __future__ import annotations

import csv
import json
import math
import sys
from pathlib import Path
from statistics import mean, pstdev


def _float(v):
    try:
        x = float(v)
        return x if math.isfinite(x) else None
    except Exception:
        return None


def _bool(v):
    if v is None:
        return None
    s = str(v).strip().lower()
    if s in {"true", "1", "yes"}:
        return True
    if s in {"false", "0", "no"}:
        return False
    return None


def sensor_suffixes(fieldnames, prefix):
    out = []
    for name in fieldnames:
        if name.startswith(prefix + "_"):
            out.append(name.split("_", 1)[1])
    return sorted(set(out))


def compact_event(row, source_file):
    fields = list(row)
    sensors = sensor_suffixes(fields, "smBeforePrecip")

    antecedent = []
    vt_flags = []
    onset_times = {}
    for s in sensors:
        v = _float(row.get(f"smBeforePrecip_{s}"))
        if v is not None:
            antecedent.append(v)
        b = _bool(row.get(f"PF_velocity_metric_{s}"))
        if b is not None:
            vt_flags.append(b)
        t = row.get(f"smOnsetTime_{s}")
        if t and str(t).strip() not in {"", "nan", "NaN", "-9999"}:
            onset_times[s] = t

    mean_theta = mean(antecedent) if antecedent else None
    cv_theta = None
    if antecedent and mean_theta not in (None, 0.0) and len(antecedent) > 1:
        cv_theta = pstdev(antecedent) / abs(mean_theta)

    peak_10min = _float(row.get("stormPeakIntensity"))
    peak_mmh = peak_10min * 6.0 if peak_10min is not None else None

    flow_type = row.get("flowTypes")
    nsr_pf = flow_type == "nonSequentialFlow"
    vt_pf = any(vt_flags) if vt_flags else None

    return {
        "source_file": source_file,
        "storm_start": row.get("stormStartTime"),
        "storm_end": row.get("stormEndTime"),
        "storm_sum_mm": _float(row.get("stormSum")),
        "storm_peak_mm_per_h": peak_mmh,
        "storm_duration_h": _float(row.get("stormDuration")),
        "mean_antecedent_theta": mean_theta,
        "cv_antecedent_theta_across_sensors": cv_theta,
        "nsr_pf": nsr_pf,
        "vt_pf_any_sensor": vt_pf,
        "flow_type": flow_type,
        "flow_position": row.get("flowPosition"),
        "sensor_onset_times": onset_times,
    }


def read_file(path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        required = {
            "stormStartTime", "stormEndTime", "stormSum",
            "stormPeakIntensity", "stormDuration", "flowTypes",
        }
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"{path}: missing required fields {sorted(missing)}")
        return [compact_event(row, path.name) for row in reader]


def summarize(events):
    usable = [e for e in events if e["storm_peak_mm_per_h"] is not None]
    bins = [(0,5),(5,8),(8,12),(12,13),(13,20),(20,1e9)]
    intensity_bins = []
    for lo, hi in bins:
        rows = [e for e in usable if lo <= e["storm_peak_mm_per_h"] < hi]
        if not rows:
            continue
        nsr = [e["nsr_pf"] for e in rows]
        vt = [e["vt_pf_any_sensor"] for e in rows if e["vt_pf_any_sensor"] is not None]
        intensity_bins.append({
            "lo_mm_h": lo,
            "hi_mm_h": None if hi > 1e8 else hi,
            "n": len(rows),
            "nsr_fraction": sum(nsr)/len(nsr),
            "vt_fraction": (sum(vt)/len(vt)) if vt else None,
        })
    return {
        "n_events": len(events),
        "n_with_peak_intensity": len(usable),
        "intensity_bins": intensity_bins,
    }


def main(argv):
    if len(argv) < 2:
        raise SystemExit("usage: macropore_alt16_neon_discrimination.py FILE.csv [FILE2.csv ...]")
    events = []
    for p in map(Path, argv[1:]):
        events.extend(read_file(p))
    result = {
        "schema": "swap5.f_macro_alt16.neon_event_preprocessor.v1",
        "status": "RESEARCH_ONLY",
        "events": events,
        "summary": summarize(events),
        "notes": [
            "stormPeakIntensity is converted from mm/10min to mm/h by multiplying by 6",
            "NSR preferential flow is flowTypes == nonSequentialFlow",
            "VT preferential flow is any PF_velocity_metric sensor == True",
            "antecedent CV here is reconstructed across available sensors within the event/profile and is not guaranteed identical to the published paper's exact antecedent-CV feature",
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv)
