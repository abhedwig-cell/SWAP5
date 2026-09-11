#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

POSTIMAGE = "0b284b5f4e224c5f76d7d78b9dbb51c99514479d"
PREIMAGE = "82280e350ea7514cc9f394db882d5cb3ef25b18c"
ADMISSION_HEAD = "effb42a36cf369293825484598fa17c53f4a2250"
OLD_MOVING_AUTH = "e765d96ee80af0629fb399e18bf58124dade7641"
FMR41_SOURCE = "50b8bd32b03946d947b9c8b87a17192684843b6e"
WORKFLOW = Path(".github/workflows/fci-canonical.yml")
MARKER = "  current-restricted-canonical-preservation:\n"
EXPECTED_BLOBS = {
    "src/runtime/mod_fmr_runtime_core.f90": "88adf19e274956ab0f97fe6b4f6307fbfb453790",
    "src/runtime/mod_fmr_serialized_reference_backend.f90": "2364c765935813675dee0d2838a7ce183d81f560",
    "src/runtime/mod_fmr_restart_state_contract.f90": "4a9c1644665c02de77c82e4b5fa2baaaf0a1fb6d",
}
ALLOWED_BRANCH_DELTA = {
    ".github/workflows/fci-canonical.yml",
    ".github/workflows/fci48p-current-canonical-postimage-reconciliation.yml",
    "integration/f-ci/F-CI48P_ARCHITECTURE_AUDIT.json",
    "integration/f-ci/F-CI48P_EVIDENCE.json",
    "integration/f-ci/F-CI48P_STATUS.json",
    "tests/fci/run_fci48p_current_canonical_postimage_reconciliation.py",
}


