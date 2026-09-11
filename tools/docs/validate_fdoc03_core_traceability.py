#!/usr/bin/env python3
"""Fail-closed validator for F-DOC03 bounded RB1 core-capability traceability.

This validator qualifies documentation/traceability only. It must not convert
RB1 release qualification into missing theory, observational validation,
Status A/AA readiness, or new scientific/canonical authority.
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "18942fee83eb385fccc1663230772ae03dcc9ae6"
SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SOURCE_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
FDOC01 = "999d4fa3da6fa08c5d57e23b9949f3920de37fbe"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
FRB02 = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
FRB02_RUN = 34586202805

REGISTRY = ROOT / "docs/scientific/registries/rb1-core-capability-traceability.json"
DOC = ROOT / "docs/scientific/F-DOC03_RB1_CORE_CAPABILITY_TRACEABILITY.md"
STATUS = ROOT / "integration/f-doc/F-DOC03_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC03_INVARIANT_AUDIT.json"

EXPECTED_CAPS = [
    "RB1-CORE-INTERVAL",
    "RB1-CORE-DATA",
    "RB1-CORE-TRANSACTION",
    "RB1-CORE-MASS",
    "RB1-CORE-DIAGNOSTICS",
]
EXPECTED_SOURCE_BLOBS = {
    "src/runtime/mod_canonical_contracts.f90": "c06aa869a0bd479df4c7d6e1d0b4f5c07a207144",
    "src/runtime/mod_canonical_interval_runtime.f90": "55f3d271aa6200a994fd0144d6fce0701c918a74",
    "src/transaction/mod_transaction_reference.f90": "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4",
}
ALLOWED_PREFIXES = (
    "docs/scientific/F-DOC03_",
    "docs/scientific/registries/rb1-core-capability-traceability.json",
    "integration/f-doc/F-DOC03_",
    "tools/docs/validate_fdoc03_core_traceability.py",
    ".github/workflows/fdoc03-core-traceability.yml",
)


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC03_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC03_{marker}=PASS")


def source_text(path: str) -> str:
    return sh("git", "show", f"{SOURCE}:{path}")


# Exact lineage and documentation-only scope.
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC02_BASE_ANCESTRY")
changed = [p for p in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if p]
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED_PREFIXES),
            "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Frozen source authority and exact implementation pins.
require(sh("git", "rev-parse", f"{SOURCE}^{{tree}}") == SOURCE_TREE, "SOURCE_TREE")
for path, expected_blob in EXPECTED_SOURCE_BLOBS.items():
    require(sh("git", "rev-parse", f"{SOURCE}:{path}") == expected_blob,
            "SOURCE_BLOB_" + path.split("/")[-1].replace(".", "_").upper())

registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
status = json.loads(STATUS.read_text(encoding="utf-8"))
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
doc = DOC.read_text(encoding="utf-8")

require(registry["work_unit"] == "F-DOC03", "REGISTRY_WORK_UNIT")
require(registry["release_id"] == "SWAP5-RB1-v1", "REGISTRY_RELEASE_ID")
require(registry["source_authority"]["commit"] == SOURCE, "REGISTRY_SOURCE_COMMIT")
require(registry["source_authority"]["tree"] == SOURCE_TREE, "REGISTRY_SOURCE_TREE")
require(registry["authorities"]["fdoc01"] == FDOC01, "REGISTRY_FDOC01")
require(registry["authorities"]["fdoc02"] == BASE, "REGISTRY_FDOC02")
require(registry["authorities"]["rb1_qualification"] == FRB01, "REGISTRY_FRB01")
require(registry["authorities"]["rb1_release"] == FRB02, "REGISTRY_FRB02")
require(registry["authorities"]["rb1_release_run"] == FRB02_RUN, "REGISTRY_FRB02_RUN")

# Source pins must exist and all declared symbols must occur in the exact frozen source.
for pin in registry["source_pins"]:
    path = pin["path"]
    require(path in EXPECTED_SOURCE_BLOBS, "SOURCE_PIN_ALLOWED_" + path.split("/")[-1].replace(".", "_").upper())
    if "blob" in pin:
        require(pin["blob"] == EXPECTED_SOURCE_BLOBS[path], "SOURCE_PIN_BLOB_" + path.split("/")[-1].replace(".", "_").upper())
    text = source_text(path)
    for symbol in pin["symbols"]:
        require(symbol.lower() in text.lower(), "SOURCE_SYMBOL_" + symbol.upper())

# Corrective provenance rule: do not invent the nonexistent direct runtime test.
missing_test = subprocess.run(
    ["git", "cat-file", "-e", f"{SOURCE}:tests/runtime/test_canonical_runtime.f90"],
    cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
)
require(missing_test.returncode != 0, "NONEXISTENT_DIRECT_RUNTIME_TEST_REJECTED")
require("does not exist" in doc and "does not cite the nonexistent path" in doc, "DOC_RECORDS_TESTPATH_CORRECTION")

# Every T9/T10 production mapping must point into the frozen source and name a real symbol.
for node in registry["nodes"]:
    if node.get("tier") not in {"T9", "T10"}:
        continue
    if not node.get("production", False):
        continue
    require(node.get("source_commit") == SOURCE, f"{node['id']}_SOURCE_COMMIT")
    require(node.get("source_tree") == SOURCE_TREE, f"{node['id']}_SOURCE_TREE")
    path = node.get("repository_path", "")
    require(path in EXPECTED_SOURCE_BLOBS, f"{node['id']}_SOURCE_PATH")
    text = source_text(path).lower()
    symbols = [s.strip() for s in node.get("symbol", "").replace(";", ",").split(",") if s.strip()]
    require(bool(symbols), f"{node['id']}_SYMBOL_DECLARED")
    for symbol in symbols:
        # Module declarations are valid implementation anchors too.
        token = symbol.lower().replace("module ", "").strip()
        require(token in text, f"{node['id']}_SYMBOL_{token.upper()}")

# Bounded five-capability denominator and fail-closed tier semantics.
capabilities = registry["capabilities"]
ids = [c["capability_id"] for c in capabilities]
require(ids == EXPECTED_CAPS, "EXACT_FIVE_CORE_CAPABILITIES")
require(len(set(ids)) == 5, "CORE_CAPABILITY_IDS_UNIQUE")
for cap in capabilities:
    cid = cap["capability_id"]
    tiers = cap["tiers"]
    require(list(tiers.keys()) == [f"T{i}" for i in range(15)], f"{cid}_TIERS_T0_T14_COMPLETE")
    require(tiers["T9"]["status"] == "RESOLVED", f"{cid}_T9_RESOLVED")
    require(tiers["T10"]["status"] == "RESOLVED", f"{cid}_T10_RESOLVED")
    require(tiers["T11"]["status"] == "SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED", f"{cid}_T11_SCOPED")
    require(tiers["T12"]["status"] == "NOT_APPLICABLE", f"{cid}_T12_NOT_APPLICATION_VALIDATION")
    require(tiers["T13"]["status"] == "RESOLVED_RB1_RELEASE_SCOPE", f"{cid}_T13_RB1_SCOPE")
    require(tiers["T14"]["status"] == "RESOLVED_RB1_RELEASE_AUTHORITY", f"{cid}_T14_RB1_AUTHORITY")
    require("FULLY_TRACED" not in cap.get("overall", ""), f"{cid}_NOT_FULLY_TRACED")

mass = next(c for c in capabilities if c["capability_id"] == "RB1-CORE-MASS")
require(mass["tiers"]["T1"]["status"] == "GAP", "CORE_MASS_T1_EXPLICIT_GAP")
require(status["traceability_boundary"]["core_mass_t1_source_binding"] == "OPEN", "STATUS_CORE_MASS_T1_OPEN")
require(status["traceability_boundary"]["t11_complete_test_graph"] == "OPEN_FOR_ALL_FIVE", "STATUS_T11_OPEN_ALL_FIVE")

# No Status A/AA or complete-traceability inflation.
boundary = status["traceability_boundary"]
require(boundary["fully_traced_claimed"] is False, "NO_FULLY_TRACED_CLAIM")
require(boundary["status_a_ready_claimed"] is False, "NO_STATUS_A_READY_CLAIM")
require(boundary["status_a_compliant_claimed"] is False, "NO_STATUS_A_COMPLIANCE_CLAIM")
require(boundary["status_aa_compliant_claimed"] is False, "NO_STATUS_AA_COMPLIANCE_CLAIM")
require(status["scope_holds"]["production_delta"] == "NONE", "STATUS_ZERO_PRODUCTION_DELTA")
require(status["scope_holds"]["reference_delta"] == "NONE", "STATUS_ZERO_REFERENCE_DELTA")
require(status["scope_holds"]["physics_delta"] == "NONE", "STATUS_ZERO_PHYSICS_DELTA")
require(status["scope_holds"]["solver_delta"] == "NONE", "STATUS_ZERO_SOLVER_DELTA")
require(status["scope_holds"]["acceptance_threshold_delta"] == "NONE", "STATUS_ZERO_THRESHOLD_DELTA")
require(status["scope_holds"]["performance_delta"] == "NONE", "STATUS_ZERO_PERFORMANCE_DELTA")
require(status["scope_holds"]["rb1_denominator_changed"] is False, "STATUS_RB1_DENOMINATOR_UNCHANGED")
require(status["scope_holds"]["scientific_authority_reopened"] is False, "STATUS_SCIENCE_NOT_REOPENED")
require(status["scope_holds"]["release_authority_reopened"] is False, "STATUS_RELEASE_NOT_REOPENED")

# Architecture invariants remain non-adversely affected.
items = audit["items"]
require(len(items) == 30 and [x["id"] for x in items] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x["result"] == "PASS" for x in items), "INVARIANTS_30_OF_30_PASS")
require(audit["summary"]["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "INVARIANT_AUDIT_OVERALL")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "HARD_MASS_UNCHANGED")
require(audit["production_delta"] == "NONE" and audit["reference_delta"] == "NONE", "AUDIT_ZERO_IMPLEMENTATION_DELTA")

# Exact-head evidence output.
evidence = {
    "work_unit": "F-DOC03",
    "head": sh("git", "rev-parse", "HEAD"),
    "tree": sh("git", "rev-parse", "HEAD^{tree}"),
    "base": BASE,
    "source_authority": SOURCE,
    "rb1_qualification_authority": FRB01,
    "rb1_release_authority": FRB02,
    "capabilities": ids,
    "core_mass_t1": "GAP",
    "t11": "SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED",
    "status_a_ready": False,
    "production_delta": False,
    "reference_delta": False,
    "invariants": "30_OF_30_NO_ADVERSE_DELTA",
}
(ROOT / "_fdoc03_core_traceability_evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
print("FDOC03_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_BOUNDED_RB1_CORE_TRACEABILITY_POPULATION_WITH_EXPLICIT_GAPS")
