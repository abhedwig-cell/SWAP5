#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

BASE_CANONICAL = "e5662a513846296585a1a7005729896c165091ac"
EXPECTED_SRC_TREE = "3446aa1d0d80861b22f7e74c7ad51bcedef4f479"
EXPECTED_REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
FCI18_EXIT_HEAD = "1eceed967b12396b8bbc832f897376378463adce"
FCI18_STATUS_BLOB = "ab4636c7048e3c6d6bae65c3615e1fec4fb0ae46"
FCI19_CANDIDATE = "4a792636ef73d25c671c5e0953cefd11978cd0ec"
FCI19_AUDIT_BLOB = "5985d659c8aa4e22c34243417111b9b013a3a12f"
FCI19_STATUS_BLOB = "b9a02d6e2ae61aac7fbe0788aaffc4b7e2896779"
FCI21_STATUS_BLOB = "3d0d891aee18744c998f9beedf2fa7851edc4c0a"
FCI21_CLOSEOUT_BLOB = "57f670c02a58cd21fc442a076c7a2ad06087254a"
FCI22_STATUS_BLOB = "166e1428b879dff9f8289a7e6d69a02407d2fab2"
TX_BLOB = "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4"
FKT09_CONTRACT_PATH = "integration/f-kt/F-KT09_DECISION_CONTRACT.json"
FKT09_CONTRACT_BLOB = "7957c07ba3a1e31469f315b437f9ac3248a860e0"
FKT08_HEAD = "510d1f29d40225c68f3a8d3e789071279941e87b"
FKT08_STATUS_BLOB = "157fd9f50e291f37439cb374ae20d875605580db"
FKT08_EVIDENCE_BLOB = "5b5f6e0fe790f5290798f9f64030c33ccae896f2"
FKT08_RUNTIME_BLOB = "f2cae79d533343db818c11e0b61b605ac5f6739d"
FMR04_SOURCE = "11eb34ea3afe8f5dda0515c28d7e08428dd2e272"
FMR04_EVIDENCE_BLOB = "50e37e6f5666b59e27fb7aa0dde51ca060c873e2"
FMR04_STATUS_BLOB = "9d073bf239a94fd381b10f1a4a745d6c17991cdf"
CURRENT_RUNTIME_BLOB = "55f3d271aa6200a994fd0144d6fce0701c918a74"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def blob(rev: str, path: str) -> str:
    return git("rev-parse", f"{rev}:{path}")


def show(rev: str, path: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), "show", f"{rev}:{path}"], text=True)


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def load_at(rev: str, path: str) -> dict:
    return json.loads(show(rev, path))


def block(source: str, name: str) -> str:
    begin = f"  subroutine {name}"
    end = f"  end subroutine {name}"
    i = source.find(begin)
    j = source.find(end)
    if i < 0 or j < 0:
        return ""
    return source[i:j + len(end)]


