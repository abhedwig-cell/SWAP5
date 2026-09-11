#!/usr/bin/env python3
"""Fail-closed validator for F-DOC04 bounded RB1 reference/temporal traceability."""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "0c25d97bd180378a916fbb14a1e45768af9ec63a"
BASE_TREE = "5ccdb626116555402fbfb6fe521ce823a08b4dc8"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SOURCE_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
FRB02 = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
FSI19 = "d3a1bc8eef243b6109af8871398c06e1840fb367"
FSI19_CANDIDATE = "8e6121ecfcdfb71c79a111153835d4400d37ff89"
FVQ34 = "df9b1123ba33ece022ce6649e70dcb538e44837f"
FVQ34_TESTED = "31e3f85ae83fe8bab9554da5467de0598446c0bd"
FCI21 = "697755068253cfb5a2f838c63894e1609a85ff51"
FCI40 = "d81ef430ebaa601469a165dfc5b9866b813b71aa"

REGISTRY = ROOT / "docs/scientific/registries/rb1-reference-temporal-traceability.json"
DOC = ROOT / "docs/scientific/F-DOC04_RB1_REFERENCE_TEMPORAL_TRACEABILITY.md"
STATUS = ROOT / "integration/f-doc/F-DOC04_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC04_INVARIANT_AUDIT.json"

CAPS = ["RB1-SW-REFERENCE", "RB1-TIME-REFERENCE"]
ALLOWED = (
    "docs/scientific/F-DOC04_",
    "docs/scientific/registries/rb1-reference-temporal-traceability.json",
    "integration/f-doc/F-DOC04_",
    "tools/docs/validate_fdoc04_rb1_reference_temporal_traceability.py",
    ".github/workflows/fdoc04-rb1-reference-temporal-traceability.yml",
)
SOURCE_PINS = {
    "src/adapter/mod_reference_richards_legacy_binding.f90": "6eda1fec1bd03c03a1c0a8f2df29a273f70d962f",
    "src/solver/mod_soil_water_solver_contract.f90": "dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0",
    "src/solver/mod_reference_linear_solver.f90": "b292d284e5549049eac1c80df4cc30008154eb96",
    "src/solver/mod_reference_richards_state_binding.f90": "e68d88382c6502c571713cc97fddd4e18434e271",
    "src/solver/mod_reference_richards_temporal_indicator.f90": "fe8f87d11257d4c6bc019f1d628ac41ba3106d4e",
    "src/runtime/mod_fmr_serialized_reference_backend.f90": "9af5a494526810324dc00706b444e448e770cba9",
}
TEMPORAL_DEPENDENCIES = [
    "src/transaction/mod_transaction_reference.f90",
    "src/transaction/mod_fkt_temporal_indicator_history.f90",
    "src/runtime/mod_fmr_runtime_core.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
    "src/solver/mod_reference_richards_temporal_indicator.f90",
    "src/runtime/mod_canonical_contracts.f90",
    "src/runtime/mod_canonical_interval_runtime.f90",
    "src/kernel/mod_kernel_transactions.f90",
]


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC04_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC04_{marker}=PASS")


def git_json(commit: str, path: str) -> dict:
    return json.loads(sh("git", "show", f"{commit}:{path}"))


# Documentation-only delta from the exact reconciled F-DOC03 authority.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "FDOC03_BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC03_BASE_ANCESTRY")
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
require(bool(changed), "BOUNDED_DELTA_NONEMPTY")
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED), "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Exact frozen source identity and representative source mappings.
require(sh("git", "rev-parse", f"{SOURCE}^{{tree}}") == SOURCE_TREE, "RB1_SOURCE_TREE")
for path, expected in SOURCE_PINS.items():
    require(sh("git", "rev-parse", f"{SOURCE}:{path}") == expected, "SOURCE_BLOB_" + path.split("/")[-1].replace(".", "_").upper())
