#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "2efba343d425770e5d581d8137cd60e83d8b7ac5"
ROOT_ATTRIBUTION = "src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
ROOT_ATTRIBUTION_BLOB = "fe5a06c9af59308cdad86c5126379f413591b0cd"
DIVDRA_BINDING = "src/runtime/mod_fmr_divdra_runtime_binding.f90"
DIVDRA_BLOB = "e4737fb6f00a11ed16e34bee44b3442ac84b31aa"
FCI33_GATE = "tools/fci/fci33_divdra_runtime_canonical_gate.py"
FCI33_RUNNER = "tests/fci/run_fci33_divdra_runtime_canonical_admission.sh"
FCI33R_GATE = "tools/fci/fci33r_current_postimage_gate.py"
FCI33R_RUNNER = "tests/fci/run_fci33_current_postimage_reconciliation.sh"
FCI33_WORKFLOW = ".github/workflows/fci33-fmr33-divdra-runtime-canonical-admission.yml"
FCI33R_WORKFLOW = ".github/workflows/fci33r-current-canonical-postimage-reconciliation.yml"
CANONICAL_WORKFLOW = ".github/workflows/fci-canonical.yml"
FCI34_WORKFLOW = ".github/workflows/fci34-fmr31-root-attribution-canonical-admission.yml"
FCI34_RUNNER = "tests/fci/run_fci34_fmr31_root_attribution_canonical_admission.sh"


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def quiet(*args: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def require(ok: bool, label: str) -> None:
    if not ok:
        raise SystemExit(f"FCI34G_FAIL {label}")
    print(f"FCI34G_{label}=PASS")


def unchanged_from_base(path: str) -> bool:
    try:
        return git("rev-parse", f"HEAD:{path}") == git("rev-parse", f"{BASE}:{path}")
    except subprocess.CalledProcessError:
        return False


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

    require(quiet("diff", "--quiet", f"{BASE}..HEAD", "--", "src"), "G03_ZERO_POSTIMAGE_SRC_DELTA")
    require(quiet("diff", "--quiet", f"{BASE}..HEAD", "--", "reference"), "G04_ZERO_POSTIMAGE_REFERENCE_DELTA")
    require(git("rev-parse", f"HEAD:{ROOT_ATTRIBUTION}") == ROOT_ATTRIBUTION_BLOB, "G05_ROOT_ATTRIBUTION_BLOB_FROZEN")
    require(git("rev-parse", f"HEAD:{DIVDRA_BINDING}") == DIVDRA_BLOB, "G06_DIVDRA_BINDING_BLOB_FROZEN")

    require(unchanged_from_base(FCI33_GATE), "G07_HISTORICAL_FCI33_GATE_UNCHANGED")
    require(unchanged_from_base(FCI33_RUNNER), "G08_HISTORICAL_FCI33_RUNNER_UNCHANGED")
    require(unchanged_from_base(FCI33R_GATE), "G09_HISTORICAL_FCI33R_GATE_UNCHANGED")
    require(unchanged_from_base(FCI33R_RUNNER), "G10_HISTORICAL_FCI33R_RUNNER_UNCHANGED")
    require(unchanged_from_base(FCI34_WORKFLOW), "G11_FCI34_DEDICATED_WORKFLOW_UNCHANGED")
    require(unchanged_from_base(FCI34_RUNNER), "G12_FCI34_SCIENTIFIC_RUNNER_UNCHANGED")

    fci33_workflow = (ROOT / FCI33_WORKFLOW).read_text(encoding="utf-8")
    fci33r_workflow = (ROOT / FCI33R_WORKFLOW).read_text(encoding="utf-8")
    require("qualification/f-ci33-fmr33-divdra-runtime-canonical-admission" in fci33_workflow, "G13_FCI33_QUALIFICATION_TRIGGER_PRESERVED")
    require("qualification/f-ci33r-current-canonical-postimage-reconciliation" in fci33r_workflow, "G14_FCI33R_QUALIFICATION_TRIGGER_PRESERVED")
    require("- integration/f-ci-canonical" not in fci33_workflow, "G15_FCI33_MOVING_CANONICAL_TRIGGER_RETIRED")
    require("- integration/f-ci-canonical" not in fci33r_workflow, "G16_FCI33R_MOVING_CANONICAL_TRIGGER_RETIRED")

    canonical = (ROOT / CANONICAL_WORKFLOW).read_text(encoding="utf-8")
    require("Current F-CI34 root-attribution canonical postimage authority gate" in canonical, "G17_CANONICAL_POINTER_IS_FCI34")
    require("run_fci34g_current_postimage_reconciliation.sh" in canonical, "G18_CANONICAL_RUNNER_IS_FCI34G")
    require("FCI34G_MODE: canonical" in canonical, "G19_CANONICAL_MODE_IS_CURRENT")
    require("Current F-CI33 restricted DIVDRA runtime canonical source authority gate" not in canonical, "G20_STALE_FCI33_CURRENT_POINTER_REMOVED")
    require("run_fci33_divdra_runtime_canonical_admission.sh" not in canonical.split("current-restricted-canonical-postimage:", 1)[-1], "G21_STALE_FCI33_CURRENT_RUNNER_REMOVED")
    require(ROOT_ATTRIBUTION_BLOB in canonical, "G22_CANONICAL_ROOT_ATTRIBUTION_LOCK_PRESENT")
    require(DIVDRA_BLOB in canonical, "G23_CANONICAL_DIVDRA_LOCK_PRESENT")

    changed = [p for p in git("diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
    allowed = {
        ".github/workflows/fci-canonical.yml",
        ".github/workflows/fci33-fmr33-divdra-runtime-canonical-admission.yml",
        ".github/workflows/fci33r-current-canonical-postimage-reconciliation.yml",
        ".github/workflows/fci34g-current-canonical-postimage-governance.yml",
        "tools/fci/fci34g_current_postimage_gate.py",
        "tests/fci/run_fci34g_current_postimage_reconciliation.sh",
        "integration/f-ci/F-CI34G_RECONCILIATION_PLAN.json",
        "integration/f-ci/F-CI34G_EVIDENCE.json",
        "integration/f-ci/F-CI34G_STATUS.json",
        "integration/f-ci/F-CI34_STATUS.json",
    }
    require(set(changed).issubset(allowed), "G24_GOVERNANCE_DELTA_ALLOWLIST")

    print(f"FCI34G_MODE={args.mode}")
    print("FCI34G_CURRENT_CANONICAL_POSTIMAGE_GOVERNANCE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