def main() -> int:
    checks: dict[str, bool] = {}

    # F-CI23 is governance/test reconciliation only. The admitted F-CI22
    # production and reference postimage must remain exact.
    checks["exact_src_tree"] = blob("HEAD", "src") == EXPECTED_SRC_TREE
    checks["exact_reference_tree"] = blob("HEAD", "reference") == EXPECTED_REFERENCE_TREE
    checks["fci23_no_src_delta"] = subprocess.run(
        ["git", "-C", str(ROOT), "diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "src"]
    ).returncode == 0
    checks["fci23_no_reference_delta"] = subprocess.run(
        ["git", "-C", str(ROOT), "diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "reference"]
    ).returncode == 0
    checks["base_is_ancestor"] = subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", BASE_CANONICAL, "HEAD"]
    ).returncode == 0

    # Frozen F-CI18 authority. Historical gates are replayed separately on this
    # exact head; here we pin the machine-readable qualification statement.
    fci18 = load("integration/f-ci/F-CI18_STATUS.json")
    checks["fci18_status_blob"] = blob("HEAD", "integration/f-ci/F-CI18_STATUS.json") == FCI18_STATUS_BLOB
    checks["fci18_full_chain_qualified"] = (
        fci18.get("status") == "QUALIFIED_EXIT"
        and fci18.get("canonical_development_baseline_exit_head") == FCI18_EXIT_HEAD
        and fci18.get("qualification", {}).get("gate_promotion_replay") == "PASS_RUN_34114164800_JOB_101717589931"
        and fci18.get("qualification", {}).get("gate_promotion_full_dependency_chain") == "PASS_FCI03_THROUGH_FCI18"
        and fci18.get("all_required_gates") == "QUALIFIED"
    )

    # F-CI19 Candidate A is the qualified restricted source-lineage bridge from
    # F-CI18 into later runtime/kernel work.
    fci19 = load("integration/f-ci/F-CI19_STATUS.json")
    audit19 = load("integration/f-ci/F-CI19_FULL_SOURCE_LINEAGE_ADMISSION_AUDIT.json")
    checks["fci19_status_blob"] = blob("HEAD", "integration/f-ci/F-CI19_STATUS.json") == FCI19_STATUS_BLOB
    checks["fci19_audit_blob"] = blob("HEAD", "integration/f-ci/F-CI19_FULL_SOURCE_LINEAGE_ADMISSION_AUDIT.json") == FCI19_AUDIT_BLOB
    checks["fci19_candidate_and_replays_qualified"] = (
        fci19.get("status") == "QUALIFIED_RESTRICTED_CANONICAL_SOURCE_LINEAGE_ADVANCED"
        and fci19.get("candidate_a", {}).get("exact_source_postimage") == FCI19_CANDIDATE
        and fci19.get("candidate_a", {}).get("composition_preservation") == "PASS"
        and fci19.get("candidate_a", {}).get("source_lineage_reachability") == "PASS"
        and fci19.get("decisive_evidence", {}).get("candidate_composition_workflow_run") == 34319928251
        and fci19.get("decisive_evidence", {}).get("reachability_workflow_run") == 34320967298
        and fci19.get("state", {}).get("source_lineage_qualified") is True
        and fci19.get("state", {}).get("closed") is True
        and audit19.get("candidate_a", {}).get("exact_source_postimage") == FCI19_CANDIDATE
        and audit19.get("composition_preservation_evidence", {}).get("conclusion") == "success"
        and audit19.get("source_lineage_reachability_evidence", {}).get("conclusion") == "success"
        and audit19.get("invariant_assessment", {}).get("transactional_timesteps") == "PASS_EXECUTED_CI19_REPLAY"
        and audit19.get("invariant_assessment", {}).get("mass_conservation") == "PASS_HARD_GATE"
        and audit19.get("invariant_assessment", {}).get("generic_time") == "PASS_NO_CALENDAR_DEPENDENCY_IN_GENERIC_TRANSACTION_SEAM"
    )

    # Transaction source stayed byte-identical after the qualified F-KT09 /
    # F-CI19 Candidate A source. The dedicated F-CI23 record makes this explicit
    # without changing the historical F-CI03 reader.
    tx_record = load("integration/f-ci/F-CI23_TRANSACTION_FORWARD_PROVENANCE.json")
    fkt09 = load_at(FCI19_CANDIDATE, FKT09_CONTRACT_PATH)
    hard09 = fkt09.get("hard_constraints", {})
    checks["transaction_blob_exact_candidate_a"] = (
        blob("HEAD", "src/transaction/mod_transaction_reference.f90") == TX_BLOB
        and blob(FCI19_CANDIDATE, "src/transaction/mod_transaction_reference.f90") == TX_BLOB
        and blob(FCI19_CANDIDATE, FKT09_CONTRACT_PATH) == FKT09_CONTRACT_BLOB
    )
    checks["transaction_forward_record"] = (
        tx_record.get("decision") == "ADMIT_EXACT_FKT09_FCI19_TRANSACTION_BLOB_AS_EXPLICIT_FORWARD_PROVENANCE"
        and tx_record.get("admitted_git_blob") == TX_BLOB
        and tx_record.get("candidate_authority", {}).get("candidate_head") == FCI19_CANDIDATE
        and tx_record.get("candidate_authority", {}).get("decision_contract_blob") == FKT09_CONTRACT_BLOB
        and tx_record.get("canonical_admission_authority", {}).get("full_source_lineage_audit_blob") == FCI19_AUDIT_BLOB
        and tx_record.get("canonical_admission_authority", {}).get("source_lineage_run") == 34320967298
        and tx_record.get("qualified_semantics", {}).get("hard_mass_gate_preserved") is True
        and tx_record.get("qualified_semantics", {}).get("rollback_semantics_preserved") is True
        and tx_record.get("qualified_semantics", {}).get("richards_specific_logic") is False
        and tx_record.get("qualified_semantics", {}).get("calendar_specific_logic") is False
    )
    checks["fkt09_hard_constraints"] = (
        fkt09.get("work_unit") == "F-KT09"
        and fkt09.get("production_richards_admitted") is False
        and hard09.get("mass_gate_remains_independent") is True
        and hard09.get("mass_tolerance_unchanged") is True
        and hard09.get("committed_state_mutation_before_external_commit") is False
        and hard09.get("calendar_specific_logic") is False
        and hard09.get("coupling_specific_logic") is False
        and hard09.get("richards_specific_logic") is False
        and hard09.get("numeric_temporal_limits_selected") is False
    )

    # F-KT08/F-MR04 replaced the old F-CI04 negative placeholder with real,
    # fail-closed accepted-only interval mass accounting. The mass core itself
    # remains byte-equivalent at subroutine level in the current runtime.
    mass_record = load("integration/f-ci/F-CI23_FCI04_MASS_PROVENANCE.json")
    fkt08_status = load_at(FKT08_HEAD, "integration/f-kt/F-KT08_STATUS.json")
    fkt08_ev = load_at(FKT08_HEAD, "integration/f-kt/F-KT08_QUALIFICATION_EVIDENCE.json")
    fmr04_ev = load_at(FCI19_CANDIDATE, "integration/f-mr/F-MR04_QUALIFICATION_EVIDENCE.json")
    fmr04_status = load_at(FCI19_CANDIDATE, "integration/f-mr/F-MR04_STATUS.json")
    current_runtime = show("HEAD", "src/runtime/mod_canonical_interval_runtime.f90")
    fkt08_runtime = show(FKT08_HEAD, "src/runtime/mod_canonical_interval_runtime.f90")
    checks["mass_authority_blobs"] = (
        blob(FKT08_HEAD, "integration/f-kt/F-KT08_STATUS.json") == FKT08_STATUS_BLOB
        and blob(FKT08_HEAD, "integration/f-kt/F-KT08_QUALIFICATION_EVIDENCE.json") == FKT08_EVIDENCE_BLOB
        and blob(FKT08_HEAD, "src/runtime/mod_canonical_interval_runtime.f90") == FKT08_RUNTIME_BLOB
        and blob(FCI19_CANDIDATE, "integration/f-mr/F-MR04_QUALIFICATION_EVIDENCE.json") == FMR04_EVIDENCE_BLOB
        and blob(FCI19_CANDIDATE, "integration/f-mr/F-MR04_STATUS.json") == FMR04_STATUS_BLOB
        and blob(FMR04_SOURCE, "src/runtime/mod_canonical_interval_runtime.f90") == FKT08_RUNTIME_BLOB
        and blob("HEAD", "src/runtime/mod_canonical_interval_runtime.f90") == CURRENT_RUNTIME_BLOB
    )
    checks["mass_fail_closed_authority"] = (
        fkt08_status.get("QUALIFIED") is True
        and fkt08_status.get("authoritative_full_interval_mass_accounting_qualified") is True
        and fkt08_status.get("completeness_fail_closed") is True
        and fkt08_status.get("accepted_only_accounting") is True
        and fkt08_status.get("retry_double_counting") is False
        and fkt08_status.get("rollback_mutates_committed_accounting") is False
        and fkt08_status.get("mass_conservation_disable_switch_added") is False
        and fkt08_ev.get("result") == "QUALIFIED_BASIS"
        and fkt08_ev.get("transaction_semantics", {}).get("rejected_trials_committed") is False
        and fkt08_ev.get("completeness_semantics", {}).get("default") == "fail-closed"
        and fkt08_ev.get("canonical_mass_contract", {}).get("mass_conservation_disable_switch") is False
        and fmr04_ev.get("qualification") == "QUALIFIED_SERIALIZED_PHYSICAL_RUNTIME_CANDIDATE_READY_FOR_FVQ"
        and fmr04_ev.get("consumed_dependencies", {}).get("F-KT08") == FKT08_HEAD
        and fmr04_ev.get("gates", {}).get("authoritative_full_interval_mass_complete") == "PASS"
        and fmr04_ev.get("gates", {}).get("authoritative_missing_mask_zero") == "PASS"
        and fmr04_ev.get("gates", {}).get("authoritative_mass_residual") == "PASS_ZERO"
        and fmr04_status.get("QUALIFIED") is True
    )
    checks["mass_forward_record"] = (
        mass_record.get("decision") == "REPLACE_OBSOLETE_NEGATIVE_LITERAL_WITH_PINNED_QUALIFIED_FAIL_CLOSED_MASS_PROVENANCE_CHECK"
        and mass_record.get("qualified_forward_authority", {}).get("F_KT08_final_head") == FKT08_HEAD
        and mass_record.get("qualified_forward_authority", {}).get("current_admitted_runtime_blob") == CURRENT_RUNTIME_BLOB
        and mass_record.get("required_semantics", {}).get("accepted_only_accounting") is True
        and mass_record.get("required_semantics", {}).get("completeness_fail_closed") is True
        and mass_record.get("required_semantics", {}).get("mass_conservation_disable_switch") is False
    )
    checks["mass_core_preserved"] = all(
        block(current_runtime, name) != "" and block(current_runtime, name) == block(fkt08_runtime, name)
        for name in ("accumulate_accepted_mass", "finalize_interval_mass")
    )

    # F-CI21 is the currently admitted production postimage. F-CI22 qualified
    # exactly this src/reference image for canonical fast-forward; the executable
    # F-CI21 closeout gate is run separately in the workflow on HEAD.
    fci21 = load("integration/f-ci/F-CI21_STATUS.json")
    close21 = load("integration/f-ci/F-CI21_CLOSEOUT.json")
    fci22 = load("integration/f-ci/F-CI22_STATUS.json")
    checks["fci21_authority_blobs"] = (
        blob("HEAD", "integration/f-ci/F-CI21_STATUS.json") == FCI21_STATUS_BLOB
        and blob("HEAD", "integration/f-ci/F-CI21_CLOSEOUT.json") == FCI21_CLOSEOUT_BLOB
        and fci21.get("state", {}).get("qualified") is True
        and fci21.get("state", {}).get("closed") is True
        and close21.get("state", {}).get("qualified") is True
        and close21.get("state", {}).get("closed") is True
        and close21.get("closed_qualified_chain", {}).get("F_WOF42_crop_persistence_preservation") is True
        and close21.get("closed_qualified_chain", {}).get("F_MR18_accepted_commit_receipt_preservation") is True
        and close21.get("closed_qualified_chain", {}).get("F_MR18_sparse_multiswap_receipt_preservation") is True
    )
    checks["fci21_negative_evidence_and_nonclaims"] = (
        fci21.get("negative_evidence", {}).get("must_remain_failed") is True
        and fci21.get("negative_evidence", {}).get("reinterpreted_as_pass") is False
        and fci21.get("negative_evidence", {}).get("used_as_positive_evidence") is False
        and fci21.get("qualified_policy_scope", {}).get("mass_gate_precedes_certificate_gate") is True
        and fci21.get("hard_nonclaims", {}).get("application_H_budget_selected") is False
        and fci21.get("hard_nonclaims", {}).get("universal_temporal_tolerance_selected") is False
        and fci21.get("hard_nonclaims", {}).get("groundwater_coupling_released") is False
    )
    checks["fci22_exact_postimage_admission"] = (
        blob("HEAD", "integration/f-ci/F-CI22_STATUS.json") == FCI22_STATUS_BLOB
        and fci22.get("candidate", {}).get("src_tree") == EXPECTED_SRC_TREE
        and fci22.get("candidate", {}).get("reference_tree") == EXPECTED_REFERENCE_TREE
        and fci22.get("qualified_scope", {}).get("exact_F_CI21_postimage_admissible") is True
        and fci22.get("qualified_scope", {}).get("hard_mass_precedence_preserved") is True
        and fci22.get("qualified_scope", {}).get("transactional_rollback_preserved") is True
        and fci22.get("decision") == "QUALIFIED_RESTRICTED_FCI21_POSTIMAGE_READY_FOR_CANONICAL_FAST_FORWARD"
    )

    # Preserve the principal F-CI19 release holds. F-CI21/F-CI22 only add the
    # qualified restricted temporal-certificate postimage; they do not release
    # unrelated held compositions.
    holds = set(fci19.get("hard_holds", []))
    checks["hard_holds_preserved"] = all(text in holds for text in (
        "general groundwater predictor-corrector coupling remains not admitted",
        "parallel real-physics execution remains not admitted",
        "BALANCED THROUGHPUT and FALLBACK remain not admitted",
        "subdaily and multiday active snow remain not admitted",
        "active macropore and swkimpl=1 scope are not expanded",
        "irrigation process admission does not imply runtime composition",
        "LayeredMFP and VZAA are not production solver admissions",
    ))

    failed = sorted(name for name, ok in checks.items() if not ok)
    print(json.dumps({
        "work_unit": "F-CI23",
        "status": "PASS" if not failed else "FAIL",
        "mode": "HISTORICAL_AUTHORITY_PLUS_EXPLICIT_FORWARD_LINEAGE",
        "src_tree": blob("HEAD", "src"),
        "reference_tree": blob("HEAD", "reference"),
        "checks": checks,
        "failed": failed,
    }, indent=2, sort_keys=True))
    if failed:
        return 2
    print("FCI23_CURRENT_LINEAGE_AUTHORITY_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
