#!/usr/bin/env python3
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOCKED_SOURCE = "11eb34ea3afe8f5dda0515c28d7e08428dd2e272"
LOCKED_TREE = "04afa5d5a90671a7791174708ae6bf48b272c83f"
FVQ14_HEAD = "69e581000bfcf15c74f2c4be5fa089502f794821"
PACKAGE_BLOB = "a7935b2871cb88a8f854ac6b54797b81c3b40c5d"
PACKAGE_PATH = ROOT / "integration/f-vq/F-VQ14_REFERENCE_RUN_PACKAGE.json"


def run(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond, msg):
    if not cond:
        raise SystemExit("FMQ23_AUDIT_FAIL " + msg)


def main():
    require(run("git", "rev-parse", f"{LOCKED_SOURCE}^{{tree}}") == LOCKED_TREE, "locked production tree")
    changed_src = run("git", "diff", "--name-only", LOCKED_SOURCE, "HEAD", "--", "src")
    require(changed_src == "", "production src changed: " + changed_src)
    require(run("git", "merge-base", "--is-ancestor", FVQ14_HEAD, "HEAD") == "", "F-VQ14 ancestry")
    require(run("git", "hash-object", str(PACKAGE_PATH)) == PACKAGE_BLOB, "immutable F-VQ14 package blob")

    package = json.loads(PACKAGE_PATH.read_text())
    require(package["locked_production_source_sha"] == LOCKED_SOURCE, "package source SHA")
    require(package["source_tree"] == LOCKED_TREE, "package source tree")
    require(package["fmq23_consumable"] is True, "fmq23_consumable")
    require(package["admission_scope"]["fmq23_release"] is True, "fmq23_release")
    require(package["admission_scope"]["parallel_reference_backend_admitted"] is False, "parallel backend must remain closed")
    require(package["per_quantity_comparison"]["criterion"] == "EXACT_BITWISE_IDENTITY_NO_NEW_SCIENTIFIC_TOLERANCE", "scientific criterion")
    require(package["per_quantity_comparison"]["maximum_observed_scientific_difference"] == 0.0, "scientific difference")
    require(package["authoritative_mass_terms_unrounded"]["complete"] is True, "mass complete")
    require(package["authoritative_mass_terms_unrounded"]["missing_contribution_mask"] == 0, "mass missing mask")
    require(package["authoritative_mass_terms_unrounded"]["residual"]["bits"] == 0, "authoritative residual")
    require(package["independent_mass_residual"]["pass"] is True, "independent residual")

    serialized_path = ROOT / "src/runtime/mod_fmr_serialized_reference_backend.f90"
    deterministic_path = ROOT / "src/runtime/mod_fmr_deterministic_runtime.f90"
    core_path = ROOT / "src/runtime/mod_fmr_runtime_core.f90"
    serialized = serialized_path.read_text().lower()
    deterministic = deterministic_path.read_text().lower()
    core = core_path.read_text().lower()

    require("fmr_backend_serialized_reference" in core, "serialized backend ID missing")
    require("procedure, public :: run_trial => fmr_serialized_backend_run_trial" in serialized, "serialized per-column trial entrypoint missing")
    require("type(fmr_logical_column_t), intent(in) :: column" in serialized, "serialized entrypoint no logical column")
    require("subroutine fmr_run_deterministic(columns" in deterministic, "synthetic multi-column comparator entrypoint missing")
    require("type(fmr_logical_column_t), intent(in) :: columns(:)" in deterministic, "synthetic multi-column array contract missing")

    production_runtime = list((ROOT / "src/runtime").glob("*.f90"))
    multi_serialized_candidates = []
    for path in production_runtime:
        text = path.read_text().lower()
        has_columns_array = bool(re.search(r"type\s*\(\s*fmr_logical_column_t\s*\).*::\s*columns\s*\(:\)", text))
        has_serialized = "fmr_backend_serialized_reference" in text or "fmr_serialized_reference_backend_t" in text
        if has_columns_array and has_serialized:
            multi_serialized_candidates.append(path.relative_to(ROOT).as_posix())

    blocker_present = len(multi_serialized_candidates) == 0
    require(blocker_present, "existing production serialized multi-column route found; F-MQ23 matrix must be reassessed: " + ",".join(multi_serialized_candidates))

    report = {
        "schema_version": 1,
        "work_unit": "F-MQ23",
        "source_lock": "PASS",
        "fvq14_package_lock": "PASS",
        "scientific_oracle_consumption_precondition": "PASS",
        "production_source_changed": False,
        "serialized_per_column_run_trial": True,
        "synthetic_production_multicolumn_dispatch": True,
        "production_serialized_multicolumn_dispatch_candidates": multi_serialized_candidates,
        "blocker": {
            "id": "FMQ23-B01",
            "status": "CONFIRMED",
            "owner": "F-MR",
            "statement": "No production multi-column serialized-reference dispatch/orchestration entrypoint exists. The admitted real-physics backend exposes only a per-column run_trial, while the existing production multi-column dispatcher is tied to the deterministic synthetic backend.",
            "qualification_fix_allowed": False
        },
        "physical_execution": "SKIPPED_FAIL_CLOSED_BEFORE_G03",
        "qualification_decision": "BLOCKED_PRODUCTION_SERIALIZED_MULTICOLUMN_RUNTIME_ENTRYPOINT_MISSING"
    }
    out = ROOT / "build" / "fmq23"
    out.mkdir(parents=True, exist_ok=True)
    (out / "capability_audit.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))
    print("FMQ23_CAPABILITY_AUDIT PASS_FAIL_CLOSED_BLOCKER_CONFIRMED")


if __name__ == "__main__":
    main()
