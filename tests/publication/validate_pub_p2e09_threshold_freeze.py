#!/usr/bin/env python3
import json
import math
import re
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit("usage: validate_pub_p2e09_threshold_freeze.py <p2e08-log> <preregistration-json>")

log_path = Path(sys.argv[1])
prereg_path = Path(sys.argv[2])

data = json.loads(prereg_path.read_text())
lines = log_path.read_text().splitlines()

selected = {}
pattern = re.compile(
    r"PUB_P2E08_SELECTED_CASE\|CASE=(?P<case>\d+)"
    r"\|M=(?P<material>[^|]+)"
    r"\|SE=(?P<se>[^|]+)"
    r"\|F=(?P<forcing>[^|]+)"
    r"\|DT=(?P<dt>[^|]+)"
    r"\|U_H_INF=(?P<h_inf>[^|]+)"
    r"\|U_H_RMS=(?P<h_rms>[^|]+)"
    r"\|U_THETA_INF=(?P<theta_inf>[^|]+)"
    r"\|U_THETA_RMS=(?P<theta_rms>[^|]+)"
    r"\|U_STORAGE=(?P<storage>[^|\s]+)"
)

for line in lines:
    match = pattern.search(line)
    if not match:
        continue
    row = match.groupdict()
    case_id = int(row["case"])
    parsed = {
        "case": case_id,
        "material": row["material"],
        "se": float(row["se"]),
        "forcing": row["forcing"],
        "dt": float(row["dt"]),
        "U_h_inf_cm": float(row["h_inf"]),
        "U_h_rms_cm": float(row["h_rms"]),
        "U_theta_inf": float(row["theta_inf"]),
        "U_theta_rms": float(row["theta_rms"]),
        "U_storage_cm": float(row["storage"]),
    }
    if case_id in selected:
        previous = selected[case_id]
        if parsed != previous:
            raise SystemExit(f"PUB_P2E09_FAIL duplicate selected case drift: {case_id}")
    else:
        selected[case_id] = parsed

if len(selected) != 54:
    raise SystemExit(f"PUB_P2E09_FAIL expected 54 unique selected cases, got {len(selected)}")

expected_se = [0.65, 0.85, 0.98]
metric_names = ["U_h_inf_cm", "U_h_rms_cm", "U_theta_inf", "U_theta_rms", "U_storage_cm"]

thresholds = data["frozen_thresholds"]

for se in expected_se:
    rows = [row for row in selected.values() if row["se"] == se]
    if len(rows) != 18:
        raise SystemExit(f"PUB_P2E09_FAIL expected 18 cases for Se={se}, got {len(rows)}")
    if any(row["dt"] != 0.0064 for row in rows):
        raise SystemExit(f"PUB_P2E09_FAIL selected calibration dt drift for Se={se}")

    key = f"Se_{se:.2f}"
    frozen = thresholds[key]
    for metric in metric_names:
        values = [row[metric] for row in rows]
        if any(not math.isfinite(value) or value < 0.0 for value in values):
            raise SystemExit(f"PUB_P2E09_FAIL invalid calibration metric {metric} for Se={se}")
        empirical_max = max(values)
        frozen_value = float(frozen[metric])
        if empirical_max != frozen_value:
            raise SystemExit(
                f"PUB_P2E09_FAIL threshold drift Se={se} metric={metric} "
                f"empirical={empirical_max:.17g} frozen={frozen_value:.17g}"
            )
        print(
            f"PUB_P2E09_THRESHOLD|SE={se:.2f}|METRIC={metric}|"
            f"REFERENCE_MAX={empirical_max:.17g}|FROZEN={frozen_value:.17g}"
        )

materials = sorted({row["material"] for row in selected.values()})
forcings = sorted({row["forcing"] for row in selected.values()})
if materials != ["B01", "B12", "O01", "O05", "O14", "O18"]:
    raise SystemExit(f"PUB_P2E09_FAIL material domain drift: {materials}")
if forcings != ["DRYING", "NOMINAL", "WETTING"]:
    raise SystemExit(f"PUB_P2E09_FAIL forcing domain drift: {forcings}")

rule = data["threshold_rule"]
if float(rule["reference_factor"]) != 1.0:
    raise SystemExit("PUB_P2E09_FAIL reference factor is not 1.0")
for metric, floor in rule["application_resolution_floor"].items():
    if float(floor) != 0.0:
        raise SystemExit(f"PUB_P2E09_FAIL nonzero application floor entered for {metric}")

print("PUB_P2E09_REFERENCE_CASE_COUNT=54")
print("PUB_P2E09_SE_065_CASE_COUNT=18")
print("PUB_P2E09_SE_085_CASE_COUNT=18")
print("PUB_P2E09_SE_098_CASE_COUNT=18")
print("PUB_P2E09_REFERENCE_FACTOR=1.0")
print("PUB_P2E09_APPLICATION_RESOLUTION_FLOORS_ZERO=TRUE")
print("PUB_P2E09_THRESHOLD_RECOMPUTATION=PASS")
