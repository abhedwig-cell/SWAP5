#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"

FCI23_RECORD = ROOT / "integration/f-ci/F-CI23_FCI04_MASS_PROVENANCE.json"
FKT08_HEAD = "510d1f29d40225c68f3a8d3e789071279941e87b"
FKT08_STATUS_PATH = "integration/f-kt/F-KT08_STATUS.json"
FKT08_STATUS_BLOB = "157fd9f50e291f37439cb374ae20d875605580db"
FKT08_EVIDENCE_PATH = "integration/f-kt/F-KT08_QUALIFICATION_EVIDENCE.json"
FKT08_EVIDENCE_BLOB = "5b5f6e0fe790f5290798f9f64030c33ccae896f2"
FKT08_RUNTIME_BLOB = "f2cae79d533343db818c11e0b61b605ac5f6739d"
FMR04_QUALIFIED_SOURCE = "11eb34ea3afe8f5dda0515c28d7e08428dd2e272"
FMR04_EVIDENCE_PATH = "integration/f-mr/F-MR04_QUALIFICATION_EVIDENCE.json"
FMR04_EVIDENCE_BLOB = "50e37e6f5666b59e27fb7aa0dde51ca060c873e2"
FMR04_STATUS_PATH = "integration/f-mr/F-MR04_STATUS.json"
FMR04_STATUS_BLOB = "9d073bf239a94fd381b10f1a4a745d6c17991cdf"
FCI19_CANDIDATE_A = "4a792636ef73d25c671c5e0953cefd11978cd0ec"
CURRENT_ADMITTED_RUNTIME_BLOB = "55f3d271aa6200a994fd0144d6fce0701c918a74"
RUNTIME_PATH = "src/runtime/mod_canonical_interval_runtime.f90"


def git_blob(revision: str, path: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", f"{revision}:{path}"], text=True
    ).strip()


def git_show_text(revision: str, path: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{revision}:{path}"], text=True
    )


def git_show_json(revision: str, path: str) -> dict:
    return json.loads(git_show_text(revision, path))


def subroutine_block(source: str, name: str) -> str:
    start_token = f"  subroutine {name}"
    end_token = f"  end subroutine {name}"
    start = source.find(start_token)
    end = source.find(end_token)
    if start < 0 or end < 0:
        return ""
    end += len(end_token)
    return source[start:end]


