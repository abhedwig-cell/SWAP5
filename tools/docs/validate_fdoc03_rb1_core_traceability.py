#!/usr/bin/env python3
"""Fail-closed validator for F-DOC03 bounded RB1 core traceability."""
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "18942fee83eb385fccc1663230772ae03dcc9ae6"
BASE_TREE = "b8044f3040bbb86e1743a7b1f7c2159ae5c0ffa3"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SOURCE_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
FRB02 = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
FRB02_RUN = 34586202805

REGISTRY = ROOT / "docs/scientific/registries/rb1-core-capability-traceability.json"
STATUS = ROOT / "integration/f-doc/F-DOC03_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC03_INVARIANT_AUDIT.json"
DOC = ROOT / "docs/scientific/F-DOC03_RB1_CORE_CAPABILITY_TRACEABILITY.md"

EXPECTED_BLOBS = {
    "src/runtime/mod_canonical_contracts.f90": "c06aa869a0bd479df4c7d6e1d0b4f5c07a207144",
    "src/runtime/mod_canonical_interval_runtime.f90": "55f3d271aa6200a994fd0144d6fce0701c918a74",
    "src/transaction/mod_transaction_reference.f90": "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4",
}
CORE_IDS = [
    "RB1-CORE-INTERVAL",
    "RB1-CORE-DATA",
    "RB1-CORE-TRANSACTION",
    "RB1-CORE-MASS",
    "RB1-CORE-DIAGNOSTICS",
]
ALLOWED_PATHS = (
    "docs/scientific/F-DOC03_",
    "docs/scientific/registries/rb1-core-capability-traceability.json",
    "integration/f-doc/F-DOC03_",
    "tools/docs/validate_fdoc03_rb1_core_traceability.py",
    ".github/workflows/fdoc03-rb1-core-traceability.yml",
)
NODE_RE = re.compile(r"^SW5-[A-Z]+-[0-9]{4}$")
NONEXISTENT_TEST = "tests/runtime/test_canonical_runtime.f90"


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC03_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC03_{marker}=PASS")


def git_json(commit: str, path: str) -> dict:
    return json.loads(sh("git", "show", f"{commit}:{path}"))


# F-DOC03 must be a documentation-only descendant of exact F-DOC02.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "FDOC02_BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC02_BASE_ANCESTRY")
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
require(bool(changed), "BOUNDED_DELTA_NONEMPTY")
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED_PATHS),
            "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# RB1 source binding is to the exact historical authority and exact described blobs.
# The later F-DOC02 branch may contain qualified post-RB1 source composition, so its
# whole src tree is deliberately NOT required to equal the older RB1 source tree.
require(sh("git", "rev-parse", f"{SOURCE}^{{tree}}") == SOURCE_TREE, "SOURCE_AUTHORITY_TREE")
for path, expected in EXPECTED_BLOBS.items():
    actual = sh("git", "rev-parse", f"{SOURCE}:{path}")
    require(actual == expected, "SOURCE_BLOB_" + path.split("/")[-1].replace(".", "_").upper())
print("FDOC03_SOURCE_PINS_EXACT=PASS")

registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
status = json.loads(STATUS.read_text(encoding="utf-8"))
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
doc_text = DOC.read_text(encoding="utf-8")

require(registry["schema_version"] == 1 and registry["work_unit"] == "F-DOC03", "REGISTRY_IDENTITY")
require(registry["release_id"] == "SWAP5-RB1-v1", "REGISTRY_RELEASE_ID")
require(registry["source_authority"] == {"commit": SOURCE, "tree": SOURCE_TREE}, "REGISTRY_SOURCE_AUTHORITY")
require(registry["authorities"]["fdoc02"] == BASE, "REGISTRY_FDOC02_AUTHORITY")
require(registry["authorities"]["rb1_qualification"] == FRB01, "REGISTRY_FRB01_AUTHORITY")
require(registry["authorities"]["rb1_release"] == FRB02, "REGISTRY_FRB02_AUTHORITY")
require(registry["authorities"]["rb1_release_run"] == FRB02_RUN, "REGISTRY_FRB02_RUN")