print("FDOC04_SOURCE_PINS_EXACT=PASS")

# F-SI19 is only a qualified seam, and its exact seam blob is preserved in RB1.
fsi = git_json(FSI19, "integration/f-si/F-SI19_STATUS.json")
require(fsi["QUALIFIED"] is True, "FSI19_QUALIFIED")
require(fsi["reference_mode"] == "PRESERVED_FULL_ACCURACY", "FSI19_REFERENCE_MODE")
require(fsi["claim_limit"].startswith("No bounded-cost threshold"), "FSI19_SCOPE_LIMIT_PRESENT")
require(sh("git", "rev-parse", f"{FSI19_CANDIDATE}:src/solver/mod_reference_linear_solver.f90") == SOURCE_PINS["src/solver/mod_reference_linear_solver.f90"], "FSI19_SEAM_BLOB_PRESERVED")

# F-VQ34 must remain explicit-budget, fail-closed and non-universal.
fvq = git_json(FVQ34, "integration/f-vq/F-VQ34_CLOSEOUT.json")
require(fvq["tested_head"] == FVQ34_TESTED, "FVQ34_TESTED_HEAD")
require(fvq["workflow_run"] == 34364081068 and fvq["workflow_conclusion"] == "success", "FVQ34_WORKFLOW_METADATA")
sem = fvq["qualified_semantics"]
require(sem["formula"] == "C_h=B_inf/H_budget", "FVQ34_FORMULA")
require(sem["budget_owner"] == "explicit numerical configuration", "FVQ34_BUDGET_OWNER")
require(sem["default_H_budget"] is None, "FVQ34_NO_DEFAULT_H_BUDGET")
require(sem["invalid_or_missing_budget"] == "certificate unavailable, fail closed", "FVQ34_FAIL_CLOSED")
require(sem["hard_mass_before_certificate"] is True and sem["certificate_can_override_mass_failure"] is False, "FVQ34_HARD_MASS_PRECEDENCE")
nonclaims = "\n".join(fvq["hard_nonclaims"])
require("does not select, recommend or qualify a numeric H_budget" in nonclaims, "FVQ34_NO_NUMERIC_APPLICATION_BUDGET")
require("does not establish a universal temporal tolerance or default H_budget" in nonclaims, "FVQ34_NO_UNIVERSAL_TEMPORAL_TOLERANCE")

# F-CI21 preserves the failed F-VQ33 gate and materializes only the qualified policy.
fci21 = git_json(FCI21, "integration/f-ci/F-CI21_STATUS.json")
require(fci21["state"]["qualified"] is True and fci21["state"]["closed"] is True, "FCI21_CLOSED_QUALIFIED")
require(fci21["component_status"]["F_VQ34_remediated_policy_replay_qualified"] is True, "FCI21_VQ34_REPLAY")
require(fci21["component_status"]["F_VQ33_remains_failed"] is True, "FCI21_VQ33_REMAINS_FAILED")
require(fci21["negative_evidence"]["reinterpreted_as_pass"] is False and fci21["negative_evidence"]["used_as_positive_evidence"] is False, "FCI21_NEGATIVE_PROVENANCE_PRESERVED")
require(fci21["qualified_policy_scope"]["default_H_budget"] is None, "FCI21_NO_DEFAULT_H_BUDGET")
require(fci21["hard_nonclaims"]["application_H_budget_selected"] is False, "FCI21_NO_APPLICATION_BUDGET")
require(fci21["hard_nonclaims"]["universal_temporal_tolerance_selected"] is False, "FCI21_NO_UNIVERSAL_TOLERANCE")

