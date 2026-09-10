#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "8c02470ddd9afbc2965ed2a92d23493c0d768bfd"
SRC_TREE = "7576837368e4244c3c2a1bbf9867df8d4e58811a"
REFERENCE_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
CANDIDATE = "src/runtime/mod_fmr_divdra_runtime_binding.f90"
CANDIDATE_BLOB = "e4737fb6f00a11ed16e34bee44b3442ac84b31aa"
FCI32_GATE = "tools/fci/fci32_divdra_canonical_gate.py"
FCI32_RUNNER = "tests/fci/run_fci32_divdra_canonical_admission.sh"
CANONICAL_WORKFLOW = ".github/workflows/fci-canonical.yml"
FCI33_GATE = "tools/fci/fci33_divdra_runtime_canonical_gate.py"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def quiet(*args: str) -> bool:
    return subprocess.run(["git", "-C", str(ROOT), *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def require(ok: bool, label: str) -> None:
    if not ok:
        raise SystemExit(f"FCI33R_FAIL {label}")
    print(f"FCI33R_{label}=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("repair", "canonical"), required=True)
    args = parser.parse_args()

    require(quiet("merge-base", "--is-ancestor", BASE, "HEAD"), "G01_BASE_IS_ANCESTOR")
    live = git("rev-parse", "refs/remotes/origin/integration/f-ci-canonical")
    if args.mode == "repair":
        require(live == BASE, "G02_LIVE_CANONICAL_REPAIR_BASE_LOCK")
    else:
        require(live == git("rev-parse", "HEAD"), "G02_CANONICAL_HEAD_IDENTITY")

    require(quiet("diff", "--quiet", f"{BASE}..HEAD", "--", "src"), "G03_ZERO_REPAIR_SRC_DELTA")
    require(quiet("diff", "--quiet", f"{BASE}..HEAD", "--", "reference"), "G04_ZERO_REPAIR_REFERENCE_DELTA")
    require(git("rev-parse", "HEAD:src") == SRC_TREE, "G05_SRC_TREE_FROZEN")
    require(git("rev-parse", "HEAD:reference") == REFERENCE_TREE, "G06_REFERENCE_TREE_FROZEN")
    require(git("rev-parse", f"HEAD:{CANDIDATE}") == CANDIDATE_BLOB, "G07_CANDIDATE_BLOB_FROZEN")
    require(git("rev-parse", f"HEAD:{FCI32_GATE}") == git("rev-parse", f"{BASE}:{FCI32_GATE}"), "G08_FCI32_GATE_UNCHANGED")
    require(git("rev-parse", f"HEAD:{FCI32_RUNNER}") == git("rev-parse", f"{BASE}:{FCI32_RUNNER}"), "G09_FCI32_RUNNER_UNCHANGED")

    workflow = (ROOT / CANONICAL_WORKFLOW).read_text(encoding="utf-8")
    require("Current F-CI33 restricted DIVDRA runtime canonical source authority gate" in workflow, "G10_CURRENT_POINTER_IS_FCI33")
    require("run_fci33_divdra_runtime_canonical_admission.sh" in workflow, "G11_CURRENT_RUNNER_IS_FCI33")
    require("FCI33_MODE: canonical" in workflow, "G12_CURRENT_MODE_IS_CANONICAL")
    require(f"HEAD:src)\" = {SRC_TREE}" in workflow, "G13_CURRENT_SRC_TREE_LOCK")
    require(f"HEAD:reference)\" = {REFERENCE_TREE}" in workflow, "G14_CURRENT_REFERENCE_TREE_LOCK")
    require(f"HEAD:{CANDIDATE})\" = {CANDIDATE_BLOB}" in workflow, "G15_CURRENT_CANDIDATE_LOCK")

    gate = (ROOT / FCI33_GATE).read_text(encoding="utf-8")
    require('path == ".github/workflows/fci-canonical.yml"' in gate, "G16_FCI33_ALLOWS_CANONICAL_AGGREGATOR")
    require('path.startswith("integration/f-ci/F-CI33R_")' in gate, "G17_FCI33_ALLOWS_REPAIR_STATUS")
    require('path == "tools/fci/fci33r_current_postimage_gate.py"' in gate, "G18_FCI33_ALLOWS_REPAIR_GATE")

    changed = [p for p in git("diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
    allowed = {
        "integration/f-ci/F-CI33R_STATUS.json",
        "tools/fci/fci33_divdra_runtime_canonical_gate.py",
        "tools/fci/fci33r_current_postimage_gate.py",
        "tests/fci/run_fci33_current_postimage_reconciliation.sh",
        ".github/workflows/fci33r-current-canonical-postimage-reconciliation.yml",
        ".github/workflows/fci-canonical.yml",
    }
    require(set(changed).issubset(allowed), "G19_REPAIR_DELTA_ALLOWLIST")

    print(f"FCI33R_MODE={args.mode}")
    print("FCI33R_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
