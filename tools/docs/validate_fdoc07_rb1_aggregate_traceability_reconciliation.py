#!/usr/bin/env python3
"""Fail-closed aggregate validator for F-DOC07."""
from __future__ import annotations

import collections
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "c20c0fd4c53ef65f3c8d375362908a25f0855a4b"
BASE_TREE = "28c16b13d30c6445772c1a90a6e2d83bbd0c03b4"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
REGISTRY = ROOT / "docs/scientific/registries/rb1-aggregate-traceability-reconciliation.json"
DOC = ROOT / "docs/scientific/F-DOC07_RB1_AGGREGATE_TRACEABILITY_RECONCILIATION.md"
STATUS = ROOT / "integration/f-doc/F-DOC07_STATUS.json"
CLOSEOUT = ROOT / "integration/f-doc/F-DOC07_CLOSEOUT.json"
AUDIT = ROOT / "integration/f-doc/F-DOC07_INVARIANT_AUDIT.json"

AUTHORITIES = {
    "F-DOC03": {
        "head": "0c25d97bd180378a916fbb14a1e45768af9ec63a",
        "status_blob": "7cac1ea40fe489cd16bb366cad26870c1ececedd",
        "path": "integration/f-doc/F-DOC03_STATUS.json",
        "run": 34596210450,
        "decision": "QUALIFIED_BOUNDED_RB1_CORE_TRACEABILITY_POPULATION_WITH_EXPLICIT_GAPS",
    },
    "F-DOC04": {
        "head": "a703747ce1991c5601b76a84f04969b602298268",
        "status_blob": "ac5dbba8fdc454a5fda4a5450415fede130af386",
        "path": "integration/f-doc/F-DOC04_STATUS.json",
        "run": 34610822444,
        "decision": "QUALIFIED_BOUNDED_RB1_REFERENCE_TEMPORAL_TRACEABILITY_WITH_EXPLICIT_GAPS",
    },
    "F-DOC05": {
        "head": "919f228d8aedc1029b5080bb019fbe61d2e1d7c6",
        "status_blob": "d9bc41819613b6b7b9be74a009f46ea4c89e6945",
        "path": "integration/f-doc/F-DOC05_STATUS.json",
        "run": 34612402892,
        "decision": "QUALIFIED_BOUNDED_RB1_EXECUTION_RESTART_TRACEABILITY_WITH_EXPLICIT_GAPS",
    },
    "F-DOC06": {
        "head": "c20c0fd4c53ef65f3c8d375362908a25f0855a4b",
        "status_blob": "25be319c1eb5caa7a46bae87f2cfe4863c0f2598",
        "path": "integration/f-doc/F-DOC06_STATUS.json",
        "run": 34620809727,
        "decision": "QUALIFIED_BOUNDED_RB1_ET_ROOT_SURFACE_EVAP_TRACEABILITY_WITH_EXPLICIT_GAPS",
    },
}
ALLOWED = (
    ".github/workflows/fdoc07-rb1-aggregate-traceability-reconciliation.yml",
    "docs/scientific/F-DOC07_",
    "docs/scientific/registries/rb1-aggregate-traceability-reconciliation.json",
    "integration/f-doc/F-DOC07_",
    "tools/docs/validate_fdoc07_rb1_aggregate_traceability_reconciliation.py",
)


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC07_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC07_{marker}=PASS")


def git_json(commit: str, path: str) -> dict:
    return json.loads(sh("git", "show", f"{commit}:{path}"))


def blob(commit: str, path: str) -> str:
    return sh("git", "rev-parse", f"{commit}:{path}")


# Exact base and documentation-only delta.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "FDOC06_BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC06_BASE_ANCESTRY")
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
require(bool(changed), "BOUNDED_DELTA_NONEMPTY")
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED), "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Exact immutable population authorities.
statuses: dict[str, dict] = {}
all_caps: list[str] = []
for work_unit, spec in AUTHORITIES.items():
    require(blob(spec["head"], spec["path"]) == spec["status_blob"], work_unit.replace("-", "_") + "_STATUS_BLOB")
    x = git_json(spec["head"], spec["path"])
    statuses[work_unit] = x
    require(x["work_unit"] == work_unit, work_unit.replace("-", "_") + "_IDENTITY")
    decision = x.get("decision", x.get("decision_if_exact_head_ci_green"))
    require(decision == spec["decision"], work_unit.replace("-", "_") + "_DECISION")
    require(x["scope_holds"]["production_delta"] == "NONE", work_unit.replace("-", "_") + "_NO_PRODUCTION_DELTA")
    require(x["scope_holds"]["reference_delta"] == "NONE", work_unit.replace("-", "_") + "_NO_REFERENCE_DELTA")
    all_caps.extend(x["capabilities"])