# F-RB01 temporal authority runner is an immutable two-part authority/preservation gate.
require(sh("git", "rev-parse", f"{FRB01}:tests/frb01/run_frb01_temporal_authority.sh") == "4e3a789f649a5b427a3fe0d89d01f09dc7277cfe", "FRB01_TEMPORAL_RUNNER_BLOB")
runner = sh("git", "show", f"{FRB01}:tests/frb01/run_frb01_temporal_authority.sh")
require(f"AUTH={FCI21}" in runner and f"FCI40={FCI40}" in runner, "FRB01_TEMPORAL_AUTHORITIES")
for marker in ("FRB01_FROZEN_TEMPORAL_SCIENTIFIC_AUTHORITY=PASS", "FRB01_CURRENT_TEMPORAL_DEPENDENCY_PRESERVATION=PASS", "FRB01_TEMPORAL_AUTHORITY_AND_CURRENT_PRESERVATION=PASS"):
    require(marker in runner, "FRB01_MARKER_" + marker.split("=")[0])
for path in TEMPORAL_DEPENDENCIES:
    require(sh("git", "rev-parse", f"{SOURCE}:{path}") == sh("git", "rev-parse", f"{FCI40}:{path}"), "TEMPORAL_PRESERVED_" + path.split("/")[-1].replace(".", "_").upper())
print("FDOC04_TEMPORAL_DEPENDENCY_SURFACE_PRESERVED=PASS")

# Registry semantics and release denominator.
registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
require(registry["schema_version"] == "1.0" and registry["work_unit"] == "F-DOC04", "REGISTRY_IDENTITY")
require(registry["base_authority"]["fdoc03"] == BASE, "REGISTRY_FDOC03_BASE")
require(registry["base_authority"]["rb1_scientific_source"] == SOURCE, "REGISTRY_SOURCE")
require(registry["base_authority"]["rb1_qualification"] == FRB01 and registry["base_authority"]["rb1_release"] == FRB02, "REGISTRY_RELEASE_AUTHORITIES")
require(registry["canonical_source_pins"] == SOURCE_PINS, "REGISTRY_SOURCE_PINS")
require(registry["governance"]["capability_ids"] == CAPS and registry["governance"]["capability_count"] == 2, "EXACT_TWO_CAPABILITIES")
require([c["capability_id"] for c in registry["capabilities"]] == CAPS, "CAPABILITY_ORDER")
require(registry["governance"]["release_pass_does_not_infer_missing_theory"] is True, "NO_RELEASE_TO_THEORY_PROMOTION")
require(registry["governance"]["historical_negative_evidence_remains_negative"] is True, "NEGATIVE_EVIDENCE_GOVERNANCE")
require(registry["governance"]["status_a_ready_claimed"] is False and registry["governance"]["status_a_compliant_claimed"] is False and registry["governance"]["status_aa_compliant_claimed"] is False, "NO_STATUS_A_AA_CLAIM")

caps = {c["capability_id"]: c for c in registry["capabilities"]}
sw = caps["RB1-SW-REFERENCE"]
time = caps["RB1-TIME-REFERENCE"]
require(sw["theory_authority"]["status"] == "GAP_NO_SINGLE_CONTROLLED_T1_AUTHORITY_IDENTIFIED", "SW_REFERENCE_T1_GAP_EXPLICIT")
require(sw["verification"]["status"] == "SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED" and sw["fully_traced_claimed"] is False, "SW_REFERENCE_T11_PARTIAL")
require(time["scientific_policy_authority"]["authority"] == f"F-VQ34@{FVQ34}", "TIME_REFERENCE_FVQ34_AUTHORITY")
require(time["scientific_policy_authority"]["default_H_budget"] is None, "TIME_REFERENCE_NO_DEFAULT_H_BUDGET")
require(time["scientific_policy_authority"]["application_budget_selection"] == "OPEN_EXTERNAL_POLICY_DEPENDENCY", "TIME_REFERENCE_APPLICATION_BUDGET_OPEN")
require(time["negative_provenance"]["must_remain_failed"] is True and time["negative_provenance"]["used_as_positive_evidence"] is False, "TIME_REFERENCE_FVQ33_NEGATIVE")
require(time["fully_traced_claimed"] is False, "TIME_REFERENCE_NOT_FULLY_TRACED")

