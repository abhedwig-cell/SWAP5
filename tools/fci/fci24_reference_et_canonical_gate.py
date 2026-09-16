#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_CANONICAL = "df435824de175e3f868b680aab2cd0a395aa19ff"
FPM06A_CLOSEOUT = "c1bbe73cd0deced17f979a601fd6169036d7076b"
FVQ35_CLOSEOUT = "a978fa20fb42ce7d83b052cda9d8246111df05a5"
EXPECTED_PRE_SRC_TREE = "3446aa1d0d80861b22f7e74c7ad51bcedef4f479"
EXPECTED_POST_SRC_TREE = "3f701f4b9e04eaf96f5ac44bba22b8e9879ebcba"
EXPECTED_REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
ET_SOURCE = "src/process/mod_reference_et_demand_process.f90"
ET_BLOB = "f5e88ec5089fd3b57ac111065fab2aa32dde0fae"
ROOT_UPTAKE_BLOB = "e6134587cf3c0164bbe09f2f4c87aef6886aaeb3"
CROP_OWNER_BLOB = "31bb390a0b70bec0a3f525f1d704a2c53890f9b4"
FPM06A_STATUS_BLOB = "fe1a910b1915a6c1368dbdaede9b3b19f766bfc4"
FVQ35_STATUS_BLOB = "713743b496bd7d5dfc894ab30c2ba26d694eed0e"
FCI23_STATUS_BLOB = "af89cf53c129467ca9480b535488dd9cab008327"


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
        raise SystemExit(f"FCI24_FAIL {label}")
    print(f"FCI24_{label}=PASS")


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

    changed_src = [p for p in git("diff", "--name-only", f"{BASE_CANONICAL}..HEAD", "--", "src").splitlines() if p]
    require(changed_src == [ET_SOURCE], "G05_EXACT_ONE_SOURCE_DELTA")
    require(blob("HEAD", "src") == EXPECTED_POST_SRC_TREE, "G06_EXACT_POST_SRC_TREE")
    require(blob("HEAD", "reference") == EXPECTED_REFERENCE_TREE, "G07_REFERENCE_TREE_UNCHANGED")
    require(quiet("diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "reference"), "G08_NO_REFERENCE_DELTA")

    require(blob("HEAD", ET_SOURCE) == ET_BLOB, "G09_ET_SOURCE_BLOB")
    require(blob(FPM06A_CLOSEOUT, ET_SOURCE) == ET_BLOB, "G10_FPM06A_SOURCE_AUTHORITY")
    require(blob(FVQ35_CLOSEOUT, ET_SOURCE) == ET_BLOB, "G11_FVQ35_SOURCE_AUTHORITY")
    require(quiet("diff", "--quiet", f"{FVQ35_CLOSEOUT}..HEAD", "--", "src"), "G12_FCI24_NO_NEW_SRC_CHANGE")

    require(blob("HEAD", "src/process/mod_root_water_uptake_process.f90") == ROOT_UPTAKE_BLOB, "G13_ROOT_UPTAKE_OWNER_LOCK")
    require(blob("HEAD", "src/crop/mod_wofost_crop_owner_state.f90") == CROP_OWNER_BLOB, "G14_CROP_OWNER_LOCK")
    require(blob("HEAD", "integration/f-pm/F-PM06A_CANDIDATE_STATUS.json") == FPM06A_STATUS_BLOB, "G15_FPM06A_STATUS_BLOB")
    require(blob("HEAD", "integration/f-vq/F-VQ35_STATUS.json") == FVQ35_STATUS_BLOB, "G16_FVQ35_STATUS_BLOB")
    require(blob("HEAD", "integration/f-ci/F-CI23_STATUS.json") == FCI23_STATUS_BLOB, "G17_FCI23_STATUS_PRESERVED")

    fpm = load("integration/f-pm/F-PM06A_CANDIDATE_STATUS.json")
    fvq = load("integration/f-vq/F-VQ35_STATUS.json")
    fvq_ev = load("integration/f-vq/F-VQ35_QUALIFICATION.json")
    fci23 = load("integration/f-ci/F-CI23_STATUS.json")

    require(
        fpm.get("decision") == "STRUCTURAL_CANDIDATE_READY_FOR_INDEPENDENT_FVQ"
        and fpm.get("lineage", {}).get("production_source_blob") == ET_BLOB
        and fpm.get("state", {}).get("runtime_bound") is False,
        "G18_FPM06A_SCOPE_LOCK",
    )
    require(
        fvq.get("decision") == "QUALIFIED_INDEPENDENT_FPM06A_RESTRICTED_STATELESS_REFERENCE_ET_DEMAND_SCIENTIFIC_ADMISSION"
        and fvq.get("candidate_source_blob") == ET_BLOB
        and fvq.get("workflow_conclusion") == "success"
        and fvq.get("independent_grid_cases") == 1700
        and fvq.get("state", {}).get("runtime_bound") is False,
        "G19_FVQ35_ADMISSION_LOCK",
    )
    require(
        fvq_ev.get("decision") == "QUALIFIED_INDEPENDENT_FPM06A_RESTRICTED_STATELESS_REFERENCE_ET_DEMAND_SCIENTIFIC_ADMISSION"
        and fvq_ev.get("candidate", {}).get("source_blob") == ET_BLOB
        and fvq_ev.get("candidate", {}).get("production_source_changed_by_fvq35") is False,
        "G20_FVQ35_EVIDENCE_LOCK",
    )
    require(
        fci23.get("state", {}).get("closed") is True
        and fci23.get("state", {}).get("post_promotion_canonical_workflow_passed") is True
        and fci23.get("state", {}).get("production_source_changed") is False,
        "G21_FCI23_BASE_AUTHORITY",
    )

    plan = load("integration/f-ci/F-CI24_ADMISSION_PLAN.json")
    require(
        plan.get("candidate", {}).get("F_VQ35_closeout") == FVQ35_CLOSEOUT
        and plan.get("candidate", {}).get("production_source_blob") == ET_BLOB
        and plan.get("admission_scope", {}).get("runtime_binding_added") is False
        and plan.get("admission_scope", {}).get("mass_ledger_binding_added") is False,
        "G22_FCI24_SCOPE_NONCLAIMS",
    )

    print(f"FCI24_MODE={args.mode}")
    print("FCI24_REFERENCE_ET_CANONICAL_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