# Exact partition and frozen release denominator.
counts = collections.Counter(all_caps)
require(len(all_caps) == 15, "POPULATION_ASSIGNMENT_COUNT_15")
require(len(counts) == 15, "POPULATION_UNIQUE_CAPABILITY_COUNT_15")
require(all(v == 1 for v in counts.values()), "NO_DUPLICATE_ASSIGNMENTS")
rb1 = git_json(FRB01, "release/f-rb01/RB1_CAPABILITY_MATRIX.json")
rb1_ids = [c["capability_id"] for c in rb1["capabilities"]]
require(rb1["required_denominator"] == 15, "RB1_DENOMINATOR_15")
require(rb1["summary"]["required_integrated_pass"] == 15, "RB1_RELEASE_PASS_15")
require(all(c["integrated_release_gate"] == "PASS" for c in rb1["capabilities"]), "RB1_ALL_REQUIRED_RELEASE_GATES_PASS")
require(set(all_caps) == set(rb1_ids), "EXACT_RB1_CAPABILITY_SET")
require(set(counts) == set(rb1_ids), "NO_UNASSIGNED_REQUIRED_CAPABILITY")

# Key maturity boundaries must remain fail-closed after aggregation.
require(statuses["F-DOC03"]["traceability_boundary"]["fully_traced_claimed"] is False, "FDOC03_NOT_FULLY_TRACED")
require(statuses["F-DOC03"]["traceability_boundary"]["status_a_ready_claimed"] is False, "FDOC03_NO_STATUS_A_READY")
require(statuses["F-DOC04"]["traceability_boundary"]["universal_H_budget_claimed"] is False, "FDOC04_NO_UNIVERSAL_H_BUDGET")
require(statuses["F-DOC04"]["traceability_boundary"]["application_H_budget_selected"] is False, "FDOC04_NO_APPLICATION_H_BUDGET_SELECTION")
require(statuses["F-DOC05"]["traceability_boundary"]["fully_traced_claimed"] is False, "FDOC05_NOT_FULLY_TRACED")
require(statuses["F-DOC05"]["traceability_boundary"]["t12_application_validation_claimed"] is False, "FDOC05_NO_T12_VALIDATION")
require(statuses["F-DOC06"]["traceability_boundary"]["fully_traced_claimed"] is False, "FDOC06_NOT_FULLY_TRACED")
require(statuses["F-DOC06"]["traceability_boundary"]["surface_evaporation_throughput_scaling_claimed"] is False, "FDOC06_NO_SURFACE_THROUGHPUT")
require(statuses["F-DOC06"]["traceability_boundary"]["surface_evaporation_performance_debt_reopened"] is False, "FDOC06_PERFORMANCE_DEBT_NOT_REOPENED")

# F-DOC01/F-DOC02 external quality boundary remains authoritative.
require(blob(BASE, "integration/f-doc/F-DOC01_STATUS.json") == "8d5cbc29af162932bc489c1896bbdc16724f34ba", "FDOC01_STATUS_BLOB")
require(blob(BASE, "integration/f-doc/F-DOC02_STATUS.json") == "2b51205b3e6ed954267daefcd052cf5018b02451", "FDOC02_STATUS_BLOB")
fdoc01 = git_json(BASE, "integration/f-doc/F-DOC01_STATUS.json")
fdoc02 = git_json(BASE, "integration/f-doc/F-DOC02_STATUS.json")
require(fdoc01["status_a_boundary"]["ready_for_status_a_review"] is False, "FDOC01_STATUS_A_REVIEW_BLOCKED")
require(fdoc01["status_a_boundary"]["formal_2024_reconciliation"] == "PENDING_CONTROLLED_COPY", "FDOC01_WRQA2024_PENDING")
require(fdoc02["status_a_boundary"]["ready_for_status_a_review"] is False, "FDOC02_STATUS_A_REVIEW_BLOCKED")
require(fdoc02["status_a_boundary"]["formal_2024_reconciliation"] == "PENDING_CONTROLLED_COPY", "FDOC02_WRQA2024_PENDING")
require(fdoc02["traceability_population"]["required_capabilities_indexed"] == 15, "FDOC02_INDEXED_15")

# Aggregate registry must exactly encode the mechanical partition.
registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
require(registry["work_unit"] == "F-DOC07" and registry["base"] == BASE, "REGISTRY_IDENTITY")
require(registry["coverage"]["required_denominator"] == 15, "REGISTRY_DENOMINATOR_15")
require(registry["coverage"]["covered_exactly_once"] == 15, "REGISTRY_COVERED_15")
require(registry["coverage"]["duplicate_assignments"] == 0, "REGISTRY_NO_DUPLICATES")
require(registry["coverage"]["unassigned_required_capabilities"] == 0, "REGISTRY_NO_UNASSIGNED")
require(registry["coverage"]["traceability_maturity_claim"] == "BOUNDED_WITH_EXPLICIT_GAPS_NOT_FULLY_TRACED", "REGISTRY_MATURITY_BOUND")
for entry in registry["population_authorities"]:
    spec = AUTHORITIES[entry["work_unit"]]
    require(entry["head"] == spec["head"] and entry["status_blob"] == spec["status_blob"] and entry["exact_head_run"] == spec["run"], "REGISTRY_AUTHORITY_" + entry["work_unit"].replace("-", "_"))
    require(entry["capabilities"] == statuses[entry["work_unit"]]["capabilities"], "REGISTRY_CAPABILITIES_" + entry["work_unit"].replace("-", "_"))
