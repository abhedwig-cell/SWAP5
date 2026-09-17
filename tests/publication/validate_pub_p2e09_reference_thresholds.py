#!/usr/bin/env python3
import json
import math
import sys
from collections import defaultdict

if len(sys.argv) != 3:
    raise SystemExit("usage: validate_pub_p2e09_reference_thresholds.py P2E08_OUTPUT PREREG")

output_path, prereg_path = sys.argv[1], sys.argv[2]
with open(prereg_path, "r", encoding="utf-8") as f:
    prereg = json.load(f)

records = {}
with open(output_path, "r", encoding="utf-8") as f:
    for raw in f:
        marker = "PUB_P2E08_SELECTED_CASE|"
        if marker not in raw:
            continue
        line = raw[raw.index(marker):].strip()
        fields = {}
        for item in line.split("|")[1:]:
            key, value = item.split("=", 1)
            fields[key] = value
        case = int(fields["CASE"])
        record = {
            "case": case,
            "material": fields["M"],
            "se": float(fields["SE"]),
            "forcing": fields["F"],
            "U_h_inf_cm": float(fields["U_H_INF"]),
            "U_h_rms_cm": float(fields["U_H_RMS"]),
            "U_theta_inf": float(fields["U_THETA_INF"]),
            "U_theta_rms": float(fields["U_THETA_RMS"]),
            "U_storage_cm": float(fields["U_STORAGE"]),
        }
        previous = records.get(case)
        if previous is not None and previous != record:
            raise SystemExit(f"PUB_P2E09_FAIL duplicate case {case} differs across P2E08 replay output")
        records[case] = record

if len(records) != 54:
    raise SystemExit(f"PUB_P2E09_FAIL expected 54 unique P2E08 selected cases, got {len(records)}")

groups = defaultdict(list)
for record in records.values():
    groups[record["se"]].append(record)

expected_levels = [0.65, 0.85, 0.98]
if sorted(groups) != expected_levels:
    raise SystemExit(f"PUB_P2E09_FAIL unexpected Se strata: {sorted(groups)}")
for se in expected_levels:
    if len(groups[se]) != 18:
        raise SystemExit(f"PUB_P2E09_FAIL Se={se} expected 18 cases, got {len(groups[se])}")

if prereg["threshold_rule"]["reference_factor"] != 1.0:
    raise SystemExit("PUB_P2E09_FAIL frozen Reference factor is not 1.0")
if any(value != 0.0 for value in prereg["threshold_rule"]["application_resolution_floor"].values()):
    raise SystemExit("PUB_P2E09_FAIL application-resolution floor is not frozen at zero")

metrics = ["U_h_inf_cm", "U_h_rms_cm", "U_theta_inf", "U_theta_rms", "U_storage_cm"]
for se in expected_levels:
    key = f"Se_{se:.2f}"
    frozen = prereg["frozen_thresholds"][key]
    for metric in metrics:
        values = [record[metric] for record in groups[se]]
        if not all(math.isfinite(value) and value >= 0.0 for value in values):
            raise SystemExit(f"PUB_P2E09_FAIL nonfinite/negative {metric} in Se={se}")
        observed = max(values)
        expected = float(frozen[metric])
        if observed != expected:
            raise SystemExit(
                f"PUB_P2E09_FAIL threshold drift Se={se} metric={metric} observed={observed:.17g} frozen={expected:.17g}"
            )
        print(
            f"PUB_P2E09_THRESHOLD|SE={se:.2f}|METRIC={metric}|REFERENCE_MAX={observed:.17g}|FROZEN={expected:.17g}"
        )

materials = sorted({record["material"] for record in records.values()})
forcing = sorted({record["forcing"] for record in records.values()})
if materials != ["B01", "B12", "O01", "O05", "O14", "O18"]:
    raise SystemExit(f"PUB_P2E09_FAIL material domain drift: {materials}")
if forcing != ["DRYING", "NOMINAL", "WETTING"]:
    raise SystemExit(f"PUB_P2E09_FAIL forcing domain drift: {forcing}")

print("PUB_P2E09_REFERENCE_CASE_COUNT=54")
print("PUB_P2E09_CASES_PER_SE=18")
print("PUB_P2E09_STRATIFICATION=EFFECTIVE_SATURATION_ONLY")
print("PUB_P2E09_REFERENCE_FACTOR=1")
print("PUB_P2E09_APPLICATION_RESOLUTION_FLOOR=ZERO")
print("PUB_P2E09_ROSSFAST_BROAD_RESULTS_USED=FALSE")
print("PUB_P2E09_THRESHOLD_VALIDATION=PASS")
