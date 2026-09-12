#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

POSTIMAGE = "39b8ed3d33c564530feeeb1e1c6d5af0a0be6636"
PREIMAGE = "ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868"
ADMISSION_HEAD = "bbdba02d8aa51204191aea8ccb8f0fcfc0d0fb6b"
DONOR = "f0e9465c78237fd974369d0ffcfaba9adc6d7b54"
OLD_MOVING_AUTH = "42544af575db522d012db491db801615577048df"
WORKFLOW = Path(".github/workflows/fci-canonical.yml")
MARKER = "  current-restricted-canonical-preservation:\n"
FGC17_SOURCE = {
    "src/runtime/mod_groundwater_coupling_contract.f90": "fc598d14eabafcb025bb55621f7b00d6d1816f10",
    "src/runtime/mod_groundwater_coupling_policy.f90": "5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976",
}
ALLOWED_BRANCH_DELTA = {
    ".github/workflows/fci-canonical.yml",
    ".github/workflows/fci50p-current-canonical-postimage-reconciliation.yml",
    "integration/f-ci/F-CI50P_PRE_REGISTRATION.json",
    "integration/f-ci/F-CI50P_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI50P_EVIDENCE.json",
    "integration/f-ci/F-CI50P_STATUS.json",
    "tests/fci/run_fci50p_current_canonical_postimage_reconciliation.py",
}


