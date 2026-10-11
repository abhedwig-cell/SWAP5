#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

POSTIMAGE = "42544af575db522d012db491db801615577048df"
PREIMAGE = "e537baf521e633c432a9f33de495fab9f18e918d"
ADMISSION_HEAD = "40e674db6c48f494fb5f49e52951c2a9ae3dfe9d"
DONOR = "48336cb7f14e9246b03c23e549fe7354a93f9e6b"
OLD_MOVING_AUTH = "0b284b5f4e224c5f76d7d78b9dbb51c99514479d"
WORKFLOW = Path(".github/workflows/fci-canonical.yml")
MARKER = "  current-restricted-canonical-preservation:\n"
FCI49_SOURCE = [
    "src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90",
    "src/adapter/mod_b110_production_soil_water_task2.f90",
    "src/adapter/mod_b1_10_reference_model.f90",
    "src/adapter/mod_reference_richards_legacy_binding.f90",
    "src/adapter/mod_soil_water_transaction_result_bridge.f90",
    "src/kernel/mod_kernel_transactions.f90",
    "src/legacy/b1_10_port/headcalc.f90",
    "src/legacy/b1_10_port/soilwater.f90",
    "src/runtime/mod_a23bu_worker_execution_context.f90",
    "src/runtime/mod_canonical_contracts.f90",
    "src/runtime/mod_canonical_interval_runtime.f90",
    "src/solver/mod_b110_dynamic_top_boundary_provider.f90",
    "src/solver/mod_reference_linear_solver.f90",
    "src/solver/mod_reference_richards_state_binding.f90",
    "src/solver/mod_reference_richards_workspace.f90",
    "src/solver/mod_soil_water_solver_contract.f90",
    "src/transaction/mod_transaction_reference.f90",
]
ALLOWED_BRANCH_DELTA = {
    ".github/workflows/fci-canonical.yml",
    ".github/workflows/fci49p-current-canonical-postimage-reconciliation.yml",
    "integration/f-ci/F-CI49P_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI49P_EVIDENCE.json",
    "integration/f-ci/F-CI49P_STATUS.json",
    "tests/fci/run_fci49p_current_canonical_postimage_reconciliation.py",
}


