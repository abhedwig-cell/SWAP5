#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

POSTIMAGE = "828ba0f0ed933fb62107f849ae0bb7cc32c47c30"
PREIMAGE = "8695974b783e76b3807890be9e1c0ecb5d2f8d5f"
ADMISSION_HEAD = "65ab358bd3f506c31c61e9287f4427eb2e74f2cc"
QUALIFICATION_AUTHORITY = "f65f170fc6ec5f1a228ade2def3732cb36942ebd"
R1_PRODUCTION_COMPOSITION = "7a35e123d263c3783a2a0a14ea467e5e065b821c"
OLD_MOVING_AUTH = "6c04ab07b4535c119157b5c5bce674b626656f07"
WORKFLOW = Path(".github/workflows/fci-canonical.yml")
MARKER = "  current-restricted-canonical-preservation:\n"
FCI52_SOURCE = [
    "src/process/mod_restricted_fixed_weir_surface_water.f90",
    "src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90",
    "src/runtime/mod_fmr_restart_state_contract.f90",
    "src/runtime/mod_fmr_runtime_core.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
]
ALLOWED_BRANCH_DELTA = {
    ".github/workflows/fci-canonical.yml",
    ".github/workflows/fci52p-current-canonical-postimage-reconciliation.yml",
    "integration/f-ci/F-CI52P_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI52P_EVIDENCE.json",
    "integration/f-ci/F-CI52P_STATUS.json",
    "tests/fci/run_fci52p_current_canonical_postimage_reconciliation.py",
}


