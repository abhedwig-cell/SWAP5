#!/usr/bin/env python3
"""Executable VQ verifier harness for transactional and generic-time semantics.

This module qualifies the verifier only. It does not execute SWAP5 production
physics and cannot produce a B2 physics PASS. A future production adapter may
implement QualificationAdapter and reuse the same case functions after passing
the VQ-1d reference-seam/result admission gates.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping, Protocol

try:
    from tools.vq.b2_result_record import assess_record
except ModuleNotFoundError:  # direct script execution from tools/vq
    from b2_result_record import assess_record

TimeValue = int | float | str
State = Mapping[str, float]
Forcing = Mapping[str, float]

CASE_IDS = (
    "TX-ROLLBACK-01",
    "TX-COMMIT-01",
    "TX-ACCOUNT-01",
    "TX-RERUN-01",
    "TX-BC-REPLAY-01",
    "TX-WARM-01",
    "TIME-00",
    "TIME-06",
    "TIME-18",
    "TIME-36",
    "TIME-SPLIT",
)

HARNESS_SCOPE = "VERIFIER_HARNESS_ONLY"
B2_PHYSICS_STATUS = "NOT_EVALUATED"


@dataclass(frozen=True)
class QualificationRequest:
    case_id: str
    t0: TimeValue
    t1: TimeValue
    committed_state: State
    forcing: Forcing
    numerical_policy: str = "reference"
    warm_start_guess: State | None = None
    qualification_directives: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class AttemptTrace:
    trial_id: str
    accepted: bool
    physical_start_state: dict[str, float]
    forcing_signature: str
    provisional_endpoint_state: dict[str, float]
    contributes_to_committed_totals: bool
    numerical_start_guess: dict[str, float] | None


@dataclass(frozen=True)
class IntervalExecution:
    record: dict[str, Any]
    attempts: tuple[AttemptTrace, ...]
    committed_state_before: dict[str, float]
    committed_state_after: dict[str, float]


class QualificationAdapter(Protocol):
    """Minimal object seam needed by the VQ transaction/time verifier."""

    def run_interval(self, request: QualificationRequest) -> IntervalExecution:
        ...


def _stable_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def _fingerprint(value: object) -> str:
    return hashlib.sha256(_stable_json(value).encode("utf-8")).hexdigest()


def _state_copy(state: State) -> dict[str, float]:
    return {str(key): float(value) for key, value in state.items()}


def _state_equal(left: Mapping[str, float], right: Mapping[str, float]) -> bool:
    return dict(left) == dict(right)


def _external_sum(record: Mapping[str, Any]) -> float:
    return sum(
        float(term["signed_amount"])
        for term in record["mass_accounting"]["boundary_terms"]
        if term["classification"] == "external"
    )


def _result_value(record: Mapping[str, Any], result_id: str) -> float:
    for item in record["results"]:
        if item["result_id"] == result_id:
            return float(item["value"])
    raise KeyError(result_id)


def _endpoint_state(record: Mapping[str, Any]) -> dict[str, float]:
    values: dict[str, float] = {}
    for item in record["endpoint_state"]["variables"]:
        value = item["value"]
        if isinstance(value, list):
            raise ValueError("fixture endpoint helper expects scalar variables")
        values[str(item["variable_id"])] = float(value)
    return values


def _physical_signature(record: Mapping[str, Any]) -> str:
    """Compare committed physics while excluding route/provenance diagnostics."""
    payload = {
        "interval": record["interval"],
        "endpoint_variables": record["endpoint_state"]["variables"],
        "results": record["results"],
        "mass_accounting": {
            "interval": record["mass_accounting"]["interval"],
            "amount_unit": record["mass_accounting"]["amount_unit"],
            "area_basis": record["mass_accounting"]["area_basis"],
            "storage": record["mass_accounting"]["storage"],
            "boundary_terms": record["mass_accounting"]["boundary_terms"],
        },
    }
    return _fingerprint(payload)


def _record_assessment(record: Mapping[str, Any]) -> dict[str, Any]:
    """Reuse the VQ-1d3 canonical result validator without production I/O."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "result.json"
        path.write_text(json.dumps(record, allow_nan=True), encoding="utf-8")
        return assess_record(path)