def git(*args: str) -> str:
    cp = subprocess.run(["git", *args], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return cp.stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI49P_FAIL: {message}")


def main() -> None:
    canonical = git("rev-parse", "origin/integration/f-ci-canonical")
    require(canonical == POSTIMAGE, f"canonical race: expected {POSTIMAGE}, got {canonical}")
    print("FCI49P_CANONICAL_POSTIMAGE_PIN=PASS")

    parents = git("rev-list", "--parents", "-n", "1", POSTIMAGE).split()
    require(parents == [POSTIMAGE, PREIMAGE, ADMISSION_HEAD], f"unexpected F-CI49 merge parents: {parents}")
    print("FCI49P_TRUE_TWO_PARENT_FCI49_MERGE=PASS")

    prod_ref_delta = git("diff", "--name-only", f"{POSTIMAGE}..HEAD", "--", "src", "reference")
    require(prod_ref_delta == "", f"production/reference delta after F-CI49 promotion: {prod_ref_delta}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{POSTIMAGE}:src"), "src tree changed on F-CI49P")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{POSTIMAGE}:reference"), "reference tree changed on F-CI49P")
    print("FCI49P_PRODUCTION_REFERENCE_POSTIMAGE_IMMUTABLE=PASS")

    for path in FCI49_SOURCE:
        require(git("rev-parse", f"{POSTIMAGE}:{path}") == git("rev-parse", f"{DONOR}:{path}"), f"promoted donor blob mismatch: {path}")
        require(git("rev-parse", f"HEAD:{path}") == git("rev-parse", f"{DONOR}:{path}"), f"F-CI49P donor blob drift: {path}")
    print("FCI49P_EXACT_DEFINITIVE_FKT15_17_BLOBS_PRESERVED=PASS")

    status = json.loads(Path("integration/f-ci/F-CI49_QUALIFICATION_STATUS.json").read_text())
    require(status.get("decision") == "QUALIFIED_FKT15_RESTRICTED_TASK2_SOLVER_SERVICE_FOR_CANONICAL_ADMISSION", "F-CI49 decision drift")
    require(status.get("definitive_kt15", {}).get("source_commit") == DONOR, "F-CI49 definitive donor drift")
    gates = status.get("gate_matrix", {})
    require(gates and all(str(v).startswith("PASS") for v in gates.values()), "F-CI49 gate matrix not fully PASS")
    guards = status.get("scope_guards", {})
    require(not any(guards.values()), "F-CI49 scope guard reports forbidden change")
    print("FCI49P_PREPROMOTION_ADMISSION_AUTHORITY_PINNED=PASS")

    evidence = json.loads(Path("integration/f-ci/F-CI49P_EVIDENCE.json").read_text())
    require(evidence.get("failed_broad_canonical_run") == 34677787757, "failed broad run provenance drift")
    require(evidence.get("failed_job") == 103510848450, "failed job provenance drift")
    require(evidence.get("failure_line") == "FCI_CANONICAL_PRESERVATION_FAIL admitted dependency drift: src/runtime/mod_a23bu_worker_execution_context.f90", "failure line drift")
    require(evidence.get("classification") == "STALE_MOVING_PRESERVATION_AUTHORITY_AFTER_QUALIFIED_SOURCE_ADMISSION", "failure classification drift")
    for key in ("production_regression_detected", "scientific_regression_detected", "transaction_regression_detected", "mass_regression_detected", "reference_regression_detected"):
        require(evidence.get(key) is False, f"evidence incorrectly reports regression: {key}")
    require(evidence.get("kt15_production_remediation_required") is False, "evidence incorrectly routes KT15 remediation")
    print("FCI49P_POSTPROMOTION_FAILURE_CLASSIFIED=PASS")

    changed = set(filter(None, git("diff", "--name-only", f"{POSTIMAGE}..HEAD").splitlines()))
    require(changed <= ALLOWED_BRANCH_DELTA, f"unexpected F-CI49P branch delta: {sorted(changed - ALLOWED_BRANCH_DELTA)}")
    require(".github/workflows/fci-canonical.yml" in changed, "moving preservation workflow not reconciled")
    print("FCI49P_GOVERNANCE_ONLY_BRANCH_DELTA=PASS")

    base_text = git("show", f"{POSTIMAGE}:{WORKFLOW.as_posix()}") + "\n"
    current_text = WORKFLOW.read_text()
    require(MARKER in base_text and MARKER in current_text, "moving-preservation job marker missing")
    base_prefix, base_suffix = base_text.split(MARKER, 1)
    cur_prefix, cur_suffix = current_text.split(MARKER, 1)
    require(cur_prefix == base_prefix, "historical/frozen workflow prefix changed")
    require(f"AUTH={OLD_MOVING_AUTH}" in base_suffix, "promoted F-CI49 workflow lacks expected stale authority")
    expected_suffix = base_suffix.replace(f"AUTH={OLD_MOVING_AUTH}", f"AUTH={POSTIMAGE}", 1)
    anchor = "          echo 'FCI48_MOVING_TYPED_OPTIONAL_STATE_LAYOUT_PRESERVATION=PASS'\n"
    marker = "          echo 'FCI49_MOVING_FKT15_SOLVER_SERVICE_TRANSACTION_COMPOSITION_PRESERVATION=PASS'\n"
    require(anchor in expected_suffix, "FCI48 marker anchor missing")
    expected_suffix = expected_suffix.replace(anchor, anchor + marker, 1)
    require(cur_suffix == expected_suffix, "fci-canonical moving-preservation change exceeds exact F-CI49P reconciliation")
    require(f"AUTH={OLD_MOVING_AUTH}" not in cur_suffix, "stale moving authority retained")
    require(cur_suffix.count(marker) == 1, "F-CI49 moving preservation marker count is not exactly one")
    print("FCI49P_FROZEN_WORKFLOW_PREFIX_BYTE_IDENTITY=PASS")
    print("FCI49P_MOVING_AUTHORITY_ADVANCED_EXACTLY_ONCE=PASS")

    audit = json.loads(Path("integration/f-ci/F-CI49P_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall")
    require(audit.get("mass_conservation") == "HARD_UNCHANGED", "mass conservation audit")
    require(audit.get("production_source_changed") is False, "architecture audit production change")
    require(audit.get("reference_changed") is False, "architecture audit reference change")
    require(audit.get("scientific_tolerances_changed") is False, "architecture audit tolerance change")
    require(audit.get("solver_functionality_changed") is False, "architecture audit solver change")
    inv = audit.get("invariants", [])
    require([x.get("id") for x in inv] == list(range(1, 31)), "architecture invariant IDs")
    require(all(x.get("status") == "PASS" for x in inv), "architecture invariant failure")
    print("FCI49P_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI49P_MASS_CONSERVATION=HARD_UNCHANGED")
    print("FCI49P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
