#!/usr/bin/env python3
"""Fail-closed preregistration and source-lock validation for F-ROM01 V2."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def git_blob(rev: str, path: str) -> str:
    return subprocess.check_output(["git", "rev-parse", f"{rev}:{path}"], text=True).strip()


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--contract", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--candidate-head", required=True)
    ap.add_argument("--test-source", required=True)
    args = ap.parse_args()

    c = load(args.contract)
    if c["phase"] != "PREREGISTERED_BEFORE_V2_EXECUTION":
        raise SystemExit("V2 contract phase drift")
    if c["canonical_baseline"] != args.baseline:
        raise SystemExit("baseline drift")
    if c["production_mutation_allowed"] is not False:
        raise SystemExit("production mutation firewall relaxed")
    if c["physical_design_unchanged"] is not True:
        raise SystemExit("V2 physical-design preservation drift")
    if c["threshold_retuning_after_execution_allowed"] is not False:
        raise SystemExit("threshold-retuning firewall relaxed")
    if c["scientific_sufficiency_threshold"] != "NOT_SET_IN_V2":
        raise SystemExit("pilot introduced a sufficiency threshold")

    d = c["frozen_physical_design"]
    expected = {
        "material_id": "B01",
        "active_nodes": 16,
        "dz_cm": 10.0,
        "root_zone_nodes": 4,
        "initial_effective_saturation": 0.85,
        "outer_interval_duration_day": 0.0016,
        "phase_steps": 48,
        "history_A": ["WET", "DRY"],
        "history_B": ["DRY", "WET"],
        "wet_top_factor": 0.025,
        "dry_top_factor": -0.005,
        "history_bottom_factor": -0.004,
        "continuation_top_factor": 0.010,
        "continuation_steps": 24,
        "continuation_observation_steps": [1, 8, 24],
        "continuation_bottom_mode": 5,
        "collision_projection": "Z1_TOTAL_STORAGE",
        "collision_abs_storage_tolerance_cm": 1e-8,
        "minimum_full_profile_theta_rms_for_distinct_histories": 1e-10,
    }
    for key, value in expected.items():
        if d.get(key) != value:
            raise SystemExit(f"V2 physical design drift: {key}={d.get(key)!r} expected {value!r}")

    p = c["reference_execution_policy"]
    if p["initial_attempt_duration_day"] != 0.0016:
        raise SystemExit("outer interval duration drift")
    if p["retry_trigger"] != "SW_SOLVE_RETRY_ADVISED":
        raise SystemExit("retry trigger drift")
    if p["retry_action"] != "REJECT_CANDIDATE_AND_BISECT_CURRENT_REMAINING_INTERVAL":
        raise SystemExit("retry action drift")
    if p["split_factor"] != 0.5 or p["max_retry_depth"] != 8:
        raise SystemExit("bounded bisection policy drift")
    if p["minimum_internal_duration_day"] != 6.25e-6:
        raise SystemExit("minimum retry duration drift")
    if p["accepted_substep_mass_residual_abs_max_cm"] != 1e-12:
        raise SystemExit("accepted-substep mass gate drift")
    if p["expected_total_outer_intervals_per_history"] != 120:
        raise SystemExit("outer interval count drift")

    v1 = load(c["predecessor_contract"])
    if v1["canonical_baseline"] != args.baseline:
        raise SystemExit("V1/V2 baseline mismatch")
    if v1["research_fixture"]["material_id"] != d["material_id"]:
        raise SystemExit("V1/V2 material drift")
    if v1["geometry"]["active_nodes"] != d["active_nodes"]:
        raise SystemExit("V1/V2 geometry drift")
    if v1["initial_state"]["effective_saturation"] != d["initial_effective_saturation"]:
        raise SystemExit("V1/V2 initial state drift")
    if v1["histories"]["phase_steps"] != d["phase_steps"]:
        raise SystemExit("V1/V2 history length drift")
    if v1["continuation"]["steps"] != d["continuation_steps"]:
        raise SystemExit("V1/V2 continuation length drift")

    adjudication = load(c["predecessor_adjudication"])
    if adjudication["execution_result"] != "FAIL_REFERENCE_ATTEMPT_RETRY_REQUIRED":
        raise SystemExit("V1 failure authority drift")
    if adjudication["decision"] != "RETAIN_V1_AS_FAILED_PILOT_AND_PREREGISTER_V2_WITH_BOUNDED_RETRY_SUBDIVISION":
        raise SystemExit("V1 adjudication decision drift")

    for path, expected_blob in v1["source_locks"].items():
        base_blob = git_blob(args.baseline, path)
        candidate_blob = git_blob(args.candidate_head, path)
        if base_blob != expected_blob or candidate_blob != expected_blob:
            raise SystemExit(
                f"source lock drift for {path}: "
                f"base={base_blob} candidate={candidate_blob} expected={expected_blob}"
            )

    src = Path(args.test_source).read_text(encoding="utf-8")
    required_tokens = [
        "theta_r = 0.02_real64",
        "theta_s = 0.427494_real64",
        "alpha_per_cm = 0.021659_real64",
        "vg_n = 1.734737_real64",
        "ksatfit_cm_per_day = 31.225016_real64",
        "lambda_mvg = 0.98087_real64",
        "phase_steps = 48",
        "continuation_steps = 24",
        "dt_day = 0.0016_real64",
        "collision_storage_tol_cm = 1.0e-8_real64",
        "max_retry_depth = 8",
        "SW_SOLVE_RETRY_ADVISED",
        "depth < max_retry_depth",
        "half_duration = 0.5_real64 * duration",
        "state = result%candidate_state",
    ]
    missing = [token for token in required_tokens if token not in src]
    if missing:
        raise SystemExit(f"V2 test/contract drift: {missing}")

    print("F_ROM01_V2_PREREGISTRATION_LOCK=PASS")
    print("F_ROM01_V2_PHYSICAL_DESIGN_PRESERVATION=PASS")
    print("F_ROM01_V2_RETRY_POLICY_LOCK=PASS")
    print("F_ROM01_SOURCE_LOCKS=PASS")
    print(f"F_ROM01_LOCKED_CANDIDATE_HEAD={args.candidate_head}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
