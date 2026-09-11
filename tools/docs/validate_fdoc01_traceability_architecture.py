#!/usr/bin/env python3
"""Fail-closed validator for F-DOC01 scientific documentation architecture.

This validator qualifies architecture, provenance discipline and explicit gap
handling. It MUST NOT promote SWAP5 to Status A/AA or READY_FOR_STATUS_A_REVIEW.
"""
from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "3c5f5bd3686e1632058b906be21abd73883e30ef"
BASE_TREE = "6baaf40271497db831698c5a01de355b5d296dbe"
STATUS = ROOT / "integration/f-doc/F-DOC01_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC01_INVARIANT_AUDIT.json"
SCI = ROOT / "docs/scientific"
AUTH = SCI / "registries/status-a-aa-authority.yaml"
REQ = SCI / "registries/status-a-aa-requirements.yaml"
A_MATRIX = SCI / "F-DOC01_STATUS_A_REQUIREMENT_MATRIX.md"
AA_MATRIX = SCI / "F-DOC01_STATUS_AA_REQUIREMENT_MATRIX.md"
TRACE_DOC = SCI / "F-DOC01_THEORY_TO_CODE_TRACEABILITY_ARCHITECTURE.md"
INDEX = SCI / "index.md"

EXPECTED_REQUIREMENTS = [
    "1.1", "1.2", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4",
    "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "6.1", "6.2",
    "6.3", "6.4", "7.1", "7.2",
]
EXPECTED_DOCS = {
    "F-DOC01_CURRENT_DOCUMENTATION_INVENTORY.md",
    "F-DOC01_DEVELOPMENT_VERSION_MANAGEMENT_POLICY.md",
    "F-DOC01_FITNESS_FOR_PURPOSE_FRAMEWORK.md",
    "F-DOC01_INPUT_PROVENANCE_POLICY.md",
    "F-DOC01_INTERPRETATION_USE_ARCHITECTURE.md",
    "F-DOC01_OWNERSHIP_MAINTENANCE_SCHEMA.md",
    "F-DOC01_PARAMETER_CALIBRATION_DOCUMENTATION_POLICY.md",
    "F-DOC01_SCIENTIFIC_ID_POLICY.md",
    "F-DOC01_SENSITIVITY_UNCERTAINTY_ARCHITECTURE.md",
    "F-DOC01_SOURCE_PROVENANCE_POLICY.md",
    "F-DOC01_STATUS_AA_REQUIREMENT_MATRIX.md",
    "F-DOC01_STATUS_A_AA_AUTHORITY.md",
    "F-DOC01_STATUS_A_REQUIREMENT_MATRIX.md",
    "F-DOC01_THEORY_CODE_EVIDENCE_RECONCILIATION_POLICY.md",
    "F-DOC01_THEORY_TO_CODE_TRACEABILITY_ARCHITECTURE.md",
    "F-DOC01_TRACEABILITY_GRAPH_SCHEMA.md",
    "F-DOC01_VERIFICATION_VALIDATION_POLICY.md",
    "index.md",
}
EXPECTED_SCHEMAS = {
    "ownership-maintenance.schema.json",
    "status-a-audit.schema.json",
    "status-aa-readiness.schema.json",
    "traceability.schema.json",
}
ALLOWED_CHANGE_PREFIXES = (
    "docs/scientific/",
    "integration/f-doc/F-DOC01_",
    "tools/docs/validate_fdoc01_traceability_architecture.py",
    ".github/workflows/fdoc01-traceability-architecture.yml",
)


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC01_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC01_{marker}=PASS")


def text(path: pathlib.Path) -> str:
    require(path.is_file(), "FILE_EXISTS_" + path.name.replace(".", "_").replace("-", "_").upper())
    return path.read_text(encoding="utf-8")


# Exact source ancestry and documentation-only scope.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "BASE_ANCESTRY")
changed = [x for x in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED_CHANGE_PREFIXES),
            "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Required architecture package exists and JSON schemas are syntactically valid.
require(EXPECTED_DOCS <= {p.name for p in SCI.glob("*.md")}, "EXPECTED_ARCHITECTURE_DOCS")
schema_dir = SCI / "schemas"
require(EXPECTED_SCHEMAS <= {p.name for p in schema_dir.glob("*.json")}, "EXPECTED_SCHEMAS")
for name in sorted(EXPECTED_SCHEMAS):
    obj = json.loads((schema_dir / name).read_text(encoding="utf-8"))
    require(obj.get("$schema") == "https://json-schema.org/draft/2020-12/schema", "JSON_SCHEMA_" + name.replace(".", "_").replace("-", "_").upper())

trace_schema = json.loads((schema_dir / "traceability.schema.json").read_text(encoding="utf-8"))
require(trace_schema.get("required") == ["schema_version", "source_authority", "nodes", "edges"], "TRACEABILITY_TOP_LEVEL_CONTRACT")
node = trace_schema["$defs"]["node"]
require(set(["id", "kind", "tier", "title", "status", "authority", "record_version"]) <= set(node["required"]), "TRACEABILITY_NODE_CONTRACT")
require(node["properties"]["tier"]["pattern"] == "^T(?:[0-9]|1[0-4])$", "TRACEABILITY_T0_T14_SCHEMA")

