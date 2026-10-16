#!/usr/bin/env python3
"""Conservative, non-executing RossFast impact plan for one Git revision delta.

This is a selection aid, never scientific evidence or a full F-CI receipt.
"""
import argparse
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

ROSS_PATHS = {
    "src/solver/mod_rossfast_d3r_soil_water_solver.f90",
    "src/solver/mod_rossfast_d3r_table_provider.f90",
    "src/solver/mod_rossfast_d3r_table_kernel.f90",
    "src/runtime/mod_rossfast_d3r_model_binding.f90",
    "src/runtime/mod_rossfast_d3r_execution_policy.f90",
    "src/runtime/mod_fmr_rossfast_solver_selection_binding.f90",
    "src/solver/mod_soil_water_solver_contract.f90",
    "src/runtime/mod_fmr_soil_water_application_host.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
}
# These independently owned production process files do not define RossFast's
# implementation/contract. Unrecognized changes are REVIEW, never a skip.
PROCESS_PREFIXES = (
    "src/crop/", "src/meteo/", "src/solute/", "src/nutrient/",
    "src/root/", "src/irrigation/",
)
OTHER_SAFE_PREFIXES = ("docs/", "integration/audits/")
ROSS_TEST_PREFIXES = ("tests/f-ross/", "tests/fross/")
def classify(paths):
    paths = sorted(set(paths))
    if not paths:
        return "NOT_SELECTED_IMPACT", "No tracked changes"
    direct = [p for p in paths if p in ROSS_PATHS or p.startswith(ROSS_TEST_PREFIXES)]
    unknown = [p for p in paths if p not in direct and (not p.startswith(PROCESS_PREFIXES + OTHER_SAFE_PREFIXES) or ".." in pathlib.PurePosixPath(p).parts)]
    if unknown:
        return "REVIEW_REQUIRED", "Unclassified dependency or execution surface: " + ", ".join(unknown)
    if direct:
        return "SELECT_FOCUSED_ROSSFAST", "RossFast implementation/contract/test changed: " + ", ".join(direct)
    return "NOT_SELECTED_IMPACT", "Only independent process/documentation surfaces changed; validate changed physics and composition separately"

def changed_paths(base, head):
    # Three-dot delta includes the merge base. Fail closed on git errors.
    proc = subprocess.run(
        ["git", "diff", "--name-only", "--no-renames", "--diff-filter=ACDMRTUXB", f"{base}...{head}", "--"],
        cwd=ROOT, check=True, capture_output=True, text=True,
    )
    return [s for s in proc.stdout.splitlines() if s]

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base", required=True, help="Known upstream/candidate base commit")
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("--paths", nargs="*", help="Direct classification test only; does not inspect git")
    args = ap.parse_args()
    try:
        paths = args.paths if args.paths is not None else changed_paths(args.base, args.head)
    except subprocess.CalledProcessError as exc:
        print(json.dumps({"component": "RossFast", "decision": "REVIEW_REQUIRED", "reason": "Could not establish git delta", "error": str(exc)}, sort_keys=True))
        return 2
    decision, reason = classify(paths)
    print(json.dumps({"component": "RossFast", "decision": decision, "reason": reason, "changed_paths": sorted(set(paths)), "full_fci_pass": False, "test_pass": False}, sort_keys=True))
    return 0

if __name__ == "__main__":
    sys.exit(main())
