#!/usr/bin/env python3
"""Parse and validate the F-ROM01 Reference Richards history-collision pilot."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_scalar(value: str):
    low = value.lower()
    if low == "true":
        return True
    if low == "false":
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
        fields[key] = parse_scalar(value)
    return name, fields


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--contract", required=True)
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    contract = json.loads(Path(args.contract).read_text(encoding="utf-8"))
    lines = Path(args.input).read_text(encoding="utf-8").splitlines()

    records: dict[str, list[dict]] = {}
    markers = set()
    for line in lines:
        if not line.startswith("F_ROM01_"):
            continue
        if "|" in line:
            name, fields = parse_record(line)
            records.setdefault(name, []).append(fields)
        elif "=" in line:
            key, value = line.split("=", 1)
            records.setdefault(key, []).append({"value": parse_scalar(value)})
            markers.add(line.strip())

    def one(name: str) -> dict:
        values = records.get(name, [])
        if len(values) != 1:
            raise SystemExit(f"expected exactly one {name} record, got {len(values)}")
        return values[0]

    authority = one("F_ROM01_AUTHORITY")
    initial = one("F_ROM01_INITIAL")
    collision = one("F_ROM01_COLLISION")
    history_mass = one("F_ROM01_HISTORY_MASS")
    all_mass = one("F_ROM01_ALL_MASS")
    continuation = records.get("F_ROM01_CONTINUATION", [])

    expected_steps = contract["continuation"]["observation_steps"]
    actual_steps = [int(r["STEP"]) for r in continuation]
    if actual_steps != expected_steps:
        raise SystemExit(f"continuation checkpoints drift: {actual_steps} != {expected_steps}")

    if authority["BASELINE"] != contract["canonical_baseline"]:
        raise SystemExit("baseline marker drift")
    if authority["MATERIAL"] != contract["research_fixture"]["material_id"]:
        raise SystemExit("material marker drift")
    if int(authority["N"]) != contract["geometry"]["active_nodes"]:
        raise SystemExit("node-count marker drift")
    if int(authority["PHASE_STEPS"]) != contract["histories"]["phase_steps"]:
        raise SystemExit("history step-count marker drift")

    if float(collision["D_S_TOTAL_CM"]) > contract["histories"]["collision_abs_storage_tolerance_cm"]:
        raise SystemExit("deliberate Z1 collision missed preregistered total-storage tolerance")
    if float(collision["THETA_RMS"]) <= contract["histories"]["minimum_full_profile_theta_rms_for_distinct_histories"]:
        raise SystemExit("history pair did not retain a distinct full profile")

    mass_limit = contract["numerical"]["retained_step_mass_residual_abs_max_cm"]
    for label, rec in (("history A", history_mass), ("history B", history_mass), ("all A", all_mass), ("all B", all_mass)):
        field = "MAX_A_CM" if label.endswith("A") else "MAX_B_CM"
        if float(rec[field]) > mass_limit:
            raise SystemExit(f"{label} mass residual exceeded contract")

    required_markers = {
        "F_ROM01_PRODUCTION_SOURCE_MUTATION=NONE",
        "F_ROM01_SCIENTIFIC_SUFFICIENCY_VERDICT=NOT_SET_IN_PILOT",
        "F_ROM01_REFERENCE_HISTORY_PILOT=PASS",
    }
    missing = sorted(required_markers - markers)
    if missing:
        raise SystemExit(f"missing markers: {missing}")

    result = {
        "schema": "swap5.f-rom01.reference-history-pilot-result.v1",
        "workstream": "F-ROM",
        "work_unit": "F-ROM01",
        "contract": args.contract,
        "canonical_baseline": contract["canonical_baseline"],
        "production_source_mutation": "NONE",
        "scientific_sufficiency_verdict": "NOT_SET_IN_PILOT",
        "authority": authority,
        "initial": initial,
        "collision": collision,
        "history_mass": history_mass,
        "continuation": continuation,
        "all_mass": all_mass,
        "pilot_gate": "PASS",
        "interpretation_boundary": (
            "This pilot establishes deterministic Reference Richards history construction, "
            "a preregistered Z1 total-storage collision, and held-identical continuation observations. "
            "It does not establish a minimum sufficient state or a production ROM accuracy threshold."
        ),
    }
    Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("F_ROM01_RESULT_SCHEMA=PASS")
    print("F_ROM01_RESULT_PILOT_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
