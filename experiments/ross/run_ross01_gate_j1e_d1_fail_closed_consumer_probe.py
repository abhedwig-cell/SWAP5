from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_j1e_d1_head_space_trust_preconditioner as gate


def fake_predictor(*, available: bool, tangent, reason: str) -> dict:
    return {
        "h_bottom_cm": -100.0,
        "local_terminal_tangent_available": available,
        "local_terminal_dh_bottom_dqbot_day": tangent,
        "local_terminal_tangent_scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
        "local_terminal_tangent_reason": reason,
    }


def run_probe() -> dict:
    unavailable = gate.correction_case(
        theta0=(),
        table=None,
        ext={},
        predictor=fake_predictor(
            available=False,
            tangent=None,
            reason="QUALIFICATION_PROBE_UNAVAILABLE",
        ),
        qbot0=0.0,
        q_scale=1.0,
        step_count=4,
        target_offset=0.02,
    )

    invalid = gate.correction_case(
        theta0=(),
        table=None,
        ext={},
        predictor=fake_predictor(
            available=True,
            tangent=-1.0,
            reason="QUALIFICATION_PROBE_NEGATIVE_TANGENT",
        ),
        qbot0=0.0,
        q_scale=1.0,
        step_count=4,
        target_offset=0.02,
    )

    tests = {
        "unavailable_tangent_no_corrector_attempt": (
            unavailable.get("corrector_attempted") is False
            and unavailable.get("corrector_run") is False
        ),
        "unavailable_tangent_not_published": (
            unavailable.get("coupled_candidate_published") is False
            and unavailable.get("fallback_required") is True
        ),
        "unavailable_tangent_route_explicit": (
            unavailable.get("route")
            == "FALLBACK_LOCAL_TERMINAL_TANGENT_UNAVAILABLE"
            and unavailable.get("fallback_reason") == "QUALIFICATION_PROBE_UNAVAILABLE"
        ),
        "invalid_preconditioner_no_corrector_attempt": (
            invalid.get("corrector_attempted") is False
            and invalid.get("corrector_run") is False
        ),
        "invalid_preconditioner_not_published": (
            invalid.get("coupled_candidate_published") is False
            and invalid.get("fallback_required") is True
        ),
        "invalid_preconditioner_route_explicit": (
            invalid.get("route") == "FALLBACK_INVALID_PRECONDITIONER"
            and invalid.get("fallback_reason")
            == "NONFINITE_OR_NONPOSITIVE_PRECONDITIONER"
        ),
        "scope_not_relabelled_in_unavailable_path": (
            unavailable.get("local_terminal_tangent_scope")
            == "LOCAL_TERMINAL_SUBSTEP_ONLY"
            and unavailable.get("local_terminal_tangent_is_whole_window_derivative") is False
            and unavailable.get("preconditioner_is_whole_window_derivative") is False
        ),
        "scope_not_relabelled_in_invalid_path": (
            invalid.get("local_terminal_tangent_scope")
            == "LOCAL_TERMINAL_SUBSTEP_ONLY"
            and invalid.get("local_terminal_tangent_is_whole_window_derivative") is False
            and invalid.get("preconditioner_is_whole_window_derivative") is False
        ),
    }

    return {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "J1E_D1_LOCAL_TERMINAL_COUPLING_PRECONDITIONER",
        "probe": "EXPLICIT_FAIL_CLOSED_CONSUMER_PATHS",
        "production_implementation": False,
        "production_admission": False,
        "whole_window_derivative_claimed": False,
        "tests": tests,
        "failed_metrics": [name for name, ok in tests.items() if not ok],
        "pass": all(tests.values()),
        "unavailable_case": unavailable,
        "invalid_preconditioner_case": invalid,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(
            "usage: run_ross01_gate_j1e_d1_fail_closed_consumer_probe.py OUTPUT.json"
        )
    output = Path(sys.argv[1])
    result = run_probe()
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        key: value for key, value in result.items()
        if key not in ("unavailable_case", "invalid_preconditioner_case")
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