# Public mapping baseline is complete as a mapping, while formal 2024 authority remains blocked.
auth = text(AUTH)
req = text(REQ)
require("formal_project_criterion_authority" in text(SCI / "F-DOC01_STATUS_A_AA_AUTHORITY.md"), "FORMAL_AUTHORITY_EXPLICIT")
require("direct_controlled_copy: null" in auth, "CONTROLLED_COPY_NOT_FABRICATED")
require("compliance_gate: BLOCKED_UNTIL_CONTROLLED_COPY_RECONCILED" in auth, "COMPLIANCE_GATE_FAIL_CLOSED")
for prohibited in ("STATUS_A_COMPLIANT", "STATUS_AA_COMPLIANT", "SWAP5_HAS_STATUS_A", "STATUS_A_QUALIFIED"):
    require(prohibited in auth, "PROHIBITED_CLAIM_" + prohibited)
require("formal_2024_reconciliation: PENDING_CONTROLLED_COPY" in req, "FORMAL_2024_RECONCILIATION_PENDING")
require("perspectives: 3" in req and "themes: 7" in req, "PUBLIC_BASELINE_STRUCTURE")
ids = re.findall(r"^\s*- \{id: '([0-9]+\.[0-9]+)'", req, flags=re.M)
require(ids == EXPECTED_REQUIREMENTS, "PUBLIC_REQUIREMENT_IDS_22_OF_22")
require(len(ids) == 22 and len(set(ids)) == 22, "PUBLIC_REQUIREMENT_DENOMINATOR_FIXED")

# Human-readable A and AA matrices must use the same complete requirement denominator.
def matrix_ids(path: pathlib.Path) -> list[str]:
    return re.findall(r"^\|\s*([1-7]\.[1-9])\s*\|", text(path), flags=re.M)

require(matrix_ids(A_MATRIX) == EXPECTED_REQUIREMENTS, "STATUS_A_MATRIX_22_OF_22")
require(matrix_ids(AA_MATRIX) == EXPECTED_REQUIREMENTS, "STATUS_AA_MATRIX_22_OF_22")
require("not a compliance verdict" in text(A_MATRIX).lower(), "STATUS_A_MATRIX_NONCLAIM")
require("provisional until the controlled" in text(AA_MATRIX).lower(), "STATUS_AA_MATRIX_NONCLAIM")

# T0-T14 architecture and authority separation.
trace = text(TRACE_DOC)
for tier in range(15):
    require(re.search(rf"\|\s*T{tier}\s*\|", trace) is not None, f"TRACE_T{tier}_PRESENT")
require("machine-readable registries define IDs and edges" in trace, "MACHINE_REGISTRY_SOURCE_OF_TRUTH")
require("F-VQ/F-MQ/F-CI/F-TB evidence remains authoritative" in trace, "EVIDENCE_AUTHORITY_NOT_DUPLICATED")
idx = text(INDEX)
require("it is not a claim that SWAP5 has Status A or Status AA" in idx, "INDEX_STATUS_NONCLAIM")
require("Formal compliance remains blocked" in idx, "INDEX_COMPLIANCE_BLOCKED")

# Closeout status must keep readiness/compliance false and scope closed.
status = json.loads(STATUS.read_text(encoding="utf-8"))
require(status.get("work_unit") == "F-DOC01", "STATUS_WORK_UNIT")
require(status.get("decision_if_green") == "QUALIFIED_SCIENTIFIC_DOCUMENTATION_TRACEABILITY_ARCHITECTURE_READY_FOR_INCREMENTAL_POPULATION", "DECISION_BOUNDARY")
b = status["status_a_boundary"]
for key in ("is_status_a_dossier", "ready_for_status_a_review", "status_a_compliant", "status_aa_compliant", "external_audit_performed"):
    require(b.get(key) is False, "STATUS_BOUNDARY_FALSE_" + key.upper())
require(b.get("compliance_state") == "BLOCKED_PENDING_CONTROLLED_2024_CRITERIA_RECONCILIATION_AND_EVIDENCE_COMPLETION", "STATUS_A_BLOCKER")
for key, value in status["scope_holds"].items():
    require(value is False, "SCOPE_HOLD_FALSE_" + key.upper())
require(len(status.get("known_gaps", [])) >= 8, "KNOWN_GAPS_EXPLICIT")

# Architecture audit is complete and cannot weaken mass conservation.
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
items = audit.get("items", [])
require(audit.get("overall") == "30_OF_30_NO_ADVERSE_DELTA", "INVARIANT_AUDIT_OVERALL")
require(audit.get("mass_conservation") == "HARD_UNCHANGED", "HARD_MASS_UNCHANGED")
require(len(items) == 30 and [x.get("id") for x in items] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x.get("result") == "PASS" for x in items), "INVARIANTS_30_OF_30_PASS")

# Emit reproducible evidence for the workflow artifact.
evidence = {
    "work_unit": "F-DOC01",
    "head": sh("git", "rev-parse", "HEAD"),
    "tree": sh("git", "rev-parse", "HEAD^{tree}"),
    "base": BASE,
    "changed_paths": changed,
    "public_requirement_count": 22,
    "traceability_tiers": 15,
    "status_a_compliance": "BLOCKED",
    "ready_for_status_a_review": False,
    "production_delta": False,
    "reference_delta": False,
    "invariant_audit": "30_OF_30_NO_ADVERSE_DELTA",
}
(ROOT / "_fdoc01_traceability_evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
print("FDOC01_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_SCIENTIFIC_DOCUMENTATION_TRACEABILITY_ARCHITECTURE_READY_FOR_INCREMENTAL_POPULATION")