def _case(
    case_id: str,
    checks: Mapping[str, bool],
    details: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "case_id": case_id,
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": dict(checks),
        "details": dict(details or {}),
    }


class SyntheticTransactionalAdapter:
    """Deterministic additive fixture used only to qualify the verifier.

    Faults deliberately inject one class of bad behavior so unit tests can
    demonstrate that the harness fails closed. This class is not a SWAP model.
    """

    IMPLEMENTATION_COMMIT = "f" * 40

    def __init__(self, faults: set[str] | frozenset[str] | None = None) -> None:
        self.faults = set(faults or ())
        self._call_count = 0

    def run_interval(self, request: QualificationRequest) -> IntervalExecution:
        self._call_count += 1
        committed_before = _state_copy(request.committed_state)
        if "storage" not in committed_before:
            raise ValueError("synthetic fixture requires committed_state['storage']")

        forcing = {str(key): float(value) for key, value in request.forcing.items()}
        forcing_amount = float(forcing.get("net_external", 0.0))
        reject_first = bool(request.qualification_directives.get("reject_first", False))
        trial_count = 2 if reject_first else 1
        warm_guess = (
            _state_copy(request.warm_start_guess)
            if request.warm_start_guess is not None
            else None
        )

        attempts: list[AttemptTrace] = []
        accepted_trial_forcing = forcing_amount
        for index in range(trial_count):
            trial_id = f"{request.case_id}-trial-{index + 1}"
            accepted = not (reject_first and index == 0)
            physical_start = dict(committed_before)

            if "rollback_mutates_committed" in self.faults and index > 0:
                physical_start["storage"] += float(
                    request.qualification_directives.get("rejected_mutation", 5.0)
                )
            if (
                "warm_start_changes_physical_start" in self.faults
                and warm_guess is not None
                and index == 0
            ):
                physical_start = dict(warm_guess)

            trial_forcing = dict(forcing)
            if "forcing_replay_drift" in self.faults and index > 0:
                trial_forcing["net_external"] = forcing_amount + 0.5
            trial_amount = float(trial_forcing.get("net_external", 0.0))
            if accepted:
                accepted_trial_forcing = trial_amount

            provisional = {
                "storage": float(physical_start["storage"]) + trial_amount
            }
            attempts.append(
                AttemptTrace(
                    trial_id=trial_id,
                    accepted=accepted,
                    physical_start_state=physical_start,
                    forcing_signature=_fingerprint(trial_forcing),
                    provisional_endpoint_state=provisional,
                    contributes_to_committed_totals=accepted,
                    numerical_start_guess=dict(warm_guess) if warm_guess is not None else None,
                )
            )

        committed_amount = accepted_trial_forcing
        if "double_counts_rejected" in self.faults and reject_first:
            committed_amount += forcing_amount
        if "rerun_nondeterministic" in self.faults:
            committed_amount += 0.001 * self._call_count

        duration: float | None = None
        if isinstance(request.t0, (int, float)) and isinstance(request.t1, (int, float)):
            duration = float(request.t1) - float(request.t0)
        if "split_noncomposable" in self.faults and duration is not None and duration > 6.0:
            committed_amount += 0.25

        committed_after = {
            "storage": float(committed_before["storage"]) + committed_amount
        }

        returned_t0: TimeValue = request.t0
        returned_t1: TimeValue = request.t1
        if (
            "calendar_snap" in self.faults
            and isinstance(request.t0, (int, float))
            and isinstance(request.t1, (int, float))
        ):
            returned_t0 = math.floor(float(request.t0) / 24.0) * 24.0
            returned_t1 = returned_t0 + (float(request.t1) - float(request.t0))

        retry_count = trial_count - 1
        commit_count = 2 if "duplicate_commit" in self.faults else 1
        rollback_count = retry_count
        accepted_trial_id = attempts[-1].trial_id

        record: dict[str, Any] = {
            "schema_version": 1,
            "contract_id": "SWAP5-B2-reference-result-record-v1",
            "interval": {
                "t0": returned_t0,
                "t1": returned_t1,
                "time_basis": "qualification-hours",
            },
            "endpoint_state": {
                "scope": "committed",
                "state_id": f"{request.case_id}:t1",
                "variables": [
                    {
                        "variable_id": "storage",
                        "value": committed_after["storage"],
                        "unit": "fixture-water-unit",
                    }
                ],
            },
            "results": [
                {
                    "result_id": "fixture.net_external",
                    "value": committed_amount,
                    "unit": "fixture-water-unit",
                    "basis": "fixture-column",
                    "aggregation": "interval_integral",
                }
            ],
            "mass_accounting": {
                "schema_version": 1,
                "component_id": "vq-synthetic-fixture",
                "column_or_tile_id": "fixture-column-1",
                "interval": {
                    "t0": returned_t0,
                    "t1": returned_t1,
                    "time_basis": "qualification-hours",
                },
                "amount_unit": "fixture-water-unit",
                "area_basis": "fixture-column",
                "accounting_scope": "committed",
                "trial_id": None,
                "accepted_trial_id": accepted_trial_id,
                "storage": {
                    "start_total": committed_before["storage"],
                    "end_total": committed_after["storage"],
                    "components": [
                        {
                            "term_id": "fixture.storage",
                            "start_amount": committed_before["storage"],
                            "end_amount": committed_after["storage"],
                        }
                    ],
                },
                "boundary_terms": [
                    {
                        "term_id": "fixture.net_external",
                        "interface_id": "fixture.boundary",
                        "signed_amount": committed_amount,
                        "classification": "external",
                    }
                ],
                "reported_residual": 0.0,
                "execution_class": "reference",
                "qualification_context": {
                    "reference_mode": True,
                    "tolerance_qualification_id": "vq-1e1-fixture-exact",
                    "source_identity": self.IMPLEMENTATION_COMMIT,
                    "case_id": request.case_id,
                },
                "diagnostics": {},
            },
            "transaction": {
                "accepted": True,
                "accepted_trial_id": accepted_trial_id,
                "trial_count": trial_count,
                "retry_count": retry_count,
                "commit_count": commit_count,
                "rollback_count": rollback_count,
                "rejected_trials_excluded_from_committed_totals": True,
            },
            "diagnostics": {
                "accepted": True,
                "execution_class": "reference",
                "retry_count": retry_count,
                "solver_iterations": max(1, 7 + retry_count * 2 - (2 if warm_guess else 0)),
                "solver_cost": float(max(1, 7 + retry_count * 2 - (2 if warm_guess else 0))),
                "fallback_used": False,
                "balance_residual": 0.0,
            },
            "provenance": {
                "implementation_commit": self.IMPLEMENTATION_COMMIT,
                "numerical_policy": request.numerical_policy,
                "result_contract_version": "v1",
                "case_id": request.case_id,
            },
        }

        return IntervalExecution(
            record=record,
            attempts=tuple(attempts),
            committed_state_before=committed_before,
            committed_state_after=committed_after,
        )


