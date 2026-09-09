#!/usr/bin/env python3
"""Fail-closed provenance/architecture gate for the F-CI03 substrate.

F-CI03 originally imported byte-identical qualified A23 transaction/worker
sources. Later canonical work units may evolve the transaction source, but only
through an explicitly pinned forward-evolution provenance record. The worker
source and retained A23 regression artifacts remain byte-identical here.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

EXPECTED_GIT_BLOBS = {
    "src/transaction/mod_transaction_reference.f90": "5614ff261c9078def61959944aa57fd04c0d324a",
    "src/runtime/mod_a23bu_worker_execution_context.f90": "2a190d206200ad201c37c9a82d3e32e651d37a37",
    "tests/transaction/test_transaction_reference.f90": "e7959bdce0f217a6600e08dd8e28f284d977f3f2",
    "tests/runtime/test_a23bu_worker_context.f90": "774c2c4b36f479da302eb1574bbc3a9536cf291d",
    "tests/transaction/run_a23bl_gate.sh": "de4d7c23e4c3cee47fb160204a5e332bd42763c6",
}

TX_PATH = "src/transaction/mod_transaction_reference.f90"
FCI08_FORWARD_PROVENANCE = ROOT / "integration/f-ci/F-CI08_TRANSACTION_CONTEXT_PROVENANCE.json"
FCI23_FORWARD_PROVENANCE = ROOT / "integration/f-ci/F-CI23_TRANSACTION_FORWARD_PROVENANCE.json"
FCI23_EXPECTED_BLOB = "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4"
FCI23_CANDIDATE_HEAD = "4a792636ef73d25c671c5e0953cefd11978cd0ec"
FCI23_FKT09_CONTRACT_PATH = "integration/f-kt/F-KT09_DECISION_CONTRACT.json"
FCI23_FKT09_CONTRACT_BLOB = "7957c07ba3a1e31469f315b437f9ac3248a860e0"
FCI23_FCI19_AUDIT = ROOT / "integration/f-ci/F-CI19_FULL_SOURCE_LINEAGE_ADMISSION_AUDIT.json"
FCI23_FCI19_AUDIT_BLOB = "5985d659c8aa4e22c34243417111b9b013a3a12f"
FCI23_FCI19_STATUS = ROOT / "integration/f-ci/F-CI19_STATUS.json"
FCI23_FCI19_STATUS_BLOB = "b9a02d6e2ae61aac7fbe0788aaffc4b7e2896779"
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
FORBIDDEN_WHOLESALE_ADAPTER = ROOT / "src/adapter/mod_a23bu_hupsel_worker_component.f90"


def git_blob(path: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "hash-object", str(path)], text=True
    ).strip()


def git_object_blob(revision: str, relative: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", f"{revision}:{relative}"], text=True
    ).strip()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_json_at_revision(revision: str, relative: str) -> dict:
    raw = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{revision}:{relative}"], text=True
    )
    return json.loads(raw)


def admitted_fci08_evolution(actual: str) -> tuple[bool, dict]:
    if not FCI08_FORWARD_PROVENANCE.is_file():
        return False, {"mode": "FCI08_PROVENANCE_MISSING"}
    try:
        record = load_json(FCI08_FORWARD_PROVENANCE)
    except Exception as exc:
        return False, {"mode": "INVALID_FCI08_FORWARD_PROVENANCE", "error": str(exc)}
    ok = (
        record.get("work_unit") == "F-CI08"
        and record.get("source_path") == TX_PATH
        and record.get("fci03_parent_git_blob") == EXPECTED_GIT_BLOBS[TX_PATH]
        and record.get("fci08_candidate_git_blob") == actual
        and record.get("physics_formula_changed") is False
        and record.get("numerical_policy_changed") is False
        and record.get("persistent_column_state_expanded_with_attempt_context") is False
        and record.get("file_io_added") is False
    )
    record = dict(record)
    record["mode"] = "FCI08_PINNED_FORWARD_EVOLUTION"
    return ok, record


def admitted_fci23_evolution(actual: str) -> tuple[bool, dict]:
    if actual != FCI23_EXPECTED_BLOB:
        return False, {"mode": "NOT_FCI23_PINNED_BLOB", "actual": actual}
    required = [FCI23_FORWARD_PROVENANCE, FCI23_FCI19_AUDIT, FCI23_FCI19_STATUS]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        return False, {"mode": "FCI23_AUTHORITY_MISSING", "missing": missing}

    try:
        record = load_json(FCI23_FORWARD_PROVENANCE)
        fkt09 = load_json_at_revision(FCI23_CANDIDATE_HEAD, FCI23_FKT09_CONTRACT_PATH)
        fci19_audit = load_json(FCI23_FCI19_AUDIT)
        fci19_status = load_json(FCI23_FCI19_STATUS)
        candidate_blob = git_object_blob(FCI23_CANDIDATE_HEAD, TX_PATH)
        fkt09_contract_blob = git_object_blob(FCI23_CANDIDATE_HEAD, FCI23_FKT09_CONTRACT_PATH)
    except Exception as exc:
        return False, {"mode": "FCI23_FROZEN_AUTHORITY_UNAVAILABLE", "error": str(exc)}

    authority_blobs = {
        "fkt09_contract_at_candidate": fkt09_contract_blob,
        "fci19_audit": git_blob(FCI23_FCI19_AUDIT),
        "fci19_status": git_blob(FCI23_FCI19_STATUS),
    }

    semantics = record.get("qualified_semantics", {})
    candidate_authority = record.get("candidate_authority", {})
    admission_authority = record.get("canonical_admission_authority", {})
    hard = fkt09.get("hard_constraints", {})
    fci19_candidate = fci19_audit.get("candidate_a", {})
    lineage = fci19_audit.get("source_lineage_reachability_evidence", {})
    fci19_invariants = fci19_audit.get("invariant_assessment", {})
    fci19_status_candidate = fci19_status.get("candidate_a", {})
    fci19_status_state = fci19_status.get("state", {})
    fkt09_spine = next(
        (entry for entry in fci19_audit.get("ordered_source_spine", []) if entry.get("stage") == "F-KT09"),
        {},
    )

    ok = all((
        record.get("schema_version") == 1,
        record.get("work_unit") == "F-CI23",
        record.get("source_path") == TX_PATH,
        record.get("provenance_class") == "EXPLICIT_QUALIFIED_FORWARD_EVOLUTION",
        record.get("fci03_original_git_blob") == EXPECTED_GIT_BLOBS[TX_PATH],
        record.get("fci08_intermediate_git_blob") == "4a573316b77252b56bcb429fd519aa57123e9a06",
        record.get("admitted_git_blob") == actual,
        record.get("decision") == "ADMIT_EXACT_FKT09_FCI19_TRANSACTION_BLOB_AS_EXPLICIT_FORWARD_PROVENANCE",
        candidate_blob == actual,
        candidate_authority.get("work_unit") == "F-KT09",
        candidate_authority.get("candidate_head") == FCI23_CANDIDATE_HEAD,
        candidate_authority.get("candidate_source_blob") == actual,
        candidate_authority.get("decision_contract_path") == FCI23_FKT09_CONTRACT_PATH,
        candidate_authority.get("decision_contract_blob") == FCI23_FKT09_CONTRACT_BLOB,
        candidate_authority.get("production_richards_admitted") is False,
        admission_authority.get("work_unit") == "F-CI19",
        admission_authority.get("candidate_a_head") == FCI23_CANDIDATE_HEAD,
        admission_authority.get("full_source_lineage_audit_blob") == FCI23_FCI19_AUDIT_BLOB,
        admission_authority.get("source_lineage_gate_blob") == "9444001ca56e4158e211060221dd4ecd63f7d7ef",
        admission_authority.get("source_lineage_run") == 34320967298,
        admission_authority.get("source_lineage_job") == 102367277768,
        admission_authority.get("source_lineage_conclusion") == "success",
        admission_authority.get("status_blob") == FCI23_FCI19_STATUS_BLOB,
        admission_authority.get("candidate_composition_preservation") == "PASS",
        admission_authority.get("candidate_source_lineage_reachability") == "PASS",
        authority_blobs["fkt09_contract_at_candidate"] == FCI23_FKT09_CONTRACT_BLOB,
        authority_blobs["fci19_audit"] == FCI23_FCI19_AUDIT_BLOB,
        authority_blobs["fci19_status"] == FCI23_FCI19_STATUS_BLOB,
        fkt09.get("work_unit") == "F-KT09",
        fkt09.get("owner_scope") == candidate_authority.get("owner_scope"),
        fkt09.get("production_richards_admitted") is False,
        hard.get("mass_gate_remains_independent") is True,
        hard.get("mass_tolerance_unchanged") is True,
        hard.get("committed_state_mutation_before_external_commit") is False,
        hard.get("persistent_state_certificate_storage") is False,
        hard.get("calendar_specific_logic") is False,
        hard.get("coupling_specific_logic") is False,
        hard.get("richards_specific_logic") is False,
        hard.get("numeric_temporal_limits_selected") is False,
        hard.get("existing_exact_identity_routes_reinterpreted") is False,
        hard.get("new_mode_must_be_explicitly_selected") is True,
        fci19_candidate.get("exact_source_postimage") == FCI23_CANDIDATE_HEAD,
        fci19_candidate.get("origin") == "F-KT09 qualified code head",
        fci19_candidate.get("decision") == "QUALIFIED_RESTRICTED_SOURCE_POSTIMAGE_READY_FOR_CANONICAL_POSTIMAGE_MATERIALIZATION",
        lineage.get("conclusion") == "success",
        "generic transaction seam remains Richards-free and calendar-free" in lineage.get("proved", []),
        fkt09_spine.get("qualified_code_head") == FCI23_CANDIDATE_HEAD,
        fkt09_spine.get("classification") == "QUALIFIED_GENERIC_TRANSACTION_SEAM",
        fkt09_spine.get("production_richards_certificate") == "NOT_ADMITTED",
        fci19_invariants.get("transactional_timesteps") == "PASS_EXECUTED_CI19_REPLAY",
        fci19_invariants.get("generic_time") == "PASS_NO_CALENDAR_DEPENDENCY_IN_GENERIC_TRANSACTION_SEAM",
        fci19_invariants.get("mass_conservation") == "PASS_HARD_GATE",
        fci19_status.get("status") == "QUALIFIED_RESTRICTED_CANONICAL_SOURCE_LINEAGE_ADVANCED",
        fci19_status_candidate.get("exact_source_postimage") == FCI23_CANDIDATE_HEAD,
        fci19_status_candidate.get("composition_preservation") == "PASS",
        fci19_status_candidate.get("source_lineage_reachability") == "PASS",
        fci19_status_state.get("source_lineage_qualified") is True,
        fci19_status_state.get("canonical_ref_advanced") is True,
        fci19_status_state.get("closed") is True,
        semantics.get("generic_transaction_seam") is True,
        semantics.get("richards_specific_logic") is False,
        semantics.get("calendar_specific_logic") is False,
        semantics.get("coupling_specific_logic") is False,
        semantics.get("file_io_added") is False,
        semantics.get("physics_formula_changed") is False,
        semantics.get("numerical_policy_changed") is False,
        semantics.get("persistent_column_state_expanded") is False,
        semantics.get("hard_mass_gate_preserved") is True,
        semantics.get("rollback_semantics_preserved") is True,
        semantics.get("existing_default_transaction_mode_preserved") is True,
        semantics.get("model_owned_certificate_is_explicit_opt_in") is True,
        semantics.get("production_richards_certificate_admitted_by_F_KT09_or_F_CI19") is False,
    ))

    result = dict(record)
    result["mode"] = "FCI23_PINNED_FKT09_FCI19_FORWARD_EVOLUTION"
    result["candidate_git_object_blob"] = candidate_blob
    result["authority_git_blobs"] = authority_blobs
    return ok, result


def admitted_tx_evolution(actual: str) -> tuple[bool, dict]:
    if actual == EXPECTED_GIT_BLOBS[TX_PATH]:
        return True, {"mode": "BYTE_IDENTICAL_A23"}

    fci08_ok, fci08_record = admitted_fci08_evolution(actual)
    if fci08_ok:
        return True, fci08_record

    fci23_ok, fci23_record = admitted_fci23_evolution(actual)
    if fci23_ok:
        return True, fci23_record

    return False, {
        "mode": "UNPINNED_OR_UNQUALIFIED_FORWARD_EVOLUTION",
        "actual": actual,
        "fci08": fci08_record,
        "fci23": fci23_record,
    }


def main() -> int:
    checks: dict[str, bool] = {}
    actual_blobs: dict[str, str] = {}
    evolution: dict = {}

    for relative, expected in EXPECTED_GIT_BLOBS.items():
        path = ROOT / relative
        exists = path.is_file()
        checks[f"exists:{relative}"] = exists
        if not exists:
            continue
        actual = git_blob(path)
        actual_blobs[relative] = actual
        if relative == TX_PATH:
            admitted, evolution = admitted_tx_evolution(actual)
            checks[f"qualified_provenance:{relative}"] = admitted
        else:
            checks[f"byte_identical_to_a23:{relative}"] = actual == expected

    checks["a23bu_wholesale_adapter_absent"] = not FORBIDDEN_WHOLESALE_ADAPTER.exists()

    tx = (ROOT / TX_PATH).read_text(encoding="utf-8")
    checks["transaction_has_explicit_checkpoint"] = "allocatable :: checkpoint" in tx
    checks["transaction_commit_is_move_alloc"] = "move_alloc(half_state, committed)" in tx
    checks["transaction_generic_t0_t1"] = "real(real64), intent(in) :: t0, t1" in tx
    checks["transaction_no_file_io"] = not any(token in tx.lower() for token in ("open(", "read(", "write("))

    worker = (ROOT / "src/runtime/mod_a23bu_worker_execution_context.f90").read_text(encoding="utf-8")
    checks["worker_owns_headcalc_scratch"] = "type, public :: a23bu_headcalc_scratch_t" in worker
    checks["worker_scratch_allocatable"] = "real(real64), allocatable :: dfdhl(:)" in worker
    checks["worker_owns_numerical_control"] = "type(a23bu_numerical_control_t) :: control" in worker
    checks["reporting_not_column_state"] = "type(a23bu_reporting_progress_t) :: reporting" in worker

    snapshot = (ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml").read_text(encoding="utf-8")
    checks["b1_10_manifest_pinned"] = B1_10_MANIFEST in snapshot
    for patch in ("SWAP-010", "SWAP-013", "SWAP-012", "SWAP-002"):
        checks[f"b1_10_contains:{patch}"] = f'id: "{patch}"' in snapshot

    failed = sorted(name for name, passed in checks.items() if not passed)
    result = {
        "work_unit": "F-CI03",
        "status": "PASS" if not failed else "FAIL",
        "a23_source_commit": "763f276a96ee1722a465bacd3a710172a5f38107",
        "a23_merge_base": "2d05eeab9d766d51bc7c436ea1e45f9b49940e92",
        "b1_oracle": "B1.10",
        "b1_manifest_sha256": B1_10_MANIFEST,
        "checks": checks,
        "actual_git_blobs": actual_blobs,
        "transaction_source_provenance": evolution,
        "failed": failed,
        "holds": [
            "generic physical sub-day execution not yet qualified",
            "mandatory full-plus-two-half transaction route remains reference-only",
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