def qualified_mass_forward_evolution(runtime: str) -> tuple[bool, dict[str, bool]]:
    checks: dict[str, bool] = {}
    if not FCI23_RECORD.is_file():
        return False, {"fci23_mass_provenance_record_present": False}

    try:
        record = json.loads(FCI23_RECORD.read_text(encoding="utf-8"))
        fkt08_status = git_show_json(FKT08_HEAD, FKT08_STATUS_PATH)
        fkt08_evidence = git_show_json(FKT08_HEAD, FKT08_EVIDENCE_PATH)
        fmr04_evidence = git_show_json(FCI19_CANDIDATE_A, FMR04_EVIDENCE_PATH)
        fmr04_status = git_show_json(FCI19_CANDIDATE_A, FMR04_STATUS_PATH)
        fkt08_runtime = git_show_text(FKT08_HEAD, RUNTIME_PATH)
        fmr04_runtime = git_show_text(FMR04_QUALIFIED_SOURCE, RUNTIME_PATH)
    except (subprocess.CalledProcessError, json.JSONDecodeError, OSError):
        return False, {"fci23_mass_authority_readable": False}

    authority = record.get("qualified_forward_authority", {})
    required = record.get("required_semantics", {})
    executable = record.get("F_MR04_executable_confirmation", {})
    later = record.get("later_runtime_evolution", {})
    fkt08_contract = fkt08_evidence.get("canonical_mass_contract", {})
    fkt08_complete = fkt08_evidence.get("completeness_semantics", {})
    fkt08_tx = fkt08_evidence.get("transaction_semantics", {})
    fkt08_regression = fkt08_evidence.get("regression_results", {})
    fmr04_gates = fmr04_evidence.get("gates", {})
    fmr04_mass = fmr04_evidence.get("mass", {})

    try:
        checks["fkt08_status_blob_pinned"] = git_blob(FKT08_HEAD, FKT08_STATUS_PATH) == FKT08_STATUS_BLOB
        checks["fkt08_evidence_blob_pinned"] = git_blob(FKT08_HEAD, FKT08_EVIDENCE_PATH) == FKT08_EVIDENCE_BLOB
        checks["fkt08_runtime_blob_pinned"] = git_blob(FKT08_HEAD, RUNTIME_PATH) == FKT08_RUNTIME_BLOB
        checks["fmr04_evidence_blob_pinned"] = git_blob(FCI19_CANDIDATE_A, FMR04_EVIDENCE_PATH) == FMR04_EVIDENCE_BLOB
        checks["fmr04_status_blob_pinned"] = git_blob(FCI19_CANDIDATE_A, FMR04_STATUS_PATH) == FMR04_STATUS_BLOB
        checks["fmr04_runtime_is_exact_fkt08_mass_runtime"] = git_blob(FMR04_QUALIFIED_SOURCE, RUNTIME_PATH) == FKT08_RUNTIME_BLOB
        checks["current_runtime_blob_is_admitted"] = git_blob("HEAD", RUNTIME_PATH) == CURRENT_ADMITTED_RUNTIME_BLOB
        checks["fci19_candidate_runtime_blob_is_admitted"] = git_blob(FCI19_CANDIDATE_A, RUNTIME_PATH) == CURRENT_ADMITTED_RUNTIME_BLOB
    except subprocess.CalledProcessError:
        return False, {"fci23_mass_git_objects_resolvable": False}

    checks["record_identity"] = (
        record.get("schema_version") == 1
        and record.get("work_unit") == "F-CI23"
        and record.get("historical_gate") == "F-CI04"
        and record.get("decision")
        == "REPLACE_OBSOLETE_NEGATIVE_LITERAL_WITH_PINNED_QUALIFIED_FAIL_CLOSED_MASS_PROVENANCE_CHECK"
    )
    checks["record_authority_pins"] = (
        authority.get("F_KT08_final_head") == FKT08_HEAD
        and authority.get("F_KT08_final_head_workflow_run") == 34187095449
        and authority.get("F_KT08_final_head_workflow_conclusion") == "success"
        and authority.get("F_KT08_status_blob") == FKT08_STATUS_BLOB
        and authority.get("F_KT08_qualification_evidence_blob") == FKT08_EVIDENCE_BLOB
        and authority.get("F_KT08_runtime_blob") == FKT08_RUNTIME_BLOB
        and authority.get("F_MR04_qualified_source_head") == FMR04_QUALIFIED_SOURCE
        and authority.get("F_MR04_qualification_evidence_blob") == FMR04_EVIDENCE_BLOB
        and authority.get("F_MR04_status_blob") == FMR04_STATUS_BLOB
        and authority.get("current_admitted_runtime_blob") == CURRENT_ADMITTED_RUNTIME_BLOB
        and authority.get("F_CI19_candidate_A_head") == FCI19_CANDIDATE_A
    )
    checks["fkt08_formally_qualified"] = (
        fkt08_status.get("work_unit") == "F-KT08"
        and fkt08_status.get("IMPLEMENTED") is True
        and fkt08_status.get("PERSISTED") is True
        and fkt08_status.get("TESTED") is True
        and fkt08_status.get("QUALIFIED") is True
        and fkt08_status.get("qualification_workflow_conclusion") == "success"
        and fkt08_status.get("authoritative_full_interval_mass_accounting_qualified") is True
        and fkt08_status.get("completeness_fail_closed") is True
        and fkt08_status.get("accepted_only_accounting") is True
        and fkt08_status.get("retry_double_counting") is False
        and fkt08_status.get("rollback_mutates_committed_accounting") is False
        and fkt08_status.get("mass_conservation_disable_switch_added") is False
    )
    checks["fkt08_mass_semantics_fail_closed"] = (
        fkt08_evidence.get("result") == "QUALIFIED_BASIS"
        and fkt08_evidence.get("authoritative_full_interval_mass_accounting_qualified") is True
        and fkt08_contract.get("mass_conservation_disable_switch") is False
        and fkt08_complete.get("default") == "fail-closed"
        and fkt08_complete.get("active_missing_is_not_zero") is True
        and fkt08_tx.get("rejected_trials_committed") is False
        and fkt08_tx.get("retry_double_counting") is False
        and fkt08_tx.get("rollback_mutates_committed_accounting") is False
        and fkt08_regression.get("historical_F_CI03_F_CI04_exact_head_replay") == "PASS"
    )
    checks["fmr04_executable_mass_confirmation"] = (
        fmr04_evidence.get("qualification") == "QUALIFIED_SERIALIZED_PHYSICAL_RUNTIME_CANDIDATE_READY_FOR_FVQ"
        and fmr04_evidence.get("consumed_dependencies", {}).get("F-KT08") == FKT08_HEAD
        and fmr04_evidence.get("workflow", {}).get("run_id") == 34187700639
        and fmr04_evidence.get("workflow", {}).get("conclusion") == "SUCCESS"
        and fmr04_gates.get("authoritative_full_interval_mass_complete") == "PASS"
        and fmr04_gates.get("authoritative_missing_mask_zero") == "PASS"
        and fmr04_gates.get("authoritative_mass_residual") == "PASS_ZERO"
        and fmr04_mass.get("complete") is True
        and fmr04_mass.get("missing_contribution_mask") == 0
        and fmr04_mass.get("residual") == 0.0
        and fmr04_status.get("QUALIFIED") is True
        and fmr04_status.get("consumed_fkt08") == FKT08_HEAD
    )
    checks["record_required_semantics_are_hard"] = (
        required.get("accepted_only_accounting") is True
        and required.get("rejected_trials_committed") is False
        and required.get("retry_double_counting") is False
        and required.get("rollback_mutates_committed_accounting") is False
        and required.get("mass_conservation_disable_switch") is False
        and required.get("completeness_fail_closed") is True
        and required.get("active_missing_contribution_blocks_complete") is True
        and required.get("finite_terms_required") is True
        and required.get("accepted_transaction_required") is True
        and required.get("zero_missing_contribution_mask_required") is True
        and required.get("full_requested_interval_completion_required") is True
        and required.get("generic_time") is True
        and required.get("physics_changed_by_F_KT08") is False
        and required.get("numerical_policy_changed_by_F_KT08") is False
    )
    checks["record_fmr04_confirmation_pinned"] = (
        executable.get("consumed_F_KT08") == FKT08_HEAD
        and executable.get("workflow_run") == 34187700639
        and executable.get("conclusion") == "SUCCESS"
        and executable.get("authoritative_full_interval_mass_complete") == "PASS"
        and executable.get("authoritative_missing_mask_zero") == "PASS"
        and executable.get("authoritative_mass_residual") == "PASS_ZERO"
    )
    checks["later_evolution_declares_mass_core_unchanged"] = (
        later.get("only_runtime_change_after_F_MR04_before_F_CI19_candidate_A")
        == "b3839a5fe2bcc535d7545cf6a4c85f7eb2f6fd0f"
        and later.get("mass_completeness_logic_changed") is False
        and later.get("accepted_mass_accumulation_logic_changed") is False
        and later.get("mass_residual_definition_changed") is False
    )

    for name in ("accumulate_accepted_mass", "finalize_interval_mass"):
        checks[f"mass_core_exact_fkt08:{name}"] = (
            subroutine_block(runtime, name) != ""
            and subroutine_block(runtime, name) == subroutine_block(fkt08_runtime, name)
            and subroutine_block(fmr04_runtime, name) == subroutine_block(fkt08_runtime, name)
        )

    checks["runtime_calls_fail_closed_mass_finalization"] = (
        "call accumulate_accepted_mass(result, tx, aggregate_mass_complete)" in runtime
        and "call finalize_interval_mass(result, aggregate_mass_complete)" in runtime
        and "result%mass%complete = aggregate_complete .and. finite_terms .and." in runtime
        and "result%mass%accepted_transaction_count > 0" in runtime
        and "result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE" in runtime
        and "result%mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED" in runtime
    )
    checks["obsolete_unconditional_false_placeholder_absent"] = "result%mass%complete = .false." not in runtime

    return all(checks.values()), checks