def case_tx_rollback(adapter: QualificationAdapter) -> dict[str, Any]:
    request = QualificationRequest(
        case_id="TX-ROLLBACK-01",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
        qualification_directives={"reject_first": True, "rejected_mutation": 5.0},
    )
    execution = adapter.run_interval(request)
    assessment = _record_assessment(execution.record)
    starts_preserved = all(
        _state_equal(attempt.physical_start_state, request.committed_state)
        for attempt in execution.attempts
    )
    checks = {
        "canonical_result_valid": assessment["valid_reference_result"],
        "two_trials": len(execution.attempts) == 2,
        "first_trial_rejected": len(execution.attempts) >= 1 and not execution.attempts[0].accepted,
        "second_trial_accepted": len(execution.attempts) >= 2 and execution.attempts[1].accepted,
        "rejected_trial_not_committed": len(execution.attempts) >= 1
        and not execution.attempts[0].contributes_to_committed_totals,
        "retry_physical_start_is_committed_state": starts_preserved,
        "committed_input_unchanged": _state_equal(execution.committed_state_before, request.committed_state),
        "single_commit": execution.record["transaction"]["commit_count"] == 1,
        "one_rollback": execution.record["transaction"]["rollback_count"] == 1,
        "accepted_endpoint_from_committed_start": execution.committed_state_after == {"storage": 11.0},
    }
    return _case(request.case_id, checks)