matrix = git_json(FRB01, "release/f-rb01/RB1_CAPABILITY_MATRIX.json")
require(matrix["required_denominator"] == 15, "RB1_DENOMINATOR_15")
mm = {x["capability_id"]: x for x in matrix["capabilities"]}
require(mm["RB1-SW-REFERENCE"]["integrated_release_gate"] == "PASS", "RB1_SW_REFERENCE_PASS")
require(mm["RB1-TIME-REFERENCE"]["integrated_release_gate"] == "PASS", "RB1_TIME_REFERENCE_PASS")
require("no universal application accuracy budget" in mm["RB1-TIME-REFERENCE"]["limitations"], "RB1_TIME_NO_UNIVERSAL_ACCURACY_BUDGET")

# Documentation must preserve the same nonclaims.
doc = DOC.read_text(encoding="utf-8")
for required in ("default_H_budget = null", "does not establish a universal temporal tolerance", "does not claim Status A readiness", "F-VQ33 is not reinterpreted as a pass", "complete T1 theory binding"):
    require(required in doc, "DOC_CONTAINS_" + required[:20].replace(" ", "_").replace("-", "_").replace("=", "_").upper())

status = json.loads(STATUS.read_text(encoding="utf-8"))
require(status["work_unit"] == "F-DOC04" and status["base"] == BASE, "STATUS_IDENTITY")
require(status["capabilities"] == CAPS, "STATUS_TWO_CAPABILITIES")
for key in ("production_delta", "reference_delta", "physics_delta", "solver_delta", "acceptance_threshold_delta", "performance_delta"):
    require(status["scope_holds"][key] == "NONE", "STATUS_" + key.upper() + "_NONE")
require(status["traceability_boundary"]["fully_traced_claimed"] is False, "STATUS_NOT_FULLY_TRACED")
require(status["traceability_boundary"]["universal_H_budget_claimed"] is False, "STATUS_NO_UNIVERSAL_H_BUDGET")
require(status["traceability_boundary"]["application_H_budget_selected"] is False, "STATUS_NO_APPLICATION_H_BUDGET")

# 30-invariant no-adverse-delta audit, with mass hard unchanged.
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
items = audit["items"]
require(len(items) == 30 and [x["id"] for x in items] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x["result"] == "PASS" for x in items), "INVARIANTS_30_OF_30_PASS")
require(audit["summary"] == {"total": 30, "pass": 30, "fail": 0, "overall": "30_OF_30_NO_ADVERSE_DELTA"}, "INVARIANT_SUMMARY")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "HARD_MASS_UNCHANGED")

out = {
    "work_unit": "F-DOC04",
    "head": sh("git", "rev-parse", "HEAD"),
    "tree": sh("git", "rev-parse", "HEAD^{tree}"),
    "fdoc03_base": BASE,
    "rb1_scientific_source": SOURCE,
    "frb01": FRB01,
    "frb02": FRB02,
    "capabilities": CAPS,
    "source_pins": SOURCE_PINS,
    "f_vq34": FVQ34,
    "f_ci21": FCI21,
    "f_ci40": FCI40,
    "production_delta": False,
    "reference_delta": False,
    "fully_traced": False,
    "universal_H_budget": False,
    "application_H_budget_selected": False,
    "sw_reference_t1": "OPEN",
    "sw_reference_complete_t11": "OPEN",
    "time_application_budget_policy": "OPEN_EXTERNAL_DEPENDENCY",
    "invariant_audit": "30_OF_30_NO_ADVERSE_DELTA"
}
(ROOT / "_fdoc04_rb1_reference_temporal_traceability_evidence.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print("FDOC04_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_BOUNDED_RB1_REFERENCE_TEMPORAL_TRACEABILITY_WITH_EXPLICIT_GAPS")
