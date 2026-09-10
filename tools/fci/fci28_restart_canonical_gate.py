#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_CANONICAL = "0aa4f7ca88a1cd2f3cf7333a35946c4415d9258d"
CANDIDATE = "594f3e2acd80ff5c2caeb596ae52688adf0d3bd7"
OWNER_CLOSEOUT = "510ccd90af6386e3239e71ff6585ed56d6ef5fdb"
EXPECTED_PRE_SRC_TREE = "4121255813971a360949efc3fb17ab6c8f87a799"
EXPECTED_POST_SRC_TREE = "3fe4ccff367479e54ab5db106e5faf8b480d8ec0"
EXPECTED_REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
RESTART_SOURCE = "src/runtime/mod_fmr_committed_restart.f90"
RESTART_BLOB = "19ea410e0ed48e65b5d73887a8e1dba59c7c4f37"
CONTRACT_SOURCE = "src/runtime/mod_fmr_restart_state_contract.f90"
CONTRACT_BLOB = "f1359f97d02408d8b700b0c93fe961a6ba46742c"
ET_SOURCE = "src/process/mod_reference_et_demand_process.f90"
ET_SOURCE_BLOB = "f5e88ec5089fd3b57ac111065fab2aa32dde0fae"
ET_BINDING = "src/runtime/mod_fmr_reference_et_demand_binding.f90"
ET_BINDING_BLOB = "8c679f911c9a82c498258224d83f5fce3cb09163"
RECEIPT_SOURCE = "src/runtime/mod_fmr_accepted_commit_receipt.f90"
RECEIPT_BLOB = "6798b3296b426950bf028814585c3f5de9be950b"
FCI27_STATUS_BLOB = "f8059ea8d8aaad4451ab64c46d398bd77aa1cd9e"
FCI27_EVIDENCE_BLOB = "4a665dc57b98c2d10fda162c8b75f1d503518eab"
FMR23_STATUS_BLOB = "3e2aef36f902e7525adabc133fddb3c26f31c78f"
FVQ36_STATUS_BLOB = "585f89307f6eeb5c3caf6bcb8c853bc66bce01c4"
FVQ36_QUALIFICATION_BLOB = "0fc9584c232a50ee215064a743e9c1adebbbf91a"
FCI24_STATUS_BLOB = "8493cd104a3aa0389f0f74e6506a93fe55b95472"
FCI28_EVIDENCE_BLOB = "3831a0d532dc94c2402a375bae5bc5d080ab7553"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def quiet(*args: str) -> bool:
    return subprocess.run(["git", "-C", str(ROOT), *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def blob(rev: str, path: str) -> str:
    return git("rev-parse", f"{rev}:{path}")


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def require(condition: bool, label: str) -> None:
    if not condition:
        raise SystemExit(f"FCI28_FAIL {label}")
    print(f"FCI28_{label}=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("admission", "canonical"), required=True)
    args = parser.parse_args()

    require(quiet("merge-base", "--is-ancestor", BASE_CANONICAL, "HEAD"), "G01_BASE_IS_ANCESTOR")
    require(blob(BASE_CANONICAL, "src") == EXPECTED_PRE_SRC_TREE, "G02_PRE_SRC_TREE_LOCK")
    require(blob(BASE_CANONICAL, "reference") == EXPECTED_REFERENCE_TREE, "G03_PRE_REFERENCE_TREE_LOCK")

    if args.mode == "admission":
        live = git("rev-parse", "refs/remotes/origin/integration/f-ci-canonical")
        require(live == BASE_CANONICAL, "G04_LIVE_CANONICAL_REF_LOCK")
    else:
        require(quiet("merge-base", "--is-ancestor", BASE_CANONICAL, "HEAD"), "G04_CANONICAL_FORWARD_LINEAGE")

    expected = [RESTART_SOURCE, CONTRACT_SOURCE]
    changed = [p for p in git("diff", "--name-only", f"{BASE_CANONICAL}..HEAD", "--", "src").splitlines() if p]
    require(changed == expected, "G05_EXACT_TWO_SOURCE_DELTA")
    require(blob("HEAD", "src") == EXPECTED_POST_SRC_TREE, "G06_EXACT_POST_SRC_TREE")
    require(blob("HEAD", "reference") == EXPECTED_REFERENCE_TREE, "G07_REFERENCE_TREE_UNCHANGED")
    require(quiet("diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "reference"), "G08_NO_REFERENCE_DELTA")

    require(blob("HEAD", RESTART_SOURCE) == RESTART_BLOB, "G09_RESTART_SOURCE_BLOB")
    require(blob("HEAD", CONTRACT_SOURCE) == CONTRACT_BLOB, "G10_CONTRACT_SOURCE_BLOB")
    require(blob(CANDIDATE, RESTART_SOURCE) == RESTART_BLOB and blob(CANDIDATE, CONTRACT_SOURCE) == CONTRACT_BLOB, "G11_CANDIDATE_SOURCE_AUTHORITY")
    require(blob(OWNER_CLOSEOUT, RESTART_SOURCE) == RESTART_BLOB and blob(OWNER_CLOSEOUT, CONTRACT_SOURCE) == CONTRACT_BLOB, "G12_OWNER_CLOSEOUT_SOURCE_AUTHORITY")
    require(quiet("diff", "--quiet", f"{CANDIDATE}..HEAD", "--", "src"), "G13_NO_QUALIFICATION_SOURCE_MUTATION")

    require(blob("HEAD", ET_SOURCE) == ET_SOURCE_BLOB, "G14_ET_PROVIDER_PRESERVED")
    require(blob("HEAD", ET_BINDING) == ET_BINDING_BLOB, "G15_FCI27_ET_RUNTIME_PRESERVED")
    require(blob("HEAD", RECEIPT_SOURCE) == RECEIPT_BLOB, "G16_ACCEPTED_COMMIT_RECEIPT_PRESERVED")
    require(blob("HEAD", "integration/f-ci/F-CI27_STATUS.json") == FCI27_STATUS_BLOB, "G17_FCI27_STATUS_PRESERVED")
    require(blob("HEAD", "integration/f-ci/F-CI27_QUALIFICATION_EVIDENCE.json") == FCI27_EVIDENCE_BLOB, "G18_FCI27_EVIDENCE_PRESERVED")
    require(blob("HEAD", "integration/f-mr/F-MR23_STATUS.json") == FMR23_STATUS_BLOB, "G19_FMR23_STATUS_PRESERVED")
    require(blob("HEAD", "integration/f-vq/F-VQ36_STATUS.json") == FVQ36_STATUS_BLOB, "G20_FVQ36_STATUS_PRESERVED")
    require(blob("HEAD", "integration/f-vq/F-VQ36_QUALIFICATION.json") == FVQ36_QUALIFICATION_BLOB, "G21_FVQ36_EVIDENCE_PRESERVED")
    require(blob("HEAD", "integration/f-ci/F-CI24_STATUS.json") == FCI24_STATUS_BLOB, "G22_FCI24_AUTHORITY_PRESERVED")
    require(blob("HEAD", "integration/f-ci/F-CI28_QUALIFICATION_EVIDENCE.json") == FCI28_EVIDENCE_BLOB, "G23_FCI28_QUALIFICATION_EVIDENCE_LOCK")

    fci27 = load("integration/f-ci/F-CI27_STATUS.json")
    fci28 = load("integration/f-ci/F-CI28_STATUS.json")
    evidence = load("integration/f-ci/F-CI28_QUALIFICATION_EVIDENCE.json")
    require(
        fci27.get("decision") == "QUALIFIED_CLOSED_FMR23_RESTRICTED_REFERENCE_ET_GENERIC_TIME_RUNTIME_CANONICAL_ADMISSION"
        and fci27.get("state", {}).get("production_source_admitted") is True
        and fci27.get("qualified_scope", {}).get("root_uptake_binding") is False,
        "G24_FCI27_CANONICAL_AUTHORITY",
    )
    allowed_decisions = {
        "QUALIFIED_INDEPENDENT_FMR25_RESTRICTED_RESTART_ON_FCI27_POSTIMAGE",
        "QUALIFIED_CLOSED_FMR25_RESTRICTED_RESTART_CURRENT_CANONICAL_ADMISSION",
    }
    require(
        fci28.get("candidate") == CANDIDATE
        and fci28.get("decision") in allowed_decisions
        and fci28.get("state", {}).get("qualified") is True,
        "G25_FCI28_QUALIFICATION_STATUS",
    )
    if args.mode == "admission":
        require(fci28.get("state", {}).get("canonical_ref_advanced") is False, "G26_PRE_ADMISSION_STATE")
    else:
        require(fci28.get("state", {}).get("canonical_ref_advanced") in (False, True), "G26_CANONICAL_STATE_COMPATIBLE")
    require(
        evidence.get("decision") == "QUALIFIED_INDEPENDENT_FMR25_RESTRICTED_RESTART_ON_FCI27_POSTIMAGE"
        and evidence.get("restart_qualification", {}).get("exact_interval_mass_continuation") == "PASS"
        and evidence.get("restart_qualification", {}).get("malformed_concrete_state_rejected") == "PASS"
        and evidence.get("current_canonical_preservation", {}).get("F_VQ36_grid_cases") == 13824,
        "G27_FCI28_EVIDENCE_SCOPE",
    )

    print(f"FCI28_MODE={args.mode}")
    print("FCI28_RESTART_CANONICAL_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
