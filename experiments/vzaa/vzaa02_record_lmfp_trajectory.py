#!/usr/bin/env python3
"""Record the qualified F-LMFP08 candidate trajectory for F-VZAA02 D0.

This is experiment-only diagnostic output.  It reuses the constrained continuous
MFP log-Darcian-ratio candidate already present in the qualified F-LMFP08 base.
No candidate history is added to production state.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
LMFP = HERE.parent / "lmfp"
if str(LMFP) not in sys.path:
    sys.path.insert(0, str(LMFP))

from run_lmfp04_ab import DZ, case_definition
import run_lmfp08_physics_informed_correction as core
from run_lmfp08_constrained_mfp_ratio import ConstrainedMFPCache

EXPECTED_CASES = 6
EXPECTED_REFINEMENTS = 2
INHERITED_LMFP08_MASS_THRESHOLD = 2.0e-10


def parse_reference_schedule(path: Path):
    schedules = defaultdict(list)
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        p = raw.split()
        if not p or p[0] != "VZAA02_STEP":
            continue
        if len(p) != 10:
            raise ValueError(f"line {lineno}: malformed VZAA02_STEP")
        case_id, refinement, step = map(int, p[1:4])
        t0, t1, dt = map(float, p[4:7])
        schedules[(case_id, refinement)].append((step, t0, t1, dt))
    return schedules


def close(a: float, b: float) -> bool:
    return abs(a - b) <= 2.0e-13 * max(1.0, abs(a), abs(b))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference_trajectory", type=Path)
    parser.add_argument("trajectory_jsonl", type=Path)
    parser.add_argument("evidence_json", type=Path)
    args = parser.parse_args()

    schedules = parse_reference_schedule(args.reference_trajectory)
    expected_series = {(c, r) for c in range(1, EXPECTED_CASES + 1)
                       for r in range(1, EXPECTED_REFINEMENTS + 1)}
    if set(schedules) != expected_series:
        raise SystemExit(f"F-VZAA02 schedule set mismatch: {sorted(schedules)}")

    args.trajectory_jsonl.parent.mkdir(parents=True, exist_ok=True)
    args.evidence_json.parent.mkdir(parents=True, exist_ok=True)

    cache = ConstrainedMFPCache()
    accepted_steps = 0
    max_mass = 0.0
    series_evidence = []

    with args.trajectory_jsonl.open("w", encoding="utf-8") as out:
        out.write(json.dumps({
            "record_type": "metadata",
            "work_unit": "F-VZAA02",
            "candidate": "F-LMFP08_CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO",
            "history_status": "experiment_only_not_persistent_production_state",
            "reference_schedule_use": "alignment_crosscheck_only_no_reference_state_or_flux_enters_candidate",
        }, sort_keys=True) + "\n")

        for case_id in range(1, EXPECTED_CASES + 1):
            name, codes, heads0, duration, base_dt, top_flux = case_definition(case_id)
            mats = [core.MATERIAL_BY_CODE[c] for c in codes]
            if case_id == 1:
                top_flux = mats[0].conductivity(heads0[0])

            for refinement in range(1, EXPECTED_REFINEMENTS + 1):
                dt_expected = base_dt / refinement
                nsteps_expected = round(duration / dt_expected)
                schedule = sorted(schedules[(case_id, refinement)])
                if len(schedule) != nsteps_expected:
                    raise SystemExit(
                        f"F-VZAA02 schedule length mismatch case={case_id} refinement={refinement}: "
                        f"reference={len(schedule)} nominal={nsteps_expected}"
                    )

                state = [m.theta(h) * dz for m, h, dz in zip(mats, heads0, DZ)]
                series_max_mass = 0.0
                previous_t1 = 0.0

                for expected_step, (step, t0, t1, dt_ref) in enumerate(schedule, 1):
                    if step != expected_step:
                        raise SystemExit(f"noncontiguous reference schedule {(case_id, refinement, step)}")
                    nominal_t0 = (step - 1) * dt_expected
                    nominal_t1 = step * dt_expected
                    if not (close(dt_ref, dt_expected) and close(t0, nominal_t0) and
                            close(t1, nominal_t1) and close(t0, previous_t1)):
                        raise SystemExit(
                            f"reference/nominal time-grid mismatch case={case_id} refinement={refinement} "
                            f"step={step}: {(t0,t1,dt_ref)} vs {(nominal_t0,nominal_t1,dt_expected)}"
                        )

                    theta_before = [w / dz for w, dz in zip(state, DZ)]
                    trial = core.corrected_trial(state, codes, DZ, dt_expected, top_flux, cache)
                    if not trial["accepted"]:
                        raise SystemExit(
                            f"qualified LMFP08 candidate rejected in D0 recorder "
                            f"case={case_id} refinement={refinement} step={step}: {trial['reason']}"
                        )
                    if len(trial["face"]) != len(DZ) + 1:
                        raise SystemExit("F-VZAA02 candidate face cardinality mismatch")

                    state_after = list(trial["state"])
                    theta_after = [w / dz for w, dz in zip(state_after, DZ)]
                    head_after = [m.head_from_theta(theta) for m, theta in zip(mats, theta_after)]
                    mass = abs(float(trial["mass_residual"]))
                    series_max_mass = max(series_max_mass, mass)
                    max_mass = max(max_mass, mass)

                    out.write(json.dumps({
                        "record_type": "accepted_step",
                        "case_id": case_id,
                        "case_name": name,
                        "refinement": refinement,
                        "step": step,
                        "t0": t0,
                        "t1": t1,
                        "dt": dt_expected,
                        "codes": list(codes),
                        "dz": list(DZ),
                        "theta_before": theta_before,
                        "head_before": list(trial["heads"]),
                        "theta_after": theta_after,
                        "head_after": head_after,
                        "face_flux_down": list(trial["face"]),
                        "mass_residual": float(trial["mass_residual"]),
                    }, sort_keys=True) + "\n")

                    state = state_after
                    previous_t1 = t1
                    accepted_steps += 1

                if not close(previous_t1, duration):
                    raise SystemExit(
                        f"series final time mismatch case={case_id} refinement={refinement}: "
                        f"{previous_t1} vs {duration}"
                    )
                series_evidence.append({
                    "case_id": case_id,
                    "case_name": name,
                    "refinement": refinement,
                    "accepted_steps": nsteps_expected,
                    "dt": dt_expected,
                    "max_abs_mass_residual": series_max_mass,
                })

    structural_pass = (accepted_steps == 660 and
                       max_mass <= INHERITED_LMFP08_MASS_THRESHOLD and
                       cache.coverage_misses == 0)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-VZAA02",
        "gate": "D0_A_LMFP_CANDIDATE_TRAJECTORY_CAPTURE",
        "candidate": "F-LMFP08_CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO",
        "production_implementation": False,
        "persistent_history_added": False,
        "reference_state_leakage": False,
        "reference_schedule_role": "crosscheck only; every interval must equal nominal case_definition grid",
        "accepted_steps": accepted_steps,
        "expected_accepted_steps": 660,
        "max_abs_mass_residual": max_mass,
        "mass_threshold": INHERITED_LMFP08_MASS_THRESHOLD,
        "mass_threshold_origin": "inherited existing F-LMFP08 transient structural gate; not newly defined by F-VZAA02",
        "cache": cache.diagnostics(),
        "series": series_evidence,
        "structural_pass": structural_pass,
        "scope_limit": "ordinary six F-LMFP04 cases only; no VZAA donor physics evaluated yet",
    }
    args.evidence_json.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    print("F-VZAA02_LMFP_TRAJECTORY_PASS" if structural_pass else "F-VZAA02_LMFP_TRAJECTORY_FAIL")
    return 0 if structural_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