require(set(registry["capability_to_population_work_unit"]) == set(rb1_ids), "REGISTRY_MAP_EXACT_15")
for cap, owner in registry["capability_to_population_work_unit"].items():
    require(cap in statuses[owner]["capabilities"], "REGISTRY_OWNER_" + cap.replace("-", "_"))
require(registry["status_a_boundary"]["ready_for_status_a_review"] is False, "REGISTRY_NO_STATUS_A_READY")
require(registry["status_a_boundary"]["status_a_compliant"] is False, "REGISTRY_NO_STATUS_A_COMPLIANCE")
require(registry["status_a_boundary"]["status_aa_compliant"] is False, "REGISTRY_NO_STATUS_AA_COMPLIANCE")
require(registry["status_a_boundary"]["formal_2024_reconciliation"] == "PENDING_CONTROLLED_COPY", "REGISTRY_WRQA2024_PENDING")

# Human-facing documentation must preserve the central distinctions.
doc = DOC.read_text(encoding="utf-8")
for phrase in (
    "15/15 capability population coverage",
    "does **not** mean `FULLY_TRACED`",
    "T12 application-class validation remains open",
    "PENDING_CONTROLLED_COPY",
    "ready_for_status_a_review = false",
    "No universal `H_budget`",
    "call-local copy/allocation",
    "Mass conservation remains hard",
):
    require(phrase in doc, "DOC_CONTAINS_" + phrase[:24].replace(" `", "_").replace("`", "").replace("/", "_").replace(" ", "_").replace("-", "_").replace("*", "").upper())

status = json.loads(STATUS.read_text(encoding="utf-8"))
require(status["work_unit"] == "F-DOC07" and status["base"] == BASE, "STATUS_IDENTITY")
require(status["decision"] == "QUALIFIED_COMPLETE_RB1_REQUIRED_CAPABILITY_POPULATION_COVERAGE_WITH_EXPLICIT_MATURITY_GAPS", "STATUS_DECISION")
require(status["coverage"] == {"required_denominator":15,"covered_exactly_once":15,"duplicates":0,"unassigned":0,"fully_traced_claimed":False}, "STATUS_COVERAGE")
require(status["status_a_boundary"]["ready_for_status_a_review"] is False, "STATUS_NO_STATUS_A_READY")
require(status["status_a_boundary"]["status_a_compliant"] is False, "STATUS_NO_STATUS_A_COMPLIANCE")
require(status["status_a_boundary"]["status_aa_compliant"] is False, "STATUS_NO_STATUS_AA_COMPLIANCE")
require(status["scope_holds"]["universal_h_budget_claimed"] is False, "STATUS_NO_UNIVERSAL_H_BUDGET")
require(status["scope_holds"]["surface_evaporation_throughput_scaling_claimed"] is False, "STATUS_NO_SURFACE_THROUGHPUT")

closeout = json.loads(CLOSEOUT.read_text(encoding="utf-8"))
require(closeout["work_unit"] == "F-DOC07" and closeout["base"] == BASE, "CLOSEOUT_IDENTITY")
require(closeout["decision"] == status["decision"], "CLOSEOUT_DECISION")
require(closeout["coverage"]["covered_exactly_once"] == 15 and closeout["coverage"]["duplicate_assignments"] == 0 and closeout["coverage"]["unassigned_required_capabilities"] == 0, "CLOSEOUT_COVERAGE")
require(closeout["closeout_state"] in ("PENDING_EXACT_HEAD_CI", "FINAL_EXACT_HEAD_CI_GREEN"), "CLOSEOUT_STATE_ALLOWED")

# Explicit 30-invariant audit.
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
require(audit["total"] == 30 and audit["pass"] == 30 and audit["fail"] == 0, "INVARIANT_COUNTS")
require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "INVARIANT_OVERALL")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "MASS_HARD_UNCHANGED")
require(len(audit["items"]) == 30 and [x["id"] for x in audit["items"]] == list(range(1,31)), "INVARIANT_IDS_1_TO_30")
require(all(x["status"] == "PASS" for x in audit["items"]), "ALL_INVARIANTS_PASS")

print("FDOC07_VALIDATION=PASS")
print("FDOC07_REQUIRED_CAPABILITY_COVERAGE=15_OF_15_EXACTLY_ONCE")
print("FDOC07_FULLY_TRACED_CLAIM=FALSE")
print("FDOC07_STATUS_A_READY_CLAIM=FALSE")
print("FDOC07_T12_COMPLETE_CLAIM=FALSE")
print("FDOC07_PRODUCTION_DELTA=NONE")
print("FDOC07_REFERENCE_DELTA=NONE")
print("FDOC07_MASS_CONSERVATION=HARD_UNCHANGED")
