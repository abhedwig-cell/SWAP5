#!/usr/bin/env python3
"""F-PE01 qualification-only measurement and contract harness.

This tool never changes production source. The ``instrument`` command edits only
an ephemeral CI checkout of the existing F-MR05 test program so that the already
qualified serialized runtime emits per-column cost observations for logical
column-count cases 1/2/8/17/31/32. The F-MR05 gate still source-binds all
production blobs.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COUNTS = (1, 2, 8, 17, 31, 32)
HARD_MASS_GATE = 1.0e-12
MARKER = "! F-PE01 EPHEMERAL REFERENCE COST PROBE"
COST_RE = re.compile(
    r"FPE01_COST\s+n=(\d+)\s+column_id=(\d+)\s+attempts=(\d+)\s+"
    r"retries=(\d+)\s+newton=(\d+)\s+mass_residual=\s*([+\-0-9.Ee]+)"
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def fail(message: str) -> None:
    raise SystemExit(f"FPE01_FAIL {message}")


def nearest_rank(values: list[int], p: float) -> int:
    if not values:
        fail("nearest_rank on empty sample")
    ordered = sorted(values)
    rank = max(1, math.ceil(p * len(ordered)))
    return ordered[rank - 1]


def stats(values: list[int]) -> dict:
    return {
        "count": len(values),
        "median_nearest_rank": nearest_rank(values, 0.50),
        "p95_nearest_rank": nearest_rank(values, 0.95),
        "p99_nearest_rank": nearest_rank(values, 0.99),
        "maximum": max(values),
        "sum": sum(values),
    }


def instrument(test_path: Path) -> None:
    text = test_path.read_text(encoding="utf-8")
    if MARKER in text:
        fail(f"probe already instrumented: {test_path}")

    insertion_anchor = (
        "  call execute_case(nfull, 8, .true., 0, .false., trial_results, trial_diag, "
        "trial_aggregate, trial_states, dispatch_status)"
    )
    if insertion_anchor not in text:
        fail("F-MR05 matrix insertion anchor not found")

    matrix_probe = f"""  {MARKER}\n  do i = 1, nbatch\n    call execute_case(batch_sizes(i), batch_sizes(i), .false., 0, .false., trial_results, trial_diag, trial_aggregate, &\n         trial_states, dispatch_status)\n    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'F-PE01 count-matrix dispatch status')\n    call validate_success_case(batch_sizes(i), batch_sizes(i), trial_results, trial_diag, trial_aggregate, trial_states)\n    call fpe01_emit_cost_records(batch_sizes(i), trial_results, trial_diag)\n  end do\n\n"""
    text = text.replace(insertion_anchor, matrix_probe + insertion_anchor, 1)

    contains_anchor = "contains\n\n"
    if contains_anchor not in text:
        fail("F-MR05 contains anchor not found")

    helper = """  subroutine fpe01_emit_cost_records(n, results, diagnostics)\n    integer, intent(in) :: n\n    type(fmr_serialized_column_result_t), intent(in) :: results(:)\n    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)\n    integer :: j\n\n    do j = 1, size(results)\n      write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A,ES26.17E3)') &\n           'FPE01_COST n=', n, ' column_id=', results(j)%column_id, ' attempts=', diagnostics(j)%attempts, &\n           ' retries=', diagnostics(j)%retries, ' newton=', results(j)%solver_iterations, &\n           ' mass_residual=', results(j)%mass%residual\n    end do\n  end subroutine fpe01_emit_cost_records\n\n"""
    text = text.replace(contains_anchor, contains_anchor + helper, 1)
    test_path.write_text(text, encoding="utf-8")
    print(f"FPE01_INSTRUMENTED {test_path}")


