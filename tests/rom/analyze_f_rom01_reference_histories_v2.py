#!/usr/bin/env python3
"""Parse and validate F-ROM01 V2 reference-history evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def scalar(value: str):
    low = value.lower()
    if low == "true":
        return True
    if low == "false":
        return False
    if value == "T":
        return True
    if value == "F":
        return False
    try:
        if any(ch in value for ch in ".eEdD"):
            return float(value.replace("D", "E").replace("d", "e"))
        return int(value)
    except ValueError:
        return value


def parse_record(line: str):
    parts = line.strip().split("|")
    name = parts[0]
    fields = {}
    for item in parts[1:]:
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        fields[key] = scalar(value)
    return name, fields


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--contract", required=True)
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    contract = json.loads(Path(args.contract).read_text(encoding="utf-8"))
    records: dict[str, list[dict]] = {}
    markers = set()
    for line in Path(args.input).read_text(encoding="utf-8").splitlines():
        if not line.startswith("F_ROM01_"):
            continue
        if "|" in line:
            name, fields = parse_record(line)
            records.setdefault(name, []).append(fields)
        elif "=" in line:
            key, value = line.split("=", 1)
            records.setdefault(key, []).append({"value": scalar(value)})
            markers.add(line.strip())

    def one(name: str) -> dict:
        vals = records.get(name, [])
        if len(vals) != 1:
            raise SystemExit(f"expected exactly one {name}, got {len(vals)}")
        return vals[0]

    authority = one("F_ROM01_AUTHORITY")
    initial = one("F_ROM01_INITIAL")
    collision = one("F_ROM01_COLLISION")
    history_mass = one("F_ROM01_HISTORY_MASS")
    history_exec = one("F_ROM01_HISTORY_EXECUTION")
    all_mass = one("F_ROM01_ALL_MASS")
    all_exec = one("F_ROM01_ALL_EXECUTION")
    continuation = records.get("F_ROM01_CONTINUATION", [])
    retries = records.get("F_ROM01_RETRY", [])

    d = contract["frozen_physical_design"]
    p = contract["reference_execution_policy"]

    if authority["BASELINE"] != contract["canonical_baseline"]:
        raise SystemExit("baseline marker drift")
    if authority["MATERIAL"] != d["material_id"]:
        raise SystemExit("material marker drift")
    if int(authority["N"]) != d["active_nodes"]:
        raise SystemExit("node count marker drift")
    if int(authority["PHASE_STEPS"]) != d["phase_steps"]:
        raise SystemExit("phase step marker drift")

    expected_steps = d["continuation_observation_steps"]
    actual_steps = [int(r["STEP"]) for r in continuation]
    if actual_steps != expected_steps:
        raise SystemExit(f"continuation checkpoint drift: {actual_steps} != {expected_steps}")

    if float(collision["D_S_TOTAL_CM"]) > d["collision_abs_storage_tolerance_cm"]:
        raise SystemExit("Z1 total-storage collision missed preregistered tolerance")
    if float(collision["THETA_RMS"]) <= d["minimum_full_profile_theta_rms_for_distinct_histories"]:
        raise SystemExit("collision histories do not retain distinct full profiles")

    mass_limit = p["accepted_substep_mass_residual_abs_max_cm"]
    for rec_name, rec in (("history", history_mass), ("all", all_mass)):
        for side in ("A", "B"):
            val = float(rec[f"MAX_{side}_CM"])
            if val > mass_limit:
                raise SystemExit(f"{rec_name} {side} mass residual {val} exceeds {mass_limit}")

    expected_history = p["expected_history_outer_intervals_per_history"]
    expected_total = p["expected_total_outer_intervals_per_history"]
    for side in ("A", "B"):
        hist_substeps = int(history_exec[f"ACCEPTED_SUBSTEPS_{side}"])
        all_substeps = int(all_exec[f"ACCEPTED_SUBSTEPS_{side}"])
        if hist_substeps < expected_history:
            raise SystemExit(f"history {side} accepted fewer substeps than outer intervals")
        if all_substeps < expected_total:
            raise SystemExit(f"all {side} accepted fewer substeps than outer intervals")
        if int(all_exec[f"RETRY_ATTEMPTS_{side}"]) < int(history_exec[f"RETRY_ATTEMPTS_{side}"]):
            raise SystemExit(f"retry count regressed for {side}")

    if not retries:
        raise SystemExit("V2 did not exercise the preregistered retry path")
    for r in retries:
        if int(r["DEPTH"]) >= p["max_retry_depth"]:
            raise SystemExit("retry record reached/exceeded prohibited split depth")
        if float(r["DT_DAY"]) < p["minimum_internal_duration_day"]:
            raise SystemExit("retry record below minimum internal duration")

    required_markers = {
        "F_ROM01_PRODUCTION_SOURCE_MUTATION=NONE",
        "F_ROM01_REJECTED_RETRY_COMMIT=NONE",
        "F_ROM01_V2_EXECUTION_POLICY=BOUNDED_BISECTION",
        "F_ROM01_SCIENTIFIC_SUFFICIENCY_VERDICT=NOT_SET_IN_PILOT",
        "F_ROM01_REFERENCE_HISTORY_PILOT=PASS",
    }
    missing = sorted(required_markers - markers)
    if missing:
        raise SystemExit(f"missing V2 markers: {missing}")

    result = {
        "schema": "swap5.f-rom01.reference-history-pilot-v2-result.v1",
        "workstream": "F-ROM",
        "work_unit": "F-ROM01",
        "contract": args.contract,
        "canonical_baseline": contract["canonical_baseline"],
        "production_source_mutation": "NONE",
        "reference_execution_policy": "BOUNDED_BISECTION",
        "rejected_retry_commit": "NONE",
        "scientific_sufficiency_verdict": "NOT_SET_IN_PILOT",
        "authority": authority,
        "initial": initial,
        "collision": collision,
        "history_mass": history_mass,
        "history_execution": history_exec,
        "continuation": continuation,
        "all_mass": all_mass,
        "all_execution": all_exec,
        "retry_records": retries,
        "pilot_gate": "PASS",
        "interpretation_boundary": (
            "V2 establishes a deterministic accepted Reference Richards trajectory for the frozen "
            "history-collision experiment under bounded retry subdivision. It records collision and "
            "identical-future divergence evidence but does not establish a minimum sufficient state "
            "or production ROM accuracy threshold."
        ),
    }
    Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("F_ROM01_V2_RESULT_SCHEMA=PASS")
    print("F_ROM01_V2_RESULT_PILOT_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
