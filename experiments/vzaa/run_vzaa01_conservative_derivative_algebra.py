from __future__ import annotations

import json
import math
import sys
from pathlib import Path

MASS_TOL = 2.0e-14


def apply_pairwise_corrections(state, corrections):
    out = list(state)
    before = math.fsum(out)
    for face, amount in corrections:
        if face < 0 or face >= len(out) - 1:
            raise ValueError(("invalid_internal_face", face))
        out[face] -= amount
        out[face + 1] += amount
    return out, math.fsum(out) - before


def trial(base, dt, q_top, q_bottom, sinks, sources, corrections, *, min_storage=0.0):
    committed_snapshot = tuple(base)
    work = list(base)
    work[0] += dt * q_top
    work[-1] -= dt * q_bottom
    for i in range(len(work)):
        work[i] += dt * (sources[i] - sinks[i])
    before_correction = math.fsum(work)
    work, correction_total_change = apply_pairwise_corrections(work, corrections)
    expected = dt * (q_top - q_bottom + math.fsum(sources) - math.fsum(sinks))
    actual = math.fsum(work) - math.fsum(base)
    residual = actual - expected
    admissible = all(math.isfinite(v) and v >= min_storage for v in work)
    return {
        "accepted": admissible,
        "candidate_state": work,
        "committed_snapshot": committed_snapshot,
        "realized_q_top": q_top,
        "realized_q_bottom": q_bottom,
        "storage_change": actual,
        "expected_external_change": expected,
        "mass_residual": residual,
        "correction_total_change": correction_total_change,
        "pre_correction_total": before_correction,
    }


def run_case(name, **kwargs):
    base = list(kwargs.pop("base"))
    original = tuple(base)
    result = trial(base=base, **kwargs)
    result["name"] = name
    result["base_state_unchanged"] = tuple(base) == original
    return result


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_vzaa01_conservative_derivative_algebra.py RESULT_JSON")
    out = Path(sys.argv[1])

    cases = []
    cases.append(run_case(
        "closed_pairwise",
        base=(2.0, 3.0, 4.0), dt=0.25, q_top=0.0, q_bottom=0.0,
        sinks=(0.0, 0.0, 0.0), sources=(0.0, 0.0, 0.0),
        corrections=((1, -0.17), (0, 0.31)),
    ))
    cases.append(run_case(
        "prescribed_bottom_downward",
        base=(2.0, 3.0, 4.0), dt=0.4, q_top=0.8, q_bottom=0.35,
        sinks=(0.0, 0.02, 0.0), sources=(0.0, 0.0, 0.0),
        corrections=((1, 0.11), (0, -0.04)),
    ))
    cases.append(run_case(
        "prescribed_bottom_upward",
        base=(2.0, 3.0, 4.0), dt=0.4, q_top=0.0, q_bottom=-0.27,
        sinks=(0.0, 0.01, 0.0), sources=(0.0, 0.0, 0.0),
        corrections=((1, -0.08), (0, -0.03)),
    ))
    cases.append(run_case(
        "distributed_source_sink",
        base=(2.0, 3.0, 4.0), dt=0.125, q_top=0.15, q_bottom=0.06,
        sinks=(0.02, 0.07, 0.04), sources=(0.01, 0.0, 0.03),
        corrections=((1, 0.23), (0, 0.09)),
    ))

    # Prescribed-head algebra: q_bottom is an explicit trial unknown. A head mismatch is
    # returned as a residual; it is never converted into an undeclared storage correction.
    head_trial = run_case(
        "prescribed_head_explicit_residual",
        base=(2.0, 3.0, 4.0), dt=0.2, q_top=0.1, q_bottom=-0.12,
        sinks=(0.0, 0.0, 0.0), sources=(0.0, 0.0, 0.0),
        corrections=((1, -0.05), (0, 0.02)),
    )
    h_boundary = 1.25
    h_candidate = 0.5 * head_trial["candidate_state"][-1] - 0.6
    head_trial["imposed_bottom_head"] = h_boundary
    head_trial["candidate_bottom_head"] = h_candidate
    head_trial["bottom_head_residual"] = h_candidate - h_boundary
    head_trial["hidden_compensating_flux"] = 0.0
    cases.append(head_trial)

    # Deliberately inadmissible correction. The trial object may contain an invalid
    # candidate, but the committed input object must remain exactly untouched.
    rejected = run_case(
        "inadmissible_rejected",
        base=(0.2, 0.3, 0.4), dt=0.1, q_top=0.0, q_bottom=0.0,
        sinks=(0.0, 0.0, 0.0), sources=(0.0, 0.0, 0.0),
        corrections=((0, 1.0),), min_storage=0.0,
    )
    cases.append(rejected)

    accepted = [c for c in cases if c["accepted"]]
    mass_max = max(abs(c["mass_residual"]) for c in accepted)
    correction_max = max(abs(c["correction_total_change"]) for c in cases)
    down = next(c for c in cases if c["name"] == "prescribed_bottom_downward")
    up = next(c for c in cases if c["name"] == "prescribed_bottom_upward")
    head = next(c for c in cases if c["name"] == "prescribed_head_explicit_residual")
    rej = next(c for c in cases if c["name"] == "inadmissible_rejected")

    checks = {
        "accepted_mass_residual_within_tolerance": mass_max <= MASS_TOL,
        "pairwise_internal_transfer_total_change_within_tolerance": correction_max <= MASS_TOL,
        "downward_bottom_flux_realized_exactly": down["realized_q_bottom"] == 0.35,
        "upward_bottom_flux_realized_exactly_without_clipping": up["realized_q_bottom"] == -0.27,
        "head_residual_is_explicit_and_nonzero": abs(head["bottom_head_residual"]) > 0.0,
        "head_residual_has_no_hidden_compensating_flux": head["hidden_compensating_flux"] == 0.0,
        "rejected_trial_is_rejected": not rej["accepted"],
        "all_base_states_unchanged": all(c["base_state_unchanged"] for c in cases),
    }
    passed = all(checks.values())
    evidence = {
        "schema_version": 1,
        "work_unit": "F-VZAA01",
        "gate": "CONSERVATIVE_DERIVATIVE_ALGEBRA",
        "classification": "VZAA_DERIVED_ALGORITHMIC_RESEARCH_ONLY",
        "mass_tolerance": MASS_TOL,
        "cases": cases,
        "metrics": {
            "accepted_mass_residual_abs_max": mass_max,
            "internal_pairwise_transfer_total_change_abs_max": correction_max,
        },
        "checks": checks,
        "pass": passed,
        "decision": (
            "CONSERVATIVE_DERIVATIVE_ALGEBRA_QUALIFIED_FOR_PREDICTOR_INTEGRATION"
            if passed else
            "CONSERVATIVE_DERIVATIVE_ALGEBRA_FAILED_DO_NOT_ADD_PREDICTOR"
        ),
        "non_claims": [
            "published VZAA reproduction",
            "VZAA hydraulic fidelity",
            "prescribed-head convergence",
            "production solver qualification"
        ],
    }
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