def summarize(log_path: Path, output_path: Path) -> None:
    records: dict[int, list[dict]] = {n: [] for n in COUNTS}
    for match in COST_RE.finditer(log_path.read_text(encoding="utf-8", errors="replace")):
        n = int(match.group(1))
        record = {
            "column_id": int(match.group(2)),
            "attempts": int(match.group(3)),
            "retries": int(match.group(4)),
            "newton_iterations": int(match.group(5)),
            "mass_residual": float(match.group(6)),
        }
        if n in records:
            records[n].append(record)

    for n in COUNTS:
        if len(records[n]) != n:
            fail(f"logical_count={n} expected {n} records, found {len(records[n])}")
        ids = [r["column_id"] for r in records[n]]
        if len(ids) != len(set(ids)):
            fail(f"logical_count={n} duplicate column ids")
        for record in records[n]:
            residual = record["mass_residual"]
            if not math.isfinite(residual) or abs(residual) > HARD_MASS_GATE:
                fail(f"logical_count={n} hard mass gate failed: {residual}")

    matrix = []
    all_records = []
    for n in COUNTS:
        sample = records[n]
        all_records.extend(sample)
        matrix.append({
            "logical_columns": n,
            "physical_worker_count": 1,
            "attempts": stats([r["attempts"] for r in sample]),
            "retries": stats([r["retries"] for r in sample]),
            "newton_iterations": stats([r["newton_iterations"] for r in sample]),
            "maximum_absolute_mass_residual": max(abs(r["mass_residual"]) for r in sample),
            "records": sample,
        })

    payload = {
        "schema_version": 1,
        "workstream": "F-PE",
        "work_unit": "F-PE01",
        "measurement_kind": "REAL_PHYSICS_SERIALIZED_REFERENCE",
        "reference_source_commit": "c28e7a2810b4a3678c577335a6a3086b173eb976",
        "qualified_scope": "EXACT_FVQ14_RESTRICTED_PROFILE_ONLY",
        "generic_interval": [1000.125, 1000.625],
        "physical_execution": "SERIALIZED",
        "parallel_real_physics_admitted": False,
        "statistics_rule": "nearest-rank for median, p95 and p99",
        "hard_mass_gate": HARD_MASS_GATE,
        "matrix": matrix,
        "overall": {
            "sample_columns": len(all_records),
            "attempts": stats([r["attempts"] for r in all_records]),
            "retries": stats([r["retries"] for r in all_records]),
            "newton_iterations": stats([r["newton_iterations"] for r in all_records]),
            "maximum_absolute_mass_residual": max(abs(r["mass_residual"]) for r in all_records),
        },
        "unmeasured_on_current_runtime_surface": [
            "accepted_substeps",
            "jacobian_assemblies",
            "linear_solves",
            "constitutive_evaluations",
            "minimum_step_hits",
        ],
        "claim_limit": "This is reference measurement evidence, not a production performance threshold or parallel-physics admission.",
    }
    write_json(output_path, payload)
    print(json.dumps(payload, indent=2, sort_keys=True))
    print(f"FPE01_REFERENCE_SUMMARY_PASS output={output_path}")


def synthetic(output_path: Path) -> None:
    fmq = load_json(ROOT / "integration/f-mq/F-MQ23_QUALIFICATION_EVIDENCE.json")
    generic = fmq["generic_runtime_infrastructure_results"]
    bytes_obs = generic["memory_observation_bytes"]
    difficult = generic["difficult_tail_observation"]

    easy = int(difficult["max_easy_synthetic_cost"])
    hard = int(difficult["synthetic_difficult_cost"])
    retries = int(difficult["diagnosed_retries"])
    if easy <= 0 or hard < easy:
        fail("invalid source-bound synthetic difficult-tail observation")

    per_column_projection = (
        int(bytes_obs["logical_runtime_metadata_per_column"])
        + int(bytes_obs["deterministic_committed_state_per_column"])
    )
    scales = []
    for n in (1_000, 10_000, 100_000):
        scales.append({
            "logical_columns": n,
            "projected_runtime_metadata_plus_deterministic_state_bytes": n * per_column_projection,
            "full_real_physics_solves_executed": 0,
            "projection_status": "COMPILER_ABI_SPECIFIC_EVIDENCE_PROJECTION_NOT_MEMORY_CONTRACT",
        })

    costs = [easy] * 31 + [hard]
    payload = {
        "schema_version": 1,
        "workstream": "F-PE",
        "work_unit": "F-PE01",
        "measurement_kind": "SYNTHETIC_RUNTIME_INFRASTRUCTURE",
        "source_evidence": "integration/f-mq/F-MQ23_QUALIFICATION_EVIDENCE.json",
        "source_evidence_scope": generic["scope_note"],
        "difficult_tail": {
            "structure": "31_easy_plus_1_difficult",
            "easy_cost": easy,
            "difficult_cost": hard,
            "diagnosed_retries": retries,
            "amplification_difficult_over_max_easy": hard / easy,
            "cost_distribution": {
                "median_nearest_rank": nearest_rank(costs, 0.50),
                "p95_nearest_rank": nearest_rank(costs, 0.95),
                "p99_nearest_rank": nearest_rank(costs, 0.99),
                "maximum": max(costs),
            },
            "physical_difficult_column_claim": False,
            "production_bounded_cost_claim": False,
        },
        "memory_observation_bytes": bytes_obs,
        "synthetic_scale": scales,
        "parallel_physical_admission": False,
        "claim_limit": "No 1k/10k/100k real-physics solve is performed. Scale results exercise arithmetic and evidence contracts only.",
    }
    write_json(output_path, payload)
    print(json.dumps(payload, indent=2, sort_keys=True))
    print(f"FPE01_SYNTHETIC_SUMMARY_PASS output={output_path}")


