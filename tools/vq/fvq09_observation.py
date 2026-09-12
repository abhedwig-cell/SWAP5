#!/usr/bin/env python3
"""Convert an F-VQ09 real probe log into the immutable raw observation shape."""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUALIFIED_PRODUCTION_SOURCE_HEAD = "da5026d8b87ad2f3c7912360891839a120ecccb6"
B1_10_MANIFEST_SHA256 = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"

REAL_KEYS = {
    "T0_DAYS", "TMID_DAYS", "T1_DAYS", "PREFIX_DAYS", "DURATION_DAYS",
    "H_CM", "THETA", "POND_CM", "GWL_CM", "VOLACT_CM", "LDWET_CM", "SPEV_CM", "SAEV_CM",
    "HM1_CM", "THETM1", "PONDM1_CM", "GWLM1_CM",
    "FULL_STORAGE_T0_CM", "FULL_MASS_IN_CM", "FULL_MASS_OUT_CM", "FULL_STORAGE_T1_CM", "FULL_RESIDUAL_CM",
    "SPLIT_STORAGE_T0_CM", "SPLIT_MASS_IN_CM", "SPLIT_MASS_OUT_CM", "SPLIT_STORAGE_T1_CM", "SPLIT_RESIDUAL_CM",
    "HARD_MASS_LIMIT_CM",
}
INT_KEYS = {"COMPATIBLE", "WATER_SCOPE_COMPLETE", "OPTIONAL_PROCESS_STATE_PRESENT", "PROCESS_SCOPE_COMPLETE", "ALLOCATION_MISMATCHES"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_probe(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8", errors="strict")
    if "FVQ09_REAL_TEMPORAL_PROBE_PASS" not in text:
        raise ValueError("probe_pass_marker_missing")
    values: dict[str, str] = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key in REAL_KEYS | INT_KEYS:
            if key in values:
                raise ValueError(f"duplicate_probe_key:{key}")
            values[key] = value.strip()
    missing = sorted((REAL_KEYS | INT_KEYS) - set(values))
    if missing:
        raise ValueError(f"missing_probe_keys:{','.join(missing)}")
    return values


def finite_float(values: dict[str, str], key: str) -> float:
    value = float(values[key])
    if not math.isfinite(value):
        raise ValueError(f"non_finite_probe_value:{key}")
    return value


def int_value(values: dict[str, str], key: str) -> int:
    return int(values[key])


def build_observation(probe_log: Path, bundle_path: Path, materialization_path: Path, compiler_path: Path, optimization: str, harness_commit: str | None) -> dict:
    values = parse_probe(probe_log)
    bundle = load_json(bundle_path)
    materialization = load_json(materialization_path)
    if not bundle.get("bundle_admitted"):
        raise ValueError("bundle_not_admitted")
    if materialization.get("status") != "PASS_MATERIALIZED_QUALIFIED_PHYSICAL_SOURCE":
        raise ValueError("physical_source_not_materialized")
    if harness_commit is None:
        harness_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()

    hard_limit = finite_float(values, "HARD_MASS_LIMIT_CM")
    if hard_limit != 1.0e-6:
        raise ValueError("hard_mass_limit_changed")
    full_residual = finite_float(values, "FULL_RESIDUAL_CM")
    split_residual = finite_float(values, "SPLIT_RESIDUAL_CM")
    full_pass = abs(full_residual) <= hard_limit
    split_pass = abs(split_residual) <= hard_limit
    compatible = int_value(values, "COMPATIBLE") == 1
    water_complete = int_value(values, "WATER_SCOPE_COMPLETE") == 1
    optional_present = int_value(values, "OPTIONAL_PROCESS_STATE_PRESENT") == 1
    process_complete = int_value(values, "PROCESS_SCOPE_COMPLETE") == 1
    allocation_mismatches = int_value(values, "ALLOCATION_MISMATCHES")
    if not full_pass or not split_pass:
        raise ValueError("hard_mass_gate_failed")
    if not compatible or not water_complete or allocation_mismatches != 0:
        raise ValueError("water_endpoint_states_incompatible")
    if not optional_present or process_complete:
        raise ValueError("qualified_hupsel_optional_process_scope_boundary_changed")

    observation = {
        "schema_version": 1,
        "work_unit": "F-VQ09",
        "record_type": "REAL_B1_10_FULL_VS_TWO_HALF_RAW_OBSERVATION",
        "provenance": {
            "fvq09_harness_commit": harness_commit,
            "qualified_production_source_head": QUALIFIED_PRODUCTION_SOURCE_HEAD,
            "b0_distribution_sha256": bundle["b0"]["observed_sha256"],
            "b1_10_source_manifest_sha256": B1_10_MANIFEST_SHA256,
            "materialized_physical_source_manifest_sha256": materialization["materialized_source_manifest_sha256"],
            "ttutil_manifest_sha256": bundle["ttutil"]["candidate_manifest_sha256"],
            "hupsel_case_manifest_sha256": bundle["hupsel_case"]["candidate_manifest_sha256"],
            "compiler_identity": compiler_path.read_text(encoding="utf-8").strip(),
            "optimization": optimization,
        },
        "interval": {
            "t0_days": finite_float(values, "T0_DAYS"),
            "tmid_days": finite_float(values, "TMID_DAYS"),
            "t1_days": finite_float(values, "T1_DAYS"),
            "prefix_days": finite_float(values, "PREFIX_DAYS"),
            "duration_days": finite_float(values, "DURATION_DAYS"),
        },
        "endpoint_differences": {
            "h_cm": finite_float(values, "H_CM"),
            "theta": finite_float(values, "THETA"),
            "pond_cm": finite_float(values, "POND_CM"),
            "gwl_cm": finite_float(values, "GWL_CM"),
            "volact_cm": finite_float(values, "VOLACT_CM"),
            "ldwet_cm": finite_float(values, "LDWET_CM"),
            "spev_cm": finite_float(values, "SPEV_CM"),
            "saev_cm": finite_float(values, "SAEV_CM"),
        },
        "lagged_diagnostics": {
            "hm1_cm": finite_float(values, "HM1_CM"),
            "thetm1": finite_float(values, "THETM1"),
            "pondm1_cm": finite_float(values, "PONDM1_CM"),
            "gwlm1_cm": finite_float(values, "GWLM1_CM"),
        },
        "mass": {
            "full_path": {
                "storage_t0_cm": finite_float(values, "FULL_STORAGE_T0_CM"),
                "mass_in_cm": finite_float(values, "FULL_MASS_IN_CM"),
                "mass_out_cm": finite_float(values, "FULL_MASS_OUT_CM"),
                "storage_t1_cm": finite_float(values, "FULL_STORAGE_T1_CM"),
                "residual_cm": full_residual,
                "hard_limit_cm": hard_limit,
                "pass": full_pass,
            },
            "two_half_path": {
                "storage_t0_cm": finite_float(values, "SPLIT_STORAGE_T0_CM"),
                "mass_in_cm": finite_float(values, "SPLIT_MASS_IN_CM"),
                "mass_out_cm": finite_float(values, "SPLIT_MASS_OUT_CM"),
                "storage_t1_cm": finite_float(values, "SPLIT_STORAGE_T1_CM"),
                "residual_cm": split_residual,
                "hard_limit_cm": hard_limit,
                "pass": split_pass,
            },
        },
        "scope": {
            "compatible": compatible,
            "water_scope_complete": water_complete,
            "optional_process_state_present": optional_present,
            "process_scope_complete": process_complete,
            "allocation_mismatches": allocation_mismatches,
        },
        "temporal_numeric_limits": None,
        "normalized_temporal_score": None,
        "raw_observation_is_production_temporal_acceptance": False,
    }
    return observation


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe-log", required=True, type=Path)
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--materialization", required=True, type=Path)
    parser.add_argument("--compiler", required=True, type=Path)
    parser.add_argument("--optimization", required=True, choices=["O0", "O2"])
    parser.add_argument("--harness-commit")
    args = parser.parse_args()
    try:
        observation = build_observation(args.probe_log, args.bundle, args.materialization, args.compiler, args.optimization, args.harness_commit)
    except Exception as exc:
        print(json.dumps({"work_unit": "F-VQ09", "status": "FAIL_OBSERVATION", "failure": str(exc)}, indent=2))
        return 2
    print(json.dumps(observation, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