def git(*args: str) -> str:
    cp = subprocess.run(["git", *args], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return cp.stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI50P_FAIL: {message}")


def main() -> None:
    canonical = git("rev-parse", "origin/integration/f-ci-canonical")
    require(canonical == POSTIMAGE, f"canonical race: expected {POSTIMAGE}, got {canonical}")
    print("FCI50P_CANONICAL_POSTIMAGE_PIN=PASS")

    parents = git("rev-list", "--parents", "-n", "1", POSTIMAGE).split()
    require(parents == [POSTIMAGE, PREIMAGE, ADMISSION_HEAD], f"unexpected F-CI50 merge parents: {parents}")
    print("FCI50P_TRUE_TWO_PARENT_FCI50_MERGE=PASS")

    prod_ref_delta = git("diff", "--name-only", f"{POSTIMAGE}..HEAD", "--", "src", "reference")
    require(prod_ref_delta == "", f"production/reference delta after F-CI50 promotion: {prod_ref_delta}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{POSTIMAGE}:src"), "src tree changed on F-CI50P")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{POSTIMAGE}:reference"), "reference tree changed on F-CI50P")
    print("FCI50P_PRODUCTION_REFERENCE_POSTIMAGE_IMMUTABLE=PASS")

    for path, blob in FGC17_SOURCE.items():
        require(git("rev-parse", f"{POSTIMAGE}:{path}") == blob, f"F-CI50 postimage blob mismatch: {path}")
        require(git("rev-parse", f"HEAD:{path}") == blob, f"F-CI50P source drift: {path}")
        require(git("rev-parse", f"{DONOR}:{path}") == blob, f"F-GC17 donor blob mismatch: {path}")
    print("FCI50P_EXACT_FGC17_BLOBS_PRESERVED=PASS")

    status = json.loads(Path("integration/f-ci/F-CI50_QUALIFICATION_STATUS.json").read_text())
    require(status.get("decision") == "QUALIFIED_FGC17_TYPED_GROUNDWATER_INTERFACE_FOR_CANONICAL_ADMISSION", "F-CI50 decision drift")
    require(status.get("canonical_base") == PREIMAGE, "F-CI50 canonical base drift")
    gates = status.get("gate_matrix", {})
    require(gates and all(str(v).startswith("PASS") for v in gates.values()), "F-CI50 gate matrix not fully PASS")
    guards = status.get("scope_guards", {})
    require(not any(guards.values()), "F-CI50 scope guard reports forbidden change")
    print("FCI50P_PREPROMOTION_ADMISSION_AUTHORITY_PINNED=PASS")

    evidence = json.loads(Path("integration/f-ci/F-CI50P_EVIDENCE.json").read_text())
    broad = evidence.get("postpromotion_broad_canonical_run", {})
    require(broad.get("run") == 34678610128, "broad postpromotion run provenance drift")
    require(broad.get("conclusion") == "success", "broad postpromotion run not green")
    require(broad.get("current_restricted_preservation_job") == 103513068810, "preservation job provenance drift")
    require(broad.get("current_restricted_preservation_conclusion") == "success", "postpromotion preservation job not green")
    obs = evidence.get("observations", {})
    for key in ("production_regression_detected", "scientific_regression_detected", "transaction_regression_detected", "mass_regression_detected", "reference_regression_detected"):
        require(obs.get(key) is False, f"evidence incorrectly reports regression: {key}")
    print("FCI50P_POSTPROMOTION_BROAD_CANONICAL_GREEN=PASS")

    changed = set(filter(None, git("diff", "--name-only", f"{POSTIMAGE}..HEAD").splitlines()))
    require(changed <= ALLOWED_BRANCH_DELTA, f"unexpected F-CI50P branch delta: {sorted(changed - ALLOWED_BRANCH_DELTA)}")
    require(".github/workflows/fci-canonical.yml" in changed, "moving preservation workflow not reconciled")
    print("FCI50P_GOVERNANCE_ONLY_BRANCH_DELTA=PASS")

    base_text = git("show", f"{POSTIMAGE}:{WORKFLOW.as_posix()}") + "\n"
    current_text = WORKFLOW.read_text()
    require(MARKER in base_text and MARKER in current_text, "moving-preservation job marker missing")
    base_prefix, base_suffix = base_text.split(MARKER, 1)
    cur_prefix, cur_suffix = current_text.split(MARKER, 1)
    require(cur_prefix == base_prefix, "historical/frozen workflow prefix changed")
    require(f"AUTH={OLD_MOVING_AUTH}" in base_suffix, "F-CI50 postimage lacks expected previous moving authority")

    expected_suffix = base_suffix.replace(f"AUTH={OLD_MOVING_AUTH}", f"AUTH={POSTIMAGE}", 1)
    dependency_anchor = "            src/runtime/mod_coupling_application_accuracy_adapter.f90\n          )\n"
    dependency_add = (
        "            src/runtime/mod_coupling_application_accuracy_adapter.f90\n"
        "            src/runtime/mod_groundwater_coupling_contract.f90\n"
        "            src/runtime/mod_groundwater_coupling_policy.f90\n"
        "          )\n"
    )
    require(dependency_anchor in expected_suffix, "dependency insertion anchor missing")
    expected_suffix = expected_suffix.replace(dependency_anchor, dependency_add, 1)

    marker_anchor = "          echo 'FCI49_MOVING_FKT15_SOLVER_SERVICE_TRANSACTION_COMPOSITION_PRESERVATION=PASS'\n"
    marker_add = marker_anchor + "          echo 'FCI50_MOVING_FGC17_TYPED_GROUNDWATER_INTERFACE_PRESERVATION=PASS'\n"
    require(marker_anchor in expected_suffix, "F-CI49 marker anchor missing")
    expected_suffix = expected_suffix.replace(marker_anchor, marker_add, 1)
    require(cur_suffix == expected_suffix, "fci-canonical moving-preservation delta exceeds exact F-CI50P reconciliation")
    require(f"AUTH={OLD_MOVING_AUTH}" not in cur_suffix, "stale moving authority retained")
    require(cur_suffix.count("FCI50_MOVING_FGC17_TYPED_GROUNDWATER_INTERFACE_PRESERVATION=PASS") == 1, "F-CI50 marker count is not exactly one")
    print("FCI50P_FROZEN_WORKFLOW_PREFIX_BYTE_IDENTITY=PASS")
    print("FCI50P_MOVING_AUTHORITY_AND_SURFACE_ADVANCED_EXACTLY_ONCE=PASS")

    audit = json.loads(Path("integration/f-ci/F-CI50P_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall")
    require(audit.get("mass_conservation") == "HARD_UNCHANGED", "mass conservation audit")
    require(audit.get("production_source_changed") is False, "architecture audit production change")
    require(audit.get("reference_changed") is False, "architecture audit reference change")
    require(audit.get("scientific_tolerances_changed") is False, "architecture audit tolerance change")
    require(audit.get("solver_functionality_changed") is False, "architecture audit solver change")
    inv = audit.get("invariants", [])
    require([x.get("id") for x in inv] == list(range(1, 31)), "architecture invariant IDs")
    require(all(x.get("status") == "PASS" for x in inv), "architecture invariant failure")
    print("FCI50P_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI50P_MASS_CONSERVATION=HARD_UNCHANGED")
    print("FCI50P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