def validate_contracts() -> None:
    dep = load_json(ROOT / "integration/f-pe/F-PE01_DEPENDENCIES.json")
    exe = load_json(ROOT / "integration/f-pe/F-PE01_EXECUTION_CLASS_CONTRACT.json")
    cost = load_json(ROOT / "integration/f-pe/F-PE01_COST_DIAGNOSTICS_CONTRACT.json")
    fmq_status = load_json(ROOT / "integration/f-mq/F-MQ23_STATUS.json")
    fmq_evidence = load_json(ROOT / "integration/f-mq/F-MQ23_QUALIFICATION_EVIDENCE.json")

    expected_source = "c28e7a2810b4a3678c577335a6a3086b173eb976"
    if dep["reference_authority"]["candidate_source_commit"] != expected_source:
        fail("dependency reference source mismatch")
    if fmq_status["candidate_source_commit"] != expected_source:
        fail("F-MQ23 source mismatch")
    if fmq_status["decision"] != "QUALIFIED_RESTRICTED_SERIALIZED_REAL_PHYSICS_MULTISWAP_RUNTIME":
        fail("F-MQ23 reference is not qualified")
    if fmq_status["parallel_real_physics_admitted"]:
        fail("parallel real physics unexpectedly admitted")
    if fmq_evidence["real_physics_results"]["physical_worker_count"] != 1:
        fail("reference physical worker count is not one")
    if not fmq_evidence["real_physics_results"]["authoritative_mass_complete"]:
        fail("reference authoritative mass incomplete")
    if fmq_evidence["real_physics_results"]["missing_mass_contribution_mask"] != 0:
        fail("reference missing mass contribution mask nonzero")

    classes = exe["classes"]
    if classes["REFERENCE"]["admission"] != "ADMITTED_EXISTING_QUALIFIED_ROUTE":
        fail("REFERENCE admission changed")
    for name in ("BALANCED", "THROUGHPUT", "FALLBACK"):
        if classes[name]["admission"] != "DEFINED_NOT_ADMITTED":
            fail(f"{name} must remain DEFINED_NOT_ADMITTED")
        if classes[name]["request_behavior_before_admission"] != "FAIL_CLOSED":
            fail(f"{name} must fail closed before admission")
        if classes[name]["physics_delta_allowed"]:
            fail(f"{name} may not alter physics")
    if exe["global_invariants"]["mass_gate"] != "HARD":
        fail("execution-class mass gate is not hard")
    if cost["aggregation"]["no_production_thresholds_in_fpe01"] is not True:
        fail("F-PE01 threshold policy weakened")
    print("FPE01_CONTRACT_GATE PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_instrument = sub.add_parser("instrument")
    p_instrument.add_argument("test_path", type=Path)

    p_summary = sub.add_parser("summarize")
    p_summary.add_argument("log_path", type=Path)
    p_summary.add_argument("--output", required=True, type=Path)

    p_synthetic = sub.add_parser("synthetic")
    p_synthetic.add_argument("--output", required=True, type=Path)

    sub.add_parser("validate-contracts")

    args = parser.parse_args()
    if args.cmd == "instrument":
        instrument(args.test_path)
    elif args.cmd == "summarize":
        summarize(args.log_path, args.output)
    elif args.cmd == "synthetic":
        synthetic(args.output)
    elif args.cmd == "validate-contracts":
        validate_contracts()
    else:
        fail(f"unknown command {args.cmd}")


if __name__ == "__main__":
    main()