caps = registry["capabilities"]
require([c["capability_id"] for c in caps] == CORE_IDS, "EXACT_CORE_CAPABILITY_SET_5")
nodes = registry["nodes"]
node_ids = [n["id"] for n in nodes]
require(len(node_ids) == len(set(node_ids)), "NODE_IDS_UNIQUE")
require(all(NODE_RE.match(nid) for nid in node_ids), "NODE_IDS_VALID")
node_map = {n["id"]: n for n in nodes}
require(all(e["from"] in node_map and e["to"] in node_map for e in registry["edges"]), "EDGE_ENDPOINTS_RESOLVE")

mapped = [n for n in nodes if n["tier"] in ("T9", "T10")]
require(len(mapped) == 10, "T9_T10_NODE_COUNT_10")
for node in mapped:
    require(node.get("source_commit") == SOURCE, node["id"] + "_SOURCE_COMMIT")
    require(node.get("source_tree") == SOURCE_TREE, node["id"] + "_SOURCE_TREE")
    require(node.get("production") is True, node["id"] + "_PRODUCTION")
    require(node.get("repository_path") in EXPECTED_BLOBS, node["id"] + "_SOURCE_PATH")
    require(bool(node.get("symbol")), node["id"] + "_SYMBOL")
print("FDOC03_T9_T10_MAPPING=PASS")

positive_locators: list[str] = []
for node in nodes:
    positive_locators.extend(node.get("sources", []))
    if node.get("repository_path"):
        positive_locators.append(node["repository_path"])
require(NONEXISTENT_TEST not in positive_locators, "NONEXISTENT_TEST_NOT_USED_AS_EVIDENCE")
require(NONEXISTENT_TEST in doc_text, "NONEXISTENT_TEST_CORRECTION_DOCUMENTED")
require(any(NONEXISTENT_TEST in x for x in registry.get("nonclaims", [])), "NONEXISTENT_TEST_NONCLAIM_DOCUMENTED")

all_tiers = {f"T{i}" for i in range(15)}
for cap in caps:
    tiers = cap["tiers"]
    require(set(tiers) == all_tiers, cap["capability_id"] + "_ALL_TIERS_CLASSIFIED")
    require(tiers["T11"]["status"] == "SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED", cap["capability_id"] + "_T11_SCOPED")
    require(tiers["T13"]["status"] == "RESOLVED_RB1_RELEASE_SCOPE", cap["capability_id"] + "_T13")
    require(tiers["T14"]["status"] == "RESOLVED_RB1_RELEASE_AUTHORITY", cap["capability_id"] + "_T14")
    require("FULLY_TRACED" not in cap.get("overall", ""), cap["capability_id"] + "_NOT_FULLY_TRACED")
    for tier, entry in tiers.items():
        if entry["status"] == "NOT_APPLICABLE":
            require(bool(entry.get("rationale", "").strip()), cap["capability_id"] + "_" + tier + "_NA_RATIONALE")
print("FDOC03_T11_SCOPED_NOT_COMPLETE=PASS")
print("FDOC03_NO_FULLY_TRACED_CLAIM=PASS")

by_cap = {c["capability_id"]: c for c in caps}
mass = by_cap["RB1-CORE-MASS"]
require(mass["tiers"]["T1"]["status"] == "GAP_SOURCE_BINDING_OPEN", "CORE_MASS_T1_GAP_EXPLICIT")
require(node_map[mass["tiers"]["T1"]["node"]]["status"] == "GAP", "CORE_MASS_T1_NODE_GAP")
require(mass["tiers"]["T12"]["status"] == "NOT_APPLICABLE", "CORE_MASS_T12_NA")
require(mass["overall"] == "PARTIALLY_TRACED_T1_AND_T11_OPEN", "CORE_MASS_OVERALL_OPEN")

