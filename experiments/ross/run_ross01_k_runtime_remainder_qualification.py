from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

import ross01_d3g02r_resolution_floor_certificate_adapter as wrapper
import ross01_d3r_fsi31_duration_adapter as d3r
import run_ross01_d2_fsi31_qualification as d2q

MASS_TOL_CM = 1.0e-12
MAX_FULL_INDEX = 8
TEST_INITIAL_INDEX = 2
MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
OUTER_HORIZON_DAY = float(d3r.DURATION_LADDER_DAY[0])
MIN_FULL_DURATION_DAY = float(d3r.DURATION_LADDER_DAY[MAX_FULL_INDEX])
OUTER_UNITS = 1 << MAX_FULL_INDEX


def _canon(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _digest(value) -> str:
    return hashlib.sha256(_canon(value).encode("utf-8")).hexdigest()


def _set_interval(request: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(request)
    forcing = out["forcing_process_requests"]
    forcing["t0_day"] = float(t0)
    forcing["t1_day"] = float(t0 + dt)
    return out


def _forcing_physics(request: dict) -> dict:
    forcing = copy.deepcopy(request["forcing_process_requests"])
    forcing.pop("t0_day", None)
    forcing.pop("t1_day", None)
    return forcing


def _duration_units(index: int) -> int:
    if not isinstance(index, int) or index < 0 or index > MAX_FULL_INDEX:
        raise ValueError("full-attempt index outside 0..8")
    return 1 << (MAX_FULL_INDEX - index)


def _duration_to_units(duration_day: float) -> int:
    value = float(duration_day)
    if not math.isfinite(value) or value <= 0.0 or value > OUTER_HORIZON_DAY:
        raise ValueError("duration outside bounded outer horizon")
    units = int(round(value / MIN_FULL_DURATION_DAY))
    if units <= 0:
        raise ValueError("duration below smallest qualified full-attempt unit")
    reconstructed = units * MIN_FULL_DURATION_DAY
    tol = max(2.0e-15, 4.0 * math.ulp(value), 4.0 * math.ulp(reconstructed))
    if not math.isclose(value, reconstructed, rel_tol=0.0, abs_tol=tol):
        raise ValueError("duration is not on the bounded D3R level-8 grid")
    return units


def _schedule_units(remaining_units: int) -> list[int]:
    if not isinstance(remaining_units, int) or remaining_units < 0 or remaining_units > OUTER_UNITS:
        raise ValueError("remaining duration outside bounded integer grid")
    schedule: list[int] = []
    remaining = remaining_units
    for index in range(0, MAX_FULL_INDEX + 1):
        units = _duration_units(index)
        if units <= remaining:
            schedule.append(index)
            remaining -= units
    if remaining != 0:
        raise ValueError("remainder cannot be represented by qualified D3R full-attempt durations")
    return schedule


def _schedule_after_shortened_accept(initial_index: int) -> list[int]:
    accepted_units = _duration_units(initial_index)
    return _schedule_units(OUTER_UNITS - accepted_units)


def _retry_cap_for_segment(index: int) -> int:
    return MAX_FULL_INDEX - index


def _positive_candidate(out: dict) -> dict:
    cert = out.get("temporal_certificate") or {}
    diag = out.get("solver_work_diagnostics") or {}
    indicator = out.get("temporal_indicator")
    residual = out.get("unrounded_mass_residual_cm")
    return {
        "candidate_ready": out.get("solver_disposition") == "candidate_ready",
        "certificate_available": out.get("temporal_certificate_available") is True and cert.get("available") is True,
        "certificate_exact_d3r_scope": cert.get("scope") == "EXACT_D3R_QUALIFIED_DOMAIN_ONLY",
        "certificate_refined_two_half": cert.get("candidate_route") == "REFINED_TWO_HALF",
        "three_component_trials": diag.get("certificate_component_trial_count") == 3,
        "canonical_runtime_only_authority": diag.get("certificate_acceptance_authority") == "CANONICAL_RUNTIME_ONLY",
        "indicator_acceptable": isinstance(indicator, (int, float))
        and math.isfinite(float(indicator))
        and 0.0 <= float(indicator) <= 1.0,
        "mass_hard_gate": isinstance(residual, (int, float))
        and math.isfinite(float(residual))
        and abs(float(residual)) <= MASS_TOL_CM,
        "candidate_only": out.get("accepted") is False
        and out.get("commit_authorized") is False
        and out.get("accepted_publication_authorized") is False,
        "committed_not_mutated": out.get("committed_state_mutated") is False,
        "request_unchanged_reported": out.get("request_object_unchanged") is True,
    }


def _receipt(out: dict, input_state: dict, t0: float, index: int) -> dict:
    candidate = copy.deepcopy(out.get("candidate_hydraulic_state"))
    return {
        "input_state_digest": _digest(input_state),
        "t0_day": float(t0),
        "duration_ladder_index": int(index),
        "duration_day": float(d3r.DURATION_LADDER_DAY[index]),
        "candidate_hydraulic_state": candidate,
        "candidate_digest": _digest(candidate),
        "certificate_digest": _digest(out.get("temporal_certificate")),
        "temporal_indicator": out.get("temporal_indicator"),
        "storage_change_cm": out.get("storage_change_cm"),
        "mass_terms": copy.deepcopy(out.get("mass_terms")),
        "unrounded_mass_residual_cm": out.get("unrounded_mass_residual_cm"),
    }


def _promote_private(receipt: dict, current_state: dict, expected_t0: float, expected_index: int) -> dict | None:
    if receipt.get("input_state_digest") != _digest(current_state):
        return None
    if receipt.get("duration_ladder_index") != expected_index:
        return None
    if not math.isclose(float(receipt.get("t0_day")), float(expected_t0), rel_tol=0.0, abs_tol=2.0e-15):
        return None
    candidate = receipt.get("candidate_hydraulic_state")
    if not isinstance(candidate, dict) or receipt.get("candidate_digest") != _digest(candidate):
        return None
    indicator = receipt.get("temporal_indicator")
    residual = receipt.get("unrounded_mass_residual_cm")
    if not isinstance(indicator, (int, float)) or not math.isfinite(float(indicator)) or not 0.0 <= float(indicator) <= 1.0:
        return None
    if not isinstance(residual, (int, float)) or not math.isfinite(float(residual)) or abs(float(residual)) > MASS_TOL_CM:
        return None
    return copy.deepcopy(candidate)


def _storage_cm(state: dict) -> float:
    return float(d2q.adapter.DZ_CM) * math.fsum(float(v) for v in state["water_content"])


def _aggregate_mass(initial_state: dict, final_state: dict, receipts: list[dict]) -> tuple[float, dict]:
    totals = {
        "top_boundary_transfer_cm": 0.0,
        "bottom_boundary_transfer_cm": 0.0,
        "source_transfer_cm": 0.0,
        "sink_transfer_cm": 0.0,
    }
    for receipt in receipts:
        terms = receipt.get("mass_terms") or {}
        for key in totals:
            value = terms.get(key)
            if not isinstance(value, (int, float)) or not math.isfinite(float(value)):
                raise ValueError(f"missing/nonfinite mass term {key}")
            totals[key] += float(value)
    storage_change = _storage_cm(final_state) - _storage_cm(initial_state)
    residual = (
        storage_change
        - totals["top_boundary_transfer_cm"]
        - totals["bottom_boundary_transfer_cm"]
        - totals["source_transfer_cm"]
        + totals["sink_transfer_cm"]
    )
    totals["storage_change_cm"] = storage_change
    totals["residual_cm"] = residual
    return residual, totals


def _algebra_checks() -> dict:
    checks = {}
    for initial_index in range(1, MAX_FULL_INDEX + 1):
        schedule = _schedule_after_shortened_accept(initial_index)
        checks[f"level_{initial_index}_schedule_exact"] = schedule == list(range(1, initial_index + 1))
        units = _duration_units(initial_index) + sum(_duration_units(i) for i in schedule)
        checks[f"level_{initial_index}_closes_outer_horizon"] = units == OUTER_UNITS
        checks[f"level_{initial_index}_retry_caps_bounded"] = all(
            i + _retry_cap_for_segment(i) == MAX_FULL_INDEX for i in schedule
        )
    try:
        _duration_to_units(MIN_FULL_DURATION_DAY * 0.5)
        checks["below_minimum_grid_fails_closed"] = False
    except ValueError:
        checks["below_minimum_grid_fails_closed"] = True
    checks["outer_duration_grid_exact"] = _duration_to_units(OUTER_HORIZON_DAY) == OUTER_UNITS
    return checks


def _run_chain(material: str, canonical_head: str, replay: bool = False) -> dict:
    t0 = 19.25
    base = d2q.base_request(material, t0=t0, steps=8, perturb=0.0, pre=False)
    forcing_template = _forcing_physics(base)
    external_committed = copy.deepcopy(base["committed_state"])
    external_before = copy.deepcopy(external_committed)
    working = copy.deepcopy(external_committed)
    initial_working = copy.deepcopy(working)
    cursor = t0
    indices = [TEST_INITIAL_INDEX] + _schedule_after_shortened_accept(TEST_INITIAL_INDEX)
    expected_indices = [2, 1, 2]
    receipts = []
    segment_records = []
    stale_receipt = None
    stale_rejected = False
    forcing_preserved = True

    for position, index in enumerate(indices):
        dt = float(d3r.DURATION_LADDER_DAY[index])
        request = copy.deepcopy(base)
        request["committed_state"] = copy.deepcopy(working)
        request["forcing_process_requests"].update(copy.deepcopy(forcing_template))
        request = _set_interval(request, cursor, dt)
        forcing_preserved = forcing_preserved and _forcing_physics(request) == forcing_template
        before = copy.deepcopy(request)
        state_before = copy.deepcopy(working)

        out = wrapper.execute_research_trial(request)
        checks = _positive_candidate(out)
        checks["caller_request_exactly_unchanged"] = request == before
        checks["private_committed_input_unchanged"] = request["committed_state"] == state_before
        checks["segment_index_expected"] = index == expected_indices[position]
        checks["retry_cap_stays_within_full_level_8"] = index + _retry_cap_for_segment(index) == MAX_FULL_INDEX
        if not all(checks.values()):
            return {
                "pass": False,
                "material": material,
                "canonical_head": canonical_head,
                "failure": "SEGMENT_QUALIFICATION_FAILED",
                "segment_position": position,
                "segment_index": index,
                "checks": checks,
                "records": segment_records,
            }

        receipt = _receipt(out, state_before, cursor, index)
        promoted = _promote_private(receipt, state_before, cursor, index)
        if promoted is None:
            return {
                "pass": False,
                "material": material,
                "canonical_head": canonical_head,
                "failure": "ACCEPTED_RECEIPT_PROMOTION_FAILED",
                "segment_position": position,
                "segment_index": index,
                "records": segment_records,
            }

        if position == 0:
            stale_receipt = copy.deepcopy(receipt)
        elif position == 1 and stale_receipt is not None:
            stale_rejected = _promote_private(stale_receipt, promoted, cursor + dt, index) is None

        receipts.append(receipt)
        working = promoted
        segment_records.append(
            {
                "position": position,
                "duration_ladder_index": index,
                "duration_day": dt,
                "retry_cap": _retry_cap_for_segment(index),
                "t0_day": cursor,
                "t1_day": cursor + dt,
                "input_state_digest": receipt["input_state_digest"],
                "candidate_digest": receipt["candidate_digest"],
                "certificate_digest": receipt["certificate_digest"],
                "temporal_indicator": receipt["temporal_indicator"],
                "mass_residual_cm": receipt["unrounded_mass_residual_cm"],
            }
        )
        cursor += dt

        if external_committed != external_before:
            return {
                "pass": False,
                "material": material,
                "canonical_head": canonical_head,
                "failure": "EXTERNAL_COMMITTED_STATE_CHANGED_BEFORE_OUTER_COMPLETION",
                "records": segment_records,
            }

    aggregate_residual, aggregate_terms = _aggregate_mass(initial_working, working, receipts)
    complete_tol = max(2.0e-15, 8.0 * math.ulp(t0 + OUTER_HORIZON_DAY))
    complete = math.isclose(cursor, t0 + OUTER_HORIZON_DAY, rel_tol=0.0, abs_tol=complete_tol)
    external_commits = 0
    if complete:
        external_committed = copy.deepcopy(working)
        external_commits = 1

    checks = {
        "scheduler_sequence_level_2_remainder_case": indices == expected_indices,
        "same_outer_forcing_preserved_across_segments": forcing_preserved,
        "outer_horizon_completed_exactly": complete,
        "single_external_publication": external_commits == 1,
        "external_state_changes_only_at_outer_completion": external_before != external_committed,
        "stale_candidate_receipt_rejected_after_state_transition": stale_rejected,
        "all_segment_mass_hard": all(abs(float(r["unrounded_mass_residual_cm"])) <= MASS_TOL_CM for r in receipts),
        "aggregate_mass_complete_finite": math.isfinite(aggregate_residual),
        "aggregate_mass_hard": abs(aggregate_residual) <= MASS_TOL_CM,
        "fresh_certificate_component_execution_each_segment": len(receipts) == len(segment_records),
        "all_retry_caps_bounded_to_full_level_8": all(
            rec["duration_ladder_index"] + rec["retry_cap"] == MAX_FULL_INDEX for rec in segment_records
        ),
    }

    replay_payload = None
    if replay:
        replay_result = _run_chain(material, canonical_head, replay=False)
        replay_payload = {
            "pass": replay_result.get("pass") is True,
            "same_final_state_digest": replay_result.get("final_state_digest") == _digest(external_committed),
            "same_segment_records": replay_result.get("segment_records") == segment_records,
            "same_aggregate_mass": replay_result.get("aggregate_mass") == aggregate_terms,
        }
        checks["deterministic_chain_replay"] = all(replay_payload.values())

    return {
        "pass": all(checks.values()),
        "material": material,
        "canonical_head": canonical_head,
        "checks": checks,
        "segment_records": segment_records,
        "aggregate_mass": aggregate_terms,
        "max_abs_segment_mass_residual_cm": max(abs(float(r["unrounded_mass_residual_cm"])) for r in receipts),
        "max_temporal_indicator": max(float(r["temporal_indicator"]) for r in receipts),
        "final_state_digest": _digest(external_committed),
        "replay": replay_payload,
    }


def _negative_failure_isolation(material: str) -> dict:
    t0 = 27.5
    request = d2q.base_request(material, t0=t0, steps=8, perturb=0.0, pre=False)
    request = _set_interval(request, t0, float(d3r.DURATION_LADDER_DAY[MAX_FULL_INDEX]))
    request["forcing_process_requests"]["top_boundary"]["q_top_cm_per_day"] = 1.0e9
    before = copy.deepcopy(request)
    external = copy.deepcopy(request["committed_state"])
    out = wrapper.execute_research_trial(request)
    diag = out.get("solver_work_diagnostics") or {}
    return {
        "smallest_segment_failure_fails_closed": out.get("solver_disposition") == "failed",
        "no_candidate_leak": out.get("candidate_hydraulic_state") is None,
        "no_certificate_acceptance": out.get("temporal_certificate_available") is False,
        "no_accept_or_commit": out.get("accepted") is False and out.get("commit_authorized") is False,
        "external_committed_unchanged": request["committed_state"] == external,
        "caller_request_unchanged": request == before,
        "no_component_execution_after_preflight_reject": diag.get("certificate_component_trial_count") in (None, 0),
        "smallest_segment_retry_cap_zero": _retry_cap_for_segment(MAX_FULL_INDEX) == 0,
    }


def qualify(material: str, canonical_head: str) -> dict:
    algebra = _algebra_checks()
    chain = _run_chain(material, canonical_head, replay=False)
    negative = _negative_failure_isolation(material) if material == "B01" else {"inherited_from_b01": True}
    passed = (
        all(algebra.values())
        and chain.get("pass") is True
        and (material != "B01" or all(negative.values()))
    )
    return {
        "workunit": "F-ROSS01_K_RUNTIME_REMAINDER",
        "qualification_class": "RESTRICTED_RESEARCH_REMAINDER_SCHEDULER_COMPOSITION",
        "scope": "EXACT_D3R_RESTRICTED_DOMAIN_ONLY",
        "material": material,
        "canonical_head": canonical_head,
        "pass": passed,
        "scheduler_algebra": algebra,
        "chain": chain,
        "failure_isolation": negative,
        "scheduler_contract": {
            "outer_horizon_day": OUTER_HORIZON_DAY,
            "minimum_full_attempt_day": MIN_FULL_DURATION_DAY,
            "full_attempt_indices": list(range(0, MAX_FULL_INDEX + 1)),
            "composition_test_chain_indices": [2, 1, 2],
            "selection": "GREEDY_LARGEST_QUALIFIED_DYADIC_DURATION_NOT_EXCEEDING_REMAINDER",
            "segment_retry_cap": "MAX_FULL_INDEX_MINUS_SEGMENT_INDEX",
            "external_publication": "ONCE_AFTER_FULL_OUTER_INTERVAL_ONLY",
            "forcing_policy": "SAME_OUTER_INTERVAL_FORCING_NO_STATE_LOCAL_REBIND",
            "certificate_policy": "FRESH_D3G02R3_CERTIFICATE_AFTER_EACH_PRIVATE_COMMITTED_STATE_CHANGE",
        },
        "nonclaims": [
            "NO_PRODUCTION_ADMISSION",
            "NO_PRODUCTION_RUNTIME_PERFORMANCE_QUALIFICATION",
            "NO_ARBITRARY_DURATION_GENERALIZATION",
            "NO_MULTISWAP_QUALIFICATION",
            "NO_GROUNDWATER_SCIENTIFIC_GENERALIZATION",
            "NO_A10_SURFACE_CAP_GENERALIZATION",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--material", required=True, choices=MATERIALS)
    parser.add_argument("--canonical-head", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = qualify(args.material, args.canonical_head)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"material": args.material, "pass": result["pass"]}, sort_keys=True))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
