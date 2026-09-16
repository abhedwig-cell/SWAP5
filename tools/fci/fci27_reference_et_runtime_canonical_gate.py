#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_CANONICAL = "f49e17c6627717d5dea181808a122f2e35960739"
FMR23_CLOSEOUT = "a0cf508581677d1af100d754bc9cb5e5d67ac84d"
FVQ36_CLOSEOUT = "9f39d3d621bc3254063af86efb4abd64525ef07f"
EXPECTED_PRE_SRC_TREE = "3f701f4b9e04eaf96f5ac44bba22b8e9879ebcba"
EXPECTED_POST_SRC_TREE = "4121255813971a360949efc3fb17ab6c8f87a799"
EXPECTED_REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
RUNTIME_SOURCE = "src/runtime/mod_fmr_reference_et_demand_binding.f90"
RUNTIME_SOURCE_BLOB = "8c679f911c9a82c498258224d83f5fce3cb09163"
ET_SOURCE = "src/process/mod_reference_et_demand_process.f90"
ET_SOURCE_BLOB = "f5e88ec5089fd3b57ac111065fab2aa32dde0fae"
ROOT_UPTAKE_BLOB = "e6134587cf3c0164bbe09f2f4c87aef6886aaeb3"
CROP_OWNER_BLOB = "31bb390a0b70bec0a3f525f1d704a2c53890f9b4"
FMR23_STATUS_BLOB = "3e2aef36f902e7525adabc133fddb3c26f31c78f"
FVQ36_STATUS_BLOB = "585f89307f6eeb5c3caf6bcb8c853bc66bce01c4"
FVQ36_QUALIFICATION_BLOB = "0fc9584c232a50ee215064a743e9c1adebbbf91a"
FCI24_STATUS_BLOB = "8493cd104a3aa0389f0f74e6506a93fe55b95472"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def quiet(*args: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def blob(rev: str, path: str) -> str:
    return git("rev-parse", f"{rev}:{path}")


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def require(condition: bool, label: str) -> None:
    if not condition:
        raise SystemExit(f"FCI27_FAIL {label}")
    print(f"FCI27_{label}=PASS")


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

    changed_src = [
        path
        for path in git("diff", "--name-only", f"{BASE_CANONICAL}..HEAD", "--", "src").splitlines()
        if path
    ]
    require(changed_src == [RUNTIME_SOURCE], "G05_EXACT_ONE_SOURCE_DELTA")
    require(blob("HEAD", "src") == EXPECTED_POST_SRC_TREE, "G06_EXACT_POST_SRC_TREE")
    require(blob("HEAD", "reference") == EXPECTED_REFERENCE_TREE, "G07_REFERENCE_TREE_UNCHANGED")
    require(quiet("diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "reference"), "G08_NO_REFERENCE_DELTA")

    require(blob("HEAD", RUNTIME_SOURCE) == RUNTIME_SOURCE_BLOB, "G09_RUNTIME_SOURCE_BLOB")
    require(blob(FMR23_CLOSEOUT, RUNTIME_SOURCE) == RUNTIME_SOURCE_BLOB, "G10_FMR23_SOURCE_AUTHORITY")
    require(blob(FVQ36_CLOSEOUT, RUNTIME_SOURCE) == RUNTIME_SOURCE_BLOB, "G11_FVQ36_SOURCE_AUTHORITY")
    require(quiet("diff", "--quiet", f"{FVQ36_CLOSEOUT}..HEAD", "--", "src"), "G12_FCI27_NO_NEW_SRC_CHANGE")

    require(blob("HEAD", ET_SOURCE) == ET_SOURCE_BLOB, "G13_ET_PROVIDER_LOCK")
    require(blob("HEAD", "src/process/mod_root_water_uptake_process.f90") == ROOT_UPTAKE_BLOB, "G14_ROOT_UPTAKE_OWNER_LOCK")
    require(blob("HEAD", "src/crop/mod_wofost_crop_owner_state.f90") == CROP_OWNER_BLOB, "G15_CROP_OWNER_LOCK")
    require(blob("HEAD", "integration/f-mr/F-MR23_STATUS.json") == FMR23_STATUS_BLOB, "G16_FMR23_STATUS_BLOB")
    require(blob("HEAD", "integration/f-vq/F-VQ36_STATUS.json") == FVQ36_STATUS_BLOB, "G17_FVQ36_STATUS_BLOB")
    require(blob("HEAD", "integration/f-vq/F-VQ36_QUALIFICATION.json") == FVQ36_QUALIFICATION_BLOB, "G18_FVQ36_EVIDENCE_BLOB")
    require(blob("HEAD", "integration/f-ci/F-CI24_STATUS.json") == FCI24_STATUS_BLOB, "G19_FCI24_STATUS_PRESERVED")

    fmr = load("integration/f-mr/F-MR23_STATUS.json")
    fvq = load("integration/f-vq/F-VQ36_STATUS.json")
    fvq_ev = load("integration/f-vq/F-VQ36_QUALIFICATION.json")
    fci24 = load("integration/f-ci/F-CI24_STATUS.json")
    plan = load("integration/f-ci/F-CI27_ADMISSION_PLAN.json")

    require(
        fmr.get("decision") == "RESTRICTED_REFERENCE_ET_GENERIC_TIME_RUNTIME_BINDING_READY_FOR_INDEPENDENT_QUALIFICATION"
        and fmr.get("candidate", {}).get("runtime_source_blob") == RUNTIME_SOURCE_BLOB
        and fmr.get("candidate", {}).get("qualified_ET_source_blob") == ET_SOURCE_BLOB
        and fmr.get("scope", {}).get("root_uptake_binding") is False
        and fmr.get("scope", {}).get("mass_ledger_binding") is False,
        "G20_FMR23_SCOPE_LOCK",
    )
    require(
        fvq.get("decision") == "QUALIFIED_INDEPENDENT_FMR23_RESTRICTED_REFERENCE_ET_GENERIC_TIME_RUNTIME_BINDING"
        and fvq.get("candidate_runtime_source_blob") == RUNTIME_SOURCE_BLOB
        and fvq.get("workflow_conclusion") == "success"
        and fvq.get("independent_grid_cases") == 13824
        and fvq.get("state", {}).get("root_uptake_bound") is False
        and fvq.get("state", {}).get("mass_ledger_bound") is False,
        "G21_FVQ36_ADMISSION_LOCK",
    )
    require(
        fvq_ev.get("decision") == "QUALIFIED_INDEPENDENT_FMR23_RESTRICTED_REFERENCE_ET_GENERIC_TIME_RUNTIME_BINDING"
        and fvq_ev.get("candidate", {}).get("runtime_source_blob") == RUNTIME_SOURCE_BLOB
        and fvq_ev.get("candidate", {}).get("production_source_changed_by_fvq36") is False
        and fvq_ev.get("architectural_qualification", {}).get("root_uptake_bound") is False
        and fvq_ev.get("architectural_qualification", {}).get("mass_ledger_bound") is False,
        "G22_FVQ36_EVIDENCE_LOCK",
    )
    require(
        fci24.get("decision") == "QUALIFIED_CLOSED_FPM06A_RESTRICTED_REFERENCE_ET_CANONICAL_SOURCE_ADMISSION"
        and fci24.get("state", {}).get("closed") is True
        and fci24.get("state", {}).get("production_source_admitted") is True
        and fci24.get("qualified_scope", {}).get("runtime_binding") is False,
        "G23_FCI24_BASE_AUTHORITY",
    )
    require(
        plan.get("candidate", {}).get("F_VQ36_closeout") == FVQ36_CLOSEOUT
        and plan.get("candidate", {}).get("production_source_blob") == RUNTIME_SOURCE_BLOB
        and plan.get("admission_scope", {}).get("root_uptake_binding_added") is False
        and plan.get("admission_scope", {}).get("ptra_ownership_reconciled") is False
        and plan.get("admission_scope", {}).get("mass_ledger_binding_added") is False
        and plan.get("admission_scope", {}).get("accepted_interval_rate_integration_added") is False,
        "G24_FCI27_SCOPE_NONCLAIMS",
    )

    print(f"FCI27_MODE={args.mode}")
    print("FCI27_REFERENCE_ET_RUNTIME_CANONICAL_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