def git(*args: str) -> str:
    cp = subprocess.run(["git", *args], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return cp.stdout.strip()


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit(f"FCI48P_FAIL: {message}")


def main() -> None:
    canonical = git("rev-parse", "origin/integration/f-ci-canonical")
    require(canonical == POSTIMAGE, f"canonical race: expected {POSTIMAGE}, got {canonical}")
    print("FCI48P_CANONICAL_POSTIMAGE_PIN=PASS")

    parents = git("rev-list", "--parents", "-n", "1", POSTIMAGE).split()
    require(parents == [POSTIMAGE, PREIMAGE, ADMISSION_HEAD], f"unexpected F-CI48 merge parents: {parents}")
    print("FCI48P_TRUE_TWO_PARENT_FCI48_MERGE=PASS")

    prod_ref_delta = git("diff", "--name-only", f"{POSTIMAGE}..HEAD", "--", "src", "reference")
    require(prod_ref_delta == "", f"production/reference delta after promotion: {prod_ref_delta}")
    require(git("rev-parse", "HEAD:src") == git("rev-parse", f"{POSTIMAGE}:src"), "src tree changed")
    require(git("rev-parse", "HEAD:reference") == git("rev-parse", f"{POSTIMAGE}:reference"), "reference tree changed")
    print("FCI48P_PRODUCTION_REFERENCE_POSTIMAGE_IMMUTABLE=PASS")

    for path, blob in EXPECTED_BLOBS.items():
        require(git("rev-parse", f"HEAD:{path}") == blob, f"postimage blob drift: {path}")
        require(git("rev-parse", f"{FMR41_SOURCE}:{path}") == blob, f"F-MR41 donor blob drift: {path}")
    print("FCI48P_EXACT_FMR41_THREE_BLOBS_PRESERVED=PASS")

    status = json.loads(Path("integration/f-ci/F-CI48_STATUS.json").read_text())
    require(status.get("decision") == "QUALIFIED_FMR41_TYPED_OPTIONAL_STATE_LAYOUT_FOR_CURRENT_CANONICAL_ADMISSION", "F-CI48 decision drift")
    fg = status.get("first_green_admission", {})
    require(fg.get("head") == "cdc1e175a2b90a784eac53758d551ba0020a057d", "F-CI48 first-green head drift")
    require(fg.get("run") == 34648706383, "F-CI48 first-green run drift")
    require(fg.get("fmr39_runtime_output_sha256") == "cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942", "F-CI48 F-MR39 output SHA drift")
    print("FCI48P_PREPROMOTION_ADMISSION_AUTHORITY_PINNED=PASS")

    evidence = json.loads(Path("integration/f-ci/F-CI48P_EVIDENCE.json").read_text())
    require(evidence.get("failed_broad_canonical_run") == 34649007705, "postpromotion failed-run provenance drift")
    require(evidence.get("failed_job") == 103426962103, "postpromotion failed-job provenance drift")
    require(evidence.get("failure_line") == "FCI_CANONICAL_PRESERVATION_FAIL admitted dependency drift: src/runtime/mod_fmr_runtime_core.f90", "failure classification provenance drift")
    require(evidence.get("classification") == "STALE_MOVING_PRESERVATION_AUTHORITY_AFTER_QUALIFIED_SOURCE_ADMISSION", "failure classification drift")
    require(evidence.get("production_regression_detected") is False, "evidence incorrectly claims production regression")
    require(evidence.get("scientific_regression_detected") is False, "evidence incorrectly claims scientific regression")
    print("FCI48P_POSTPROMOTION_FAILURE_CLASSIFIED=PASS")

    changed = set(filter(None, git("diff", "--name-only", f"{POSTIMAGE}..HEAD").splitlines()))
    require(changed <= ALLOWED_BRANCH_DELTA, f"unexpected F-CI48P branch delta: {sorted(changed - ALLOWED_BRANCH_DELTA)}")
    require(".github/workflows/fci-canonical.yml" in changed, "moving preservation workflow not reconciled")
    print("FCI48P_GOVERNANCE_ONLY_BRANCH_DELTA=PASS")

    base_text = git("show", f"{POSTIMAGE}:{WORKFLOW.as_posix()}") + "\n"
    current_text = WORKFLOW.read_text()
    require(MARKER in base_text and MARKER in current_text, "moving-preservation job marker missing")
    base_prefix, base_suffix = base_text.split(MARKER, 1)
    cur_prefix, cur_suffix = current_text.split(MARKER, 1)
    require(cur_prefix == base_prefix, "historical/frozen workflow prefix changed")
    require(f"AUTH={OLD_MOVING_AUTH}" in base_suffix, "promoted F-CI48 workflow lacks expected stale authority")
    expected_suffix = base_suffix.replace(f"AUTH={OLD_MOVING_AUTH}", f"AUTH={POSTIMAGE}", 1)
    anchor = "          echo 'FCI47_MOVING_PRESERVATION_AUTHORITY_RECONCILED=PASS'\n"
    require(anchor in expected_suffix, "FCI47 marker anchor missing")
    expected_suffix = expected_suffix.replace(anchor, anchor + "          echo 'FCI48_MOVING_TYPED_OPTIONAL_STATE_LAYOUT_PRESERVATION=PASS'\n", 1)
    require(cur_suffix == expected_suffix, "fci-canonical moving-preservation change exceeds exact F-CI48P reconciliation")
    require(f"AUTH={OLD_MOVING_AUTH}" not in cur_suffix, "stale moving authority retained")
    print("FCI48P_FROZEN_WORKFLOW_PREFIX_BYTE_IDENTITY=PASS")
    print("FCI48P_MOVING_AUTHORITY_ADVANCED_EXACTLY_ONCE=PASS")

    audit = json.loads(Path("integration/f-ci/F-CI48P_ARCHITECTURE_AUDIT.json").read_text())
    require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "architecture audit overall")
    require(audit.get("mass_conservation") == "HARD_UNCHANGED", "mass conservation audit")
    require(audit.get("production_source_changed") is False, "architecture audit production change")
    require(audit.get("reference_changed") is False, "architecture audit reference change")
    require(audit.get("scientific_tolerances_changed") is False, "architecture audit tolerance change")
    inv = audit.get("invariants", [])
    require([x.get("id") for x in inv] == list(range(1, 31)), "architecture invariant IDs")
    require(all(x.get("status") == "PASS" for x in inv), "architecture invariant failure")
    print("FCI48P_ARCHITECTURE_INVARIANTS=PASS:30_OF_30")
    print("FCI48P_MASS_CONSERVATION=HARD_UNCHANGED")
    print("FCI48P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION=PASS")


if __name__ == "__main__":
    main()