def main() -> int:
    checks: dict[str, bool] = {}

    contracts_path = ROOT / "src/runtime/mod_canonical_contracts.f90"
    runtime_path = ROOT / RUNTIME_PATH
    seam_path = ROOT / "integration/f-ci/F-CI04_PHYSICAL_SEAM_CONTRACT.json"
    snapshot_path = ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml"
    forbidden_adapter = ROOT / "src/adapter/mod_a23bu_hupsel_worker_component.f90"

    for path in (contracts_path, runtime_path, seam_path, snapshot_path):
        checks[f"exists:{path.relative_to(ROOT)}"] = path.is_file()

    if not all(checks.values()):
        failed = sorted(name for name, ok in checks.items() if not ok)
        print(json.dumps({"work_unit": "F-CI04", "status": "FAIL", "checks": checks, "failed": failed}, indent=2))
        return 2

    contracts = contracts_path.read_text(encoding="utf-8")
    runtime = runtime_path.read_text(encoding="utf-8")
    seam = json.loads(seam_path.read_text(encoding="utf-8"))
    snapshot = snapshot_path.read_text(encoding="utf-8")

    checks["explicit_persistent_state_type"] = "canonical_state_t" in contracts
    checks["explicit_forcing_type"] = "canonical_forcing_t" in contracts
    checks["explicit_numerical_config_type"] = "canonical_numerical_config_t" in contracts
    checks["explicit_result_type"] = "canonical_result_t" in contracts
    checks["explicit_mass_contract_type"] = "canonical_mass_accounting_t" in contracts
    checks["physical_model_prepare_contract"] = "prepare_interval" in contracts

    checks["runtime_private_working_state"] = "allocatable :: working" in runtime
    checks["runtime_clones_external_committed_state"] = "committed%clone(working)" in runtime
    checks["runtime_external_commit_only_at_completion"] = "move_alloc(working, committed)" in runtime
    checks["runtime_continues_to_requested_t1"] = "cursor, interval%t1" in runtime
    checks["runtime_has_bounded_substeps"] = "max_committed_substeps" in runtime

    historical_mass_placeholder = "result%mass%complete = .false." in runtime
    qualified_mass, mass_checks = qualified_mass_forward_evolution(runtime)
    checks["runtime_does_not_fabricate_mass_complete"] = historical_mass_placeholder or qualified_mass
    if not historical_mass_placeholder:
        checks.update({f"mass_forward:{name}": value for name, value in mass_checks.items()})

    checks["runtime_no_file_io"] = not any(token in runtime.lower() for token in ("open(", "read(", "write("))

    checks["b1_10_manifest_pinned"] = B1_10_MANIFEST in snapshot
    checks["seam_oracle_is_b1_10"] = seam.get("oracle", {}).get("snapshot") == "B1.10"
    checks["seam_manifest_matches"] = seam.get("oracle", {}).get("source_manifest_sha256") == B1_10_MANIFEST
    checks["seam_generic_time_required"] = seam.get("runtime_semantics", {}).get("requested_interval_is_generic_t0_t1") is True
    checks["seam_atomic_interval_required"] = seam.get("runtime_semantics", {}).get("full_requested_interval_is_externally_atomic") is True
    checks["seam_full_mass_still_blocked"] = seam.get("mass_contract", {}).get("full_unrounded_interval_accounting_currently_available") is False
    checks["wholesale_a23bu_adapter_absent"] = not forbidden_adapter.exists()
    checks["integer_day_projection_forbidden"] = seam.get("physical_model_contract", {}).get("integer_day_projection_allowed_in_canonical_seam") is False

    failed = sorted(name for name, ok in checks.items() if not ok)
    result = {
        "work_unit": "F-CI04",
        "status": "PASS" if not failed else "FAIL",
        "b1_oracle": "B1.10",
        "b1_manifest_sha256": B1_10_MANIFEST,
        "mass_provenance_mode": "HISTORICAL_NEGATIVE_PLACEHOLDER" if historical_mass_placeholder else "FCI23_PINNED_FKT08_FMR04_FORWARD_EVOLUTION",
        "checks": checks,
        "failed": failed,
        "holds": seam.get("holds", []),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