def case_tx_commit(adapter: QualificationAdapter) -> dict[str, Any]:
    request = QualificationRequest(
        case_id="TX-COMMIT-01",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
    )
    execution = adapter.run_interval(request)
    assessment = _record_assessment(execution.record)
    checks = {
        "canonical_result_valid": assessment["valid_reference_result"],
        "one_trial": len(execution.attempts) == 1,
        "trial_accepted": len(execution.attempts) == 1 and execution.attempts[0].accepted,
        "single_commit": execution.record["transaction"]["commit_count"] == 1,
        "zero_rollbacks": execution.record["transaction"]["rollback_count"] == 0,
        "committed_endpoint_matches_record": _endpoint_state(execution.record) == execution.committed_state_after,
        "committed_endpoint_expected": execution.committed_state_after == {"storage": 11.0},
    }
    return _case(request.case_id, checks)


def case_tx_account(adapter: QualificationAdapter) -> dict[str, Any]:
    request = QualificationRequest(
        case_id="TX-ACCOUNT-01",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
        qualification_directives={"reject_first": True},
    )
    execution = adapter.run_interval(request)
    assessment = _record_assessment(execution.record)
    storage = execution.record["mass_accounting"]["storage"]
    checks = {
        "canonical_result_valid": assessment["valid_reference_result"],
        "rejected_trial_present": len(execution.attempts) == 2 and not execution.attempts[0].accepted,
        "committed_external_exactly_once": _external_sum(execution.record) == 1.0,
        "committed_result_exactly_once": _result_value(execution.record, "fixture.net_external") == 1.0,
        "storage_delta_exactly_once": float(storage["end_total"]) - float(storage["start_total"]) == 1.0,
        "rejected_trials_declared_excluded": execution.record["transaction"][
            "rejected_trials_excluded_from_committed_totals"
        ]
        is True,
    }
    return _case(request.case_id, checks)


def case_tx_rerun(adapter: QualificationAdapter) -> dict[str, Any]:
    request = QualificationRequest(
        case_id="TX-RERUN-01",
        t0=3.0,
        t1=9.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.25},
    )
    first = adapter.run_interval(request)
    second = adapter.run_interval(request)
    first_assessment = _record_assessment(first.record)
    second_assessment = _record_assessment(second.record)
    checks = {
        "first_result_valid": first_assessment["valid_reference_result"],
        "second_result_valid": second_assessment["valid_reference_result"],
        "same_physical_result": _physical_signature(first.record) == _physical_signature(second.record),
        "same_committed_endpoint": first.committed_state_after == second.committed_state_after,
        "same_physical_start": all(
            _state_equal(attempt.physical_start_state, request.committed_state)
            for execution in (first, second)
            for attempt in execution.attempts
        ),
    }
    return _case(request.case_id, checks)


def case_tx_bc_replay(adapter: QualificationAdapter) -> dict[str, Any]:
    request = QualificationRequest(
        case_id="TX-BC-REPLAY-01",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
        qualification_directives={"reject_first": True},
    )
    execution = adapter.run_interval(request)
    assessment = _record_assessment(execution.record)
    expected = _fingerprint({"net_external": 1.0})
    checks = {
        "canonical_result_valid": assessment["valid_reference_result"],
        "retry_present": len(execution.attempts) == 2,
        "forcing_signature_replayed": all(
            attempt.forcing_signature == expected for attempt in execution.attempts
        ),
        "accepted_amount_matches_original_forcing": _external_sum(execution.record) == 1.0,
    }
    return _case(request.case_id, checks)


