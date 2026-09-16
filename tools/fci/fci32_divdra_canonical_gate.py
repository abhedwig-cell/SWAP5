#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_CANONICAL = "e3964ec0ef312f974461aeac70fb9bc5720803e3"
OWNER_CLOSEOUT = "70a66a768e64760ecfd43702535a848b6d834d61"
FVQ47_SCIENTIFIC_CLOSEOUT = "9aa52a6e6e3b85119434fc97f056f4c9918447fd"
FVQ47_ADMIN = "12fef763fbf664972a9f26a02b666def5009fc1a"
EXPECTED_PRE_SRC_TREE = "d33c525c6d6f4d2ab19bec8341d732b98d6daebf"
EXPECTED_POST_SRC_TREE = "f18948aef9a8755903951475078f218024ad3c42"
EXPECTED_REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
DIVDRA_SOURCE = "src/process/mod_drainage_spatial_distribution.f90"
DIVDRA_BLOB = "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a"
HYDRAULIC_VIEW = "src/solver/mod_process_hydraulic_view.f90"
HYDRAULIC_VIEW_BLOB = "d7d85fe71ced0d94b29c8d9395859ae1834f7dd6"
SOLVER_CONTRACT = "src/solver/mod_soil_water_solver_contract.f90"
SOLVER_CONTRACT_BLOB = "dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0"
FVQ47_STATUS = "integration/f-vq/F-VQ47_STATUS.json"
PLAN = "integration/f-ci/F-CI32_QUALIFICATION_PLAN.json"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def quiet(*args: str) -> bool:
    return subprocess.run(["git", "-C", str(ROOT), *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def blob(rev: str, path: str) -> str:
    return git("rev-parse", f"{rev}:{path}")


def require(condition: bool, label: str) -> None:
    if not condition:
        raise SystemExit(f"FCI32_FAIL {label}")
    print(f"FCI32_{label}=PASS")


def ensure_authority(commit: str, branch: str) -> None:
    if quiet("cat-file", "-e", f"{commit}^{{commit}}"):
        return
    subprocess.check_call(["git", "-C", str(ROOT), "fetch", "--no-tags", "origin", branch])
    require(quiet("cat-file", "-e", f"{commit}^{{commit}}"), f"FETCH_{branch.replace('/', '_').upper()}")


def show_json(rev: str, path: str) -> dict:
    return json.loads(git("show", f"{rev}:{path}"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("admission", "canonical"), required=True)
    args = parser.parse_args()

    ensure_authority(OWNER_CLOSEOUT, "work/f-pm08br-lev2comp-boundary-seam-remediation")
    ensure_authority(FVQ47_ADMIN, "qualification/f-vq47-fpm08br-spatial-distribution-requalification")

    require(quiet("merge-base", "--is-ancestor", BASE_CANONICAL, "HEAD"), "G01_BASE_IS_ANCESTOR")
    require(blob(BASE_CANONICAL, "src") == EXPECTED_PRE_SRC_TREE, "G02_PRE_SRC_TREE_LOCK")
    require(blob(BASE_CANONICAL, "reference") == EXPECTED_REFERENCE_TREE, "G03_PRE_REFERENCE_TREE_LOCK")

    if args.mode == "admission":
        live = git("rev-parse", "refs/remotes/origin/integration/f-ci-canonical")
        require(live == BASE_CANONICAL, "G04_LIVE_CANONICAL_REF_LOCK")
    else:
        require(quiet("merge-base", "--is-ancestor", BASE_CANONICAL, "HEAD"), "G04_CANONICAL_FORWARD_LINEAGE")

    changed_src = [p for p in git("diff", "--name-only", f"{BASE_CANONICAL}..HEAD", "--", "src").splitlines() if p]
    require(changed_src == [DIVDRA_SOURCE], "G05_EXACT_ONE_SOURCE_DELTA")
    require(blob("HEAD", "src") == EXPECTED_POST_SRC_TREE, "G06_EXACT_POST_SRC_TREE")
    require(blob("HEAD", "reference") == EXPECTED_REFERENCE_TREE, "G07_REFERENCE_TREE_UNCHANGED")
    require(quiet("diff", "--quiet", f"{BASE_CANONICAL}..HEAD", "--", "reference"), "G08_NO_REFERENCE_DELTA")

    require(blob("HEAD", DIVDRA_SOURCE) == DIVDRA_BLOB, "G09_DIVDRA_SOURCE_BLOB")
    require(blob(OWNER_CLOSEOUT, DIVDRA_SOURCE) == DIVDRA_BLOB, "G10_OWNER_SOURCE_AUTHORITY")
    require(blob("HEAD", HYDRAULIC_VIEW) == HYDRAULIC_VIEW_BLOB, "G11_HYDRAULIC_VIEW_LOCK")
    require(blob(BASE_CANONICAL, HYDRAULIC_VIEW) == HYDRAULIC_VIEW_BLOB, "G12_BASE_HYDRAULIC_VIEW_LOCK")
    require(blob(OWNER_CLOSEOUT, HYDRAULIC_VIEW) == HYDRAULIC_VIEW_BLOB, "G13_OWNER_HYDRAULIC_VIEW_LOCK")
    require(blob("HEAD", SOLVER_CONTRACT) == SOLVER_CONTRACT_BLOB, "G14_SOLVER_CONTRACT_LOCK")

    fvq = show_json(FVQ47_ADMIN, FVQ47_STATUS)
    require(fvq.get("scientific_closeout_head") == FVQ47_SCIENTIFIC_CLOSEOUT, "G15_FVQ47_CLOSEOUT_LOCK")
    require(fvq.get("candidate_closeout") == OWNER_CLOSEOUT and fvq.get("candidate_source_blob") == DIVDRA_BLOB, "G16_FVQ47_CANDIDATE_LOCK")
    require(fvq.get("status") == "QUALIFIED_REMEDIATED_RESTRICTED_DIVDRA_SPATIAL_DISTRIBUTION_AND_LEV2COMP_BOUNDARY_SEAM_EQUIVALENCE", "G17_FVQ47_DECISION_LOCK")
    state = fvq.get("state", {})
    require(state.get("scientifically_qualified") is True and state.get("architecture_audited_all_30") is True, "G18_FVQ47_QUALIFICATION_LOCK")
    require(state.get("runtime_admission_qualified") is False and state.get("canonical_admission_qualified") is False, "G19_FVQ47_SCOPE_BOUNDARY")
    close = fvq.get("closeout_verification", {})
    require(close.get("conclusion") == "success" and close.get("src_delta_files") == 0 and close.get("reference_delta_files") == 0, "G20_FVQ47_EXACT_CLOSEOUT_VERIFIED")

    plan = json.loads((ROOT / PLAN).read_text(encoding="utf-8"))
    scope = plan.get("admission_scope", {})
    require(plan.get("clean_base") == BASE_CANONICAL and plan.get("source_authority", {}).get("production_blob") == DIVDRA_BLOB, "G21_FCI32_PLAN_LOCK")
    require(scope.get("runtime_binding") is False and scope.get("runtime_composition") is False and scope.get("new_drainage_physics") is False and scope.get("scientific_requalification") is False, "G22_FCI32_NONCLAIMS")
    require(plan.get("mass_governance", {}).get("mass_conservation_absolute") is True and plan.get("mass_governance", {}).get("configurable_mass_tolerance_allowed") is False, "G23_MASS_GOVERNANCE_LOCK")

    print(f"FCI32_MODE={args.mode}")
    print("FCI32_DIVDRA_CANONICAL_SOURCE_ADMISSION_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