data_tiers = by_cap["RB1-CORE-DATA"]["tiers"]
for i in range(9):
    require(data_tiers[f"T{i}"]["status"] == "NOT_APPLICABLE", f"CORE_DATA_T{i}_NA")
    require(bool(data_tiers[f"T{i}"]["rationale"].strip()), f"CORE_DATA_T{i}_RATIONALE")

matrix = git_json(FRB01, "release/f-rb01/RB1_CAPABILITY_MATRIX.json")
qual = git_json(FRB01, "release/f-rb01/RB1_RELEASE_QUALIFICATION.json")
matrix_map = {x["capability_id"]: x for x in matrix["capabilities"]}
require(matrix["required_denominator"] == 15, "RB1_DENOMINATOR_STILL_15")
require(all(matrix_map[c]["integrated_release_gate"] == "PASS" for c in CORE_IDS), "FIVE_CORE_RB1_PASS")
require(qual["release_gates"]["hard_mass"] == "PASS", "RB1_HARD_MASS_PASS")
require(qual["release_gates"]["transactionality"] == "PASS", "RB1_TRANSACTIONALITY_PASS")
require(qual["scientific_authority_reopened"] is False, "RB1_SCIENCE_FROZEN")

require(status["work_unit"] == "F-DOC03", "STATUS_WORK_UNIT")
require(status["base"] == BASE and status["source_authority"] == SOURCE, "STATUS_AUTHORITIES")
require(status["capabilities"] == CORE_IDS, "STATUS_CORE_SET_5")
for key in ("production_delta", "reference_delta", "physics_delta", "solver_delta", "acceptance_threshold_delta", "performance_delta"):
    require(status["scope_holds"][key] == "NONE", "STATUS_" + key.upper() + "_NONE")
require(status["scope_holds"]["rb1_denominator_changed"] is False, "STATUS_DENOMINATOR_UNCHANGED")
require(status["scope_holds"]["scientific_authority_reopened"] is False, "STATUS_SCIENCE_NOT_REOPENED")
require(status["scope_holds"]["release_authority_reopened"] is False, "STATUS_RELEASE_NOT_REOPENED")
boundary = status["traceability_boundary"]
require(boundary["fully_traced_claimed"] is False, "STATUS_NO_FULL_TRACE_CLAIM")
require(boundary["status_a_ready_claimed"] is False, "STATUS_NOT_STATUS_A_READY")
require(boundary["status_a_compliant_claimed"] is False, "STATUS_NOT_STATUS_A_COMPLIANT")
require(boundary["status_aa_compliant_claimed"] is False, "STATUS_NOT_STATUS_AA_COMPLIANT")

items = audit["items"]
require(len(items) == 30 and [x["id"] for x in items] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x["result"] == "PASS" for x in items), "INVARIANTS_30_OF_30_PASS")
require(audit["summary"] == {"total": 30, "pass": 30, "fail": 0, "overall": "30_OF_30_NO_ADVERSE_DELTA"}, "INVARIANT_SUMMARY")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "HARD_MASS_UNCHANGED")

out = {
    "work_unit": "F-DOC03",
    "head": sh("git", "rev-parse", "HEAD"),
    "tree": sh("git", "rev-parse", "HEAD^{tree}"),
    "fdoc02_base": BASE,
    "rb1_scientific_source": SOURCE,
    "frb01_qualification": FRB01,
    "frb02_release_authority": FRB02,
    "frb02_exact_head_run": FRB02_RUN,
    "capabilities": CORE_IDS,
    "source_blobs": EXPECTED_BLOBS,
    "production_delta": False,
    "reference_delta": False,
    "fully_traced": False,
    "core_mass_t1_source_binding": "OPEN",
    "t11_complete_graph": "OPEN",
    "status_a_ready": False,
    "status_a_compliant": False,
    "status_aa_compliant": False,
    "invariant_audit": "30_OF_30_NO_ADVERSE_DELTA"
}
(ROOT / "_fdoc03_rb1_core_traceability_evidence.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print("FDOC03_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_BOUNDED_RB1_CORE_TRACEABILITY_POPULATION_WITH_EXPLICIT_GAPS")