def case_tx_warm(adapter: QualificationAdapter) -> dict[str, Any]:
    cold_request = QualificationRequest(
        case_id="TX-WARM-01",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
    )
    cold = adapter.run_interval(cold_request)
    warm_guess = {"storage": 99.0}
    warm_request = QualificationRequest(
        case_id="TX-WARM-01",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
        warm_start_guess=warm_guess,
    )
    warm = adapter.run_interval(warm_request)
    cold_assessment = _record_assessment(cold.record)
    warm_assessment = _record_assessment(warm.record)
    checks = {
        "cold_result_valid": cold_assessment["valid_reference_result"],
        "warm_result_valid": warm_assessment["valid_reference_result"],
        "warm_guess_visible_in_trace": all(
            attempt.numerical_start_guess == warm_guess for attempt in warm.attempts
        ),
        "warm_physical_start_is_committed_state": all(
            _state_equal(attempt.physical_start_state, warm_request.committed_state)
            for attempt in warm.attempts
        ),
        "warm_and_cold_same_physics": _physical_signature(cold.record) == _physical_signature(warm.record),
        "warm_and_cold_same_committed_endpoint": cold.committed_state_after == warm.committed_state_after,
    }
    return _case(cold_request.case_id, checks)


def case_time(adapter: QualificationAdapter, case_id: str, start: float) -> dict[str, Any]:
    request = QualificationRequest(
        case_id=case_id,
        t0=start,
        t1=start + 6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 0.75},
    )
    execution = adapter.run_interval(request)
    assessment = _record_assessment(execution.record)
    interval = execution.record["interval"]
    mass_interval = execution.record["mass_accounting"]["interval"]
    checks = {
        "canonical_result_valid": assessment["valid_reference_result"],
        "returned_t0_exact": interval["t0"] == request.t0,
        "returned_t1_exact": interval["t1"] == request.t1,
        "mass_t0_exact": mass_interval["t0"] == request.t0,
        "mass_t1_exact": mass_interval["t1"] == request.t1,
        "physical_start_is_committed_state": all(
            _state_equal(attempt.physical_start_state, request.committed_state)
            for attempt in execution.attempts
        ),
    }
    return _case(case_id, checks)


def case_time_split(adapter: QualificationAdapter) -> dict[str, Any]:
    direct_request = QualificationRequest(
        case_id="TIME-SPLIT",
        t0=0.0,
        t1=12.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 2.0},
    )
    first_request = QualificationRequest(
        case_id="TIME-SPLIT-A",
        t0=0.0,
        t1=6.0,
        committed_state={"storage": 10.0},
        forcing={"net_external": 1.0},
    )
    direct = adapter.run_interval(direct_request)
    first = adapter.run_interval(first_request)
    second_request = QualificationRequest(
        case_id="TIME-SPLIT-B",
        t0=6.0,
        t1=12.0,
        committed_state=first.committed_state_after,
        forcing={"net_external": 1.0},
    )
    second = adapter.run_interval(second_request)

    assessments = [_record_assessment(item.record) for item in (direct, first, second)]
    direct_external = _external_sum(direct.record)
    split_external = _external_sum(first.record) + _external_sum(second.record)
    direct_result = _result_value(direct.record, "fixture.net_external")
    split_result = _result_value(first.record, "fixture.net_external") + _result_value(
        second.record, "fixture.net_external"
    )
    checks = {
        "all_results_valid": all(item["valid_reference_result"] for item in assessments),
        "first_interval_exact": first.record["interval"]["t0"] == 0.0
        and first.record["interval"]["t1"] == 6.0,
        "second_interval_exact": second.record["interval"]["t0"] == 6.0
        and second.record["interval"]["t1"] == 12.0,
        "split_state_continuity": second.committed_state_before == first.committed_state_after,
        "final_endpoint_exact_fixture_equivalence": second.committed_state_after
        == direct.committed_state_after,
        "external_amount_exact_fixture_equivalence": split_external == direct_external,
        "result_amount_exact_fixture_equivalence": split_result == direct_result,
    }
    details = {
        "comparison_tolerance": 0.0,
        "comparison_scope": "synthetic additive fixture only",
        "production_tolerance_qualified": False,
    }
    return _case("TIME-SPLIT", checks, details)