def git(*args: str) -> str:
    cp = subprocess.run(
        ["git", *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return cp.stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI52P_FAIL: {message}")


def main() -> None:
    canonical = git("rev-parse", "origin/integration/f-ci-canonical")
    require(canonical == POSTIMAGE, f"canonical race: expected {POSTIMAGE}, got {canonical}")
    print("FCI52P_CANONICAL_POSTIMAGE_PIN=PASS")

    parents = git("rev-list", "--parents", "-n", "1", POSTIMAGE).split()
    require(parents == [POSTIMAGE, PREIMAGE, ADMISSION_HEAD], f"unexpected F-CI52 merge parents: {parents}")
    print("FCI52P_TRUE_TWO_PARENT_FCI52_SOURCE_MERGE=PASS")

    require(git("merge-base", "--is-ancestor", R1_PRODUCTION_COMPOSITION, ADMISSION_HEAD) == "", "R1 production composition is not an ancestor of the admission head")
    prod_ref_delta = git("diff", "--name-only", f"{POSTIMAGE}..HEAD", "--", "src", "reference")
    require(prod_ref_delta == "", f"production/reference delta after F-CI52 promotion: {prod_ref_delta}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{POSTIMAGE}:src"), "src tree changed on F-CI52P")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{POSTIMAGE}:reference"), "reference tree changed on F-CI52P")
    print("FCI52P_PRODUCTION_REFERENCE_POSTIMAGE_IMMUTABLE=PASS")

    for path in FCI52_SOURCE:
        post_blob = git("rev-parse", f"{POSTIMAGE}:{path}")
        qual_blob = git("rev-parse", f"{QUALIFICATION_AUTHORITY}:{path}")
        r1_blob = git("rev-parse", f"{R1_PRODUCTION_COMPOSITION}:{path}")
        head_blob = git("rev-parse", f"HEAD:{path}")
        require(post_blob == qual_blob, f"F-VQ59 qualified blob not present in promoted postimage: {path}")
        require(post_blob == r1_blob, f"R1 production-composition blob drift: {path}")
        require(head_blob == post_blob, f"F-CI52P production blob drift: {path}")
    print("FCI52P_EXACT_FVQ59_FIVE_PRODUCTION_BLOBS_PRESERVED=PASS")

    evidence = json.loads(Path("integration/f-ci/F-CI52P_EVIDENCE.json").read_text())
    require(evidence.get("source_postimage") == POSTIMAGE, "source postimage evidence drift")
    require(evidence.get("prepromotion_canonical") == PREIMAGE, "prepromotion canonical evidence drift")
    require(evidence.get("fci52_admission_head") == ADMISSION_HEAD, "admission head evidence drift")
    require(evidence.get("f_vq59_authority") == QUALIFICATION_AUTHORITY, "F-VQ59 authority evidence drift")
    require(evidence.get("r1_production_composition") == R1_PRODUCTION_COMPOSITION, "R1 production composition evidence drift")
    require(evidence.get("prepromotion_broad_run") == 34688109490, "prepromotion broad run provenance drift")
    require(evidence.get("prepromotion_failed_job") == 103538753724, "prepromotion failed job provenance drift")
    require(evidence.get("postpromotion_broad_run") == 34688308275, "postpromotion broad run provenance drift")
    require(evidence.get("postpromotion_failed_job") == 103539248733, "postpromotion failed job provenance drift")
    require(evidence.get("failure_line") == "FCI_CANONICAL_PRESERVATION_FAIL admitted dependency drift: src/runtime/mod_fmr_runtime_core.f90", "failure line drift")
    require(evidence.get("classification") == "STALE_MOVING_PRESERVATION_AUTHORITY_AFTER_QUALIFIED_SOURCE_ADMISSION", "failure classification drift")
    regressions = evidence.get("regression_classification", {})
    require(regressions and not any(regressions.values()), "evidence incorrectly reports a regression")
    routing = evidence.get("routing", {})
    require(routing.get("pm08d7_production_remediation_required") is False, "evidence incorrectly routes PM08D7 production remediation")
    require(routing.get("moving_preservation_reconciliation_required") is True, "evidence does not require moving preservation reconciliation")
    print("FCI52P_POSTPROMOTION_FAILURE_CLASSIFIED=PASS")

    changed = set(filter(None, git("diff", "--name-only", f"{POSTIMAGE}..HEAD").splitlines()))
    require(changed <= ALLOWED_BRANCH_DELTA, f"unexpected F-CI52P branch delta: {sorted(changed - ALLOWED_BRANCH_DELTA)}")
    require(".github/workflows/fci-canonical.yml" in changed, "moving preservation workflow not reconciled")
    print("FCI52P_GOVERNANCE_ONLY_BRANCH_DELTA=PASS")

    base_text = git("show", f"{POSTIMAGE}:{WORKFLOW.as_posix()}") + "\n"
    current_text = WORKFLOW.read_text()
    require(MARKER in base_text and MARKER in current_text, "moving-preservation job marker missing")
    base_prefix, base_suffix = base_text.split(MARKER, 1)
    cur_prefix, cur_suffix = current_text.split(MARKER, 1)
    require(cur_prefix == base_prefix, "historical/frozen workflow prefix changed")
    require(f"AUTH={OLD_MOVING_AUTH}" in base_suffix, "F-CI52 source postimage lacks expected stale moving authority")
    expected_suffix = base_suffix.replace(f"AUTH={OLD_MOVING_AUTH}", f"AUTH={POSTIMAGE}", 1)
    anchor = "          echo 'FCI50_MOVING_FGC17_TYPED_GROUNDWATER_INTERFACE_PRESERVATION=PASS'\n"
    marker = "          echo 'FCI52_MOVING_PM08D7_FIXED_WEIR_TRANSACTIONAL_RUNTIME_PRESERVATION=PASS'\n"
    require(anchor in expected_suffix, "FCI50 marker anchor missing")
    expected_suffix = expected_suffix.replace(anchor, anchor + marker, 1)
    require(cur_suffix == expected_suffix, "fci-canonical moving-preservation change exceeds exact F-CI52P reconciliation")
    require(f"AUTH={OLD_MOVING_AUTH}" not in cur_suffix, "stale moving authority retained")
    require(cur_suffix.count(marker) == 1, "F-CI52 moving preservation marker count is not exactly one")
    print("FCI52P_FROZEN_WORKFLOW_PREFIX_BYTE_IDENTITY=PASS")
    print("FCI52P_MOVING_AUTHORITY_ADVANCED_EXACTLY_ONCE=PASS")

    status = json.loads(Path("integration/f-ci/F-CI52P_STATUS.json").read_text())
    require(status.get("canonical_postimage") == POSTIMAGE, "status canonical postimage drift")
    require(status.get("prepromotion_canonical") == PREIMAGE, "status prepromotion canonical drift")
    require(status.get("fci52_admission_head") == ADMISSION_HEAD, "status admission head drift")
    state = status.get("state", {})
    require(state.get("production_source_changed_by_fci52p") is False, "status reports production source change")
    require(state.get("reference_changed_by_fci52p") is False, "status reports reference change")
    require(state.get("scientific_tolerance_changed") is False, "status reports tolerance change")
    require(state.get("solver_functionality_changed") is False, "status reports solver functionality change")
    require(state.get("mass_conservation_relaxed") is False, "status reports mass relaxation")
    require(state.get("moving_preservation_disabled_or_weakened") is False, "status reports weakened moving preservation")
    require(state.get("historical_frozen_authority_rewritten") is False, "status reports historical authority rewrite")
    require(state.get("fmr41_optional_state_layout_ownership_preserved") is True, "F-MR41 optional-state ownership is not preserved")
    print("FCI52P_STATUS_SCOPE_GUARDS=PASS")

    audit = json.loads(Path("integration/f-ci/F-CI52P_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall")
    require(audit.get("mass_conservation") == "HARD_UNCHANGED", "mass conservation audit")
    require(audit.get("production_source_changed") is False, "architecture audit production change")
    require(audit.get("reference_changed") is False, "architecture audit reference change")
    require(audit.get("scientific_tolerances_changed") is False, "architecture audit tolerance change")
    require(audit.get("solver_functionality_changed") is False, "architecture audit solver change")
    require(audit.get("moving_preservation_weakened") is False, "architecture audit moving preservation weakening")
    require(audit.get("historical_frozen_authority_rewritten") is False, "architecture audit historical rewrite")
    inv = audit.get("invariants", [])
    require([x.get("id") for x in inv] == list(range(1, 31)), "architecture invariant IDs")
    require(all(x.get("status") == "PASS" for x in inv), "architecture invariant failure")
    print("FCI52P_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI52P_MASS_CONSERVATION=HARD_UNCHANGED")
    print("FCI52P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