def run_fixture_suite(faults: set[str] | frozenset[str] | None = None) -> dict[str, Any]:
    """Run all named verifier cases against isolated synthetic adapters."""
    faults = set(faults or ())

    def adapter() -> SyntheticTransactionalAdapter:
        return SyntheticTransactionalAdapter(faults)

    cases = [
        case_tx_rollback(adapter()),
        case_tx_commit(adapter()),
        case_tx_account(adapter()),
        case_tx_rerun(adapter()),
        case_tx_bc_replay(adapter()),
        case_tx_warm(adapter()),
        case_time(adapter(), "TIME-00", 0.0),
        case_time(adapter(), "TIME-06", 6.0),
        case_time(adapter(), "TIME-18", 18.0),
        case_time(adapter(), "TIME-36", 36.0),
        case_time_split(adapter()),
    ]
    by_id = {item["case_id"]: item for item in cases}
    missing = [case_id for case_id in CASE_IDS if case_id not in by_id]
    all_pass = not missing and all(by_id[case_id]["status"] == "PASS" for case_id in CASE_IDS)
    return {
        "schema_version": 1,
        "workstream": "VQ",
        "slice": "VQ-1e1",
        "qualification_scope": HARNESS_SCOPE,
        "harness_status": "PASS" if all_pass else "FAIL",
        "b2_physics_status": B2_PHYSICS_STATUS,
        "production_physics_executed": False,
        "production_mass_tolerance_qualified": False,
        "case_count": len(CASE_IDS),
        "cases": cases,
        "missing_cases": missing,
    }


def evidence_projection(report: Mapping[str, Any]) -> dict[str, Any]:
    case_status = {
        str(item["case_id"]): str(item["status"])
        for item in report.get("cases", [])
        if isinstance(item, Mapping) and "case_id" in item and "status" in item
    }
    return {
        "schema_version": 1,
        "workstream": "VQ",
        "slice": "VQ-1e1",
        "qualification_scope": report.get("qualification_scope"),
        "harness_status": report.get("harness_status"),
        "b2_physics_status": report.get("b2_physics_status"),
        "production_physics_executed": report.get("production_physics_executed"),
        "production_mass_tolerance_qualified": report.get("production_mass_tolerance_qualified"),
        "case_count": report.get("case_count"),
        "case_status": {case_id: case_status.get(case_id) for case_id in CASE_IDS},
    }


def check_stored_evidence(report: Mapping[str, Any], evidence_path: Path) -> dict[str, Any]:
    stored = json.loads(evidence_path.read_text(encoding="utf-8"))
    expected = evidence_projection(report)
    mismatches = {
        key: {"expected": expected.get(key), "stored": stored.get(key)}
        for key in expected
        if stored.get(key) != expected.get(key)
    }
    return {
        "consistent": not mismatches,
        "mismatches": mismatches,
        "expected_projection": expected,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Qualify the VQ transaction/generic-time verifier harness."
    )
    parser.add_argument(
        "--fixture-suite",
        action="store_true",
        help="Run the deterministic synthetic verifier-qualification suite.",
    )
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()

    if not args.fixture_suite:
        parser.error("VQ-1e1 currently supports only --fixture-suite; no B2 production adapter is admitted")

    report = run_fixture_suite()
    if args.evidence is not None:
        report["stored_evidence"] = {
            "path": str(args.evidence),
            **check_stored_evidence(report, args.evidence),
        }

    print(json.dumps(report, indent=2, sort_keys=True))

    if report["harness_status"] != "PASS":
        return 2
    if args.evidence is not None and not report["stored_evidence"]["consistent"]:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
