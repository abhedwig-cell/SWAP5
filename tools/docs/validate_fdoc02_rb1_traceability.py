#!/usr/bin/env python3
"""Fail-closed validator for F-DOC02 RB1 release-bound traceability.

F-DOC02 may index exact RB1 authorities and expose documentation gaps. It may
not infer theory, implementation mapping, application validation, Status A
readiness, or new scientific qualification from an RB1 release PASS.
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = "999d4fa3da6fa08c5d57e23b9949f3920de37fbe"
BASE_TREE = "fef5d8fea98e63abaebe95c4d0c7643869ef4762"
RB1_SOURCE = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
FRB01 = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
FRB02 = "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
FRB02_TREE = "9fd636cb35503d59654495186c9b4ec33287f344"
FRB02_RUN = 34586202805
FRB02_ARTIFACT = 10193678464
FRB02_DIGEST = "sha256:8730e91708395dd03af0cb7f3ad51b04dc48cfb797be2a9557ba89e37038f82a"
SCOPE_PATH = "release/f-rb01/RESTRICTED_PRODUCTION_BASELINE_V1_SCOPE.json"
MATRIX_PATH = "release/f-rb01/RB1_CAPABILITY_MATRIX.json"
QUAL_PATH = "release/f-rb01/RB1_RELEASE_QUALIFICATION.json"
CLOSEOUT_PATH = "release/f-rb02/F-RB02_CLOSEOUT.json"
REGISTRY = ROOT / "docs/scientific/registries/rb1-release-traceability-index.json"
GAP_MATRIX = ROOT / "docs/scientific/F-DOC02_RB1_RELEASE_TRACEABILITY_GAP_MATRIX.md"
STATUS = ROOT / "integration/f-doc/F-DOC02_STATUS.json"
AUDIT = ROOT / "integration/f-doc/F-DOC02_INVARIANT_AUDIT.json"

EXPECTED_SCOPE_BLOB = "09df8417fe12bcc2eca9d9320117264737ffc83a"
EXPECTED_MATRIX_BLOB = "e20e0b2cae1cfde91c8736ad632059b4fe480d88"
EXPECTED_QUAL_BLOB = "f2d55a945dde6e379f2df1c3cbbd8706b1bbaa09"
EXPECTED_CLOSEOUT_BLOB = "e20dd5744c5717397339af5d14935b41e4ff90c7"
EXPECTED_OPEN_TIERS = [f"T{i}" for i in range(11)] + ["T12"]
ALLOWED_PREFIXES = (
    "docs/scientific/F-DOC02_",
    "docs/scientific/registries/rb1-release-traceability-index.json",
    "integration/f-doc/F-DOC02_",
    "tools/docs/validate_fdoc02_rb1_traceability.py",
    ".github/workflows/fdoc02-rb1-traceability.yml",
)


def sh(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(cond: bool, marker: str) -> None:
    if not cond:
        print(f"FDOC02_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FDOC02_{marker}=PASS")


def git_json(commit: str, path: str) -> dict:
    return json.loads(sh("git", "show", f"{commit}:{path}"))


def blob(commit: str, path: str) -> str:
    return sh("git", "rev-parse", f"{commit}:{path}")


# F-DOC02 is a documentation-only descendant of the exact qualified F-DOC01.
require(sh("git", "rev-parse", f"{BASE}^{{tree}}") == BASE_TREE, "FDOC01_BASE_TREE")
require(sh("git", "merge-base", "HEAD", BASE) == BASE, "FDOC01_BASE_ANCESTRY")
changed = [x for x in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
for path in changed:
    require(any(path.startswith(prefix) for prefix in ALLOWED_PREFIXES),
            "DOC_ONLY_" + path.replace("/", "_").replace(".", "_").replace("-", "_").upper())
require(sh("git", "rev-parse", "HEAD:src") == sh("git", "rev-parse", f"{BASE}:src"), "ZERO_PRODUCTION_DELTA")
require(sh("git", "rev-parse", "HEAD:reference") == sh("git", "rev-parse", f"{BASE}:reference"), "ZERO_REFERENCE_DELTA")

# Exact upstream immutable objects must exist and retain their known identities.
require(blob(FRB01, SCOPE_PATH) == EXPECTED_SCOPE_BLOB, "FRB01_SCOPE_BLOB")
require(blob(FRB01, MATRIX_PATH) == EXPECTED_MATRIX_BLOB, "FRB01_MATRIX_BLOB")
require(blob(FRB01, QUAL_PATH) == EXPECTED_QUAL_BLOB, "FRB01_QUALIFICATION_BLOB")
require(blob(FRB02, CLOSEOUT_PATH) == EXPECTED_CLOSEOUT_BLOB, "FRB02_CLOSEOUT_BLOB")
require(sh("git", "rev-parse", f"{FRB02}^{{tree}}") == FRB02_TREE, "FRB02_TREE")

scope = git_json(FRB01, SCOPE_PATH)
matrix = git_json(FRB01, MATRIX_PATH)
qual = git_json(FRB01, QUAL_PATH)
closeout = git_json(FRB02, CLOSEOUT_PATH)
registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
status = json.loads(STATUS.read_text(encoding="utf-8"))
audit = json.loads(AUDIT.read_text(encoding="utf-8"))
gap_text = GAP_MATRIX.read_text(encoding="utf-8")

# Frozen RB1 denominator and qualification identity.
require(scope["scope_frozen"] is True, "RB1_SCOPE_FROZEN")
require(scope["moving_denominator_forbidden"] is True, "RB1_DENOMINATOR_IMMUTABLE")
require(scope["required_capability_denominator"] == 15, "RB1_REQUIRED_DENOMINATOR_15")
expected_ids = [x["id"] for x in scope["required_capabilities"]]
optional_ids = [x["id"] for x in scope["admitted_optional"]]
require(len(expected_ids) == 15 and len(set(expected_ids)) == 15, "RB1_SCOPE_IDS_UNIQUE_15")
require(matrix["required_denominator"] == 15, "RB1_MATRIX_DENOMINATOR_15")
matrix_ids = [x["capability_id"] for x in matrix["capabilities"]]
require(matrix_ids == expected_ids, "RB1_MATRIX_SCOPE_IDENTITY")
require(all(x["integrated_release_gate"] == "PASS" for x in matrix["capabilities"]), "RB1_MATRIX_15_OF_15_PASS")
require(matrix["summary"]["required_integrated_pass"] == 15 and matrix["summary"]["required_gaps"] == 0, "RB1_MATRIX_SUMMARY_15_PASS_0_GAP")
require(qual["decision"] == "QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_READY_FOR_RELEASE_AUTHORITY", "FRB01_DECISION")
require(qual["production_change_by_frb01"] == "NONE" and qual["scientific_authority_reopened"] is False, "FRB01_ZERO_SCIENCE_DELTA")

# Definitive F-RB02 release authority, not the earlier precloseout metadata head.
require(closeout["release_id"] == "SWAP5-RB1-v1", "FRB02_RELEASE_ID")
require(closeout["decision"] == "QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_RELEASE_AUTHORITY_ESTABLISHED", "FRB02_DECISION")
require(closeout["frozen_release"]["required_capabilities"] == 15 and closeout["frozen_release"]["required_pass"] == 15, "FRB02_FROZEN_15_OF_15")
require(closeout["immutability"]["production_delta_by_frb02"] == "NONE", "FRB02_ZERO_PRODUCTION_DELTA")
require(closeout["immutability"]["scientific_authority_reopened"] is False, "FRB02_SCIENCE_NOT_REOPENED")

# F-DOC02 registry authority pins.
auth = registry["authorities"]
require(auth["fdoc01_architecture"]["commit"] == BASE and auth["fdoc01_architecture"]["tree"] == BASE_TREE, "REGISTRY_FDOC01_AUTHORITY")
require(auth["rb1_scientific_source"]["commit"] == RB1_SOURCE, "REGISTRY_RB1_SOURCE_AUTHORITY")
require(auth["rb1_qualification"]["commit"] == FRB01, "REGISTRY_FRB01_AUTHORITY")
require(auth["rb1_release_metadata"]["commit"] == FRB02 and auth["rb1_release_metadata"]["tree"] == FRB02_TREE, "REGISTRY_FRB02_AUTHORITY")
require(auth["rb1_release_metadata"]["exact_head_run"] == FRB02_RUN, "REGISTRY_FRB02_RUN")
require(auth["rb1_release_metadata"]["evidence_artifact"] == FRB02_ARTIFACT, "REGISTRY_FRB02_ARTIFACT")
require(auth["rb1_release_metadata"]["evidence_digest"] == FRB02_DIGEST, "REGISTRY_FRB02_DIGEST")
require(registry["denominator"]["required"] == 15 and registry["denominator"]["moving_denominator_forbidden"] is True, "REGISTRY_DENOMINATOR_15_FROZEN")

# Exact 15-capability population and fail-closed tier semantics.
capabilities = registry["capabilities"]
registry_ids = [x["capability_id"] for x in capabilities]
require(registry_ids == expected_ids, "REGISTRY_EXACT_REQUIRED_IDS_15")
require(not (set(registry_ids) & set(optional_ids)), "OPTIONAL_IDS_OUTSIDE_REQUIRED_DENOMINATOR")
require(registry["population_policy"]["default_unresolved_tiers"] == EXPECTED_OPEN_TIERS, "DEFAULT_OPEN_TIERS_T0_T10_T12")
for cap in capabilities:
    cid = cap["capability_id"]
    require(cap["rb1_release_gate"] == "PASS", f"{cid}_RB1_PASS")
    require(cap["unresolved_tiers"] == EXPECTED_OPEN_TIERS, f"{cid}_OPEN_TIERS_EXPLICIT")
    require("T12" in cap["unresolved_tiers"], f"{cid}_VALIDATION_NOT_INFERRED")
    require(cap["T11"]["status"] == "SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED", f"{cid}_T11_SCOPED_ONLY")
    require(bool(cap["T11"].get("evidence")), f"{cid}_T11_EVIDENCE_LOCATOR")
    require(cap["T13"]["status"] == "RESOLVED_RB1_RELEASE_SCOPE" and cap["T13"]["authority"] == FRB01, f"{cid}_T13_FRB01")
    require(cap["T14"]["status"] == "RESOLVED_RB1_RELEASE_AUTHORITY" and cap["T14"]["authority"] == FRB02, f"{cid}_T14_FRB02")

surf = next(x for x in capabilities if x["capability_id"] == "RB1-SURFACE-EVAP-RESTRICTED")
require("throughput/scaling remains separate" in surf["T13"].get("nonclaim", ""), "SURFACE_EVAP_PERFORMANCE_SCOPE_HOLD")
require("Throughput/scaling of the call-local copy/allocation path remains a separate performance subject" in gap_text, "SURFACE_EVAP_GAP_MATRIX_NONCLAIM")

# Status A/AA and application validation boundaries remain fail closed.
for obj_name, boundary in (("REGISTRY", registry["status_a_boundary"]), ("STATUS", status["status_a_boundary"])):
    require(boundary["ready_for_status_a_review"] is False, f"{obj_name}_NOT_STATUS_A_READY")
    require(boundary["status_a_compliant"] is False, f"{obj_name}_NOT_STATUS_A_COMPLIANT")
    require(boundary["status_aa_compliant"] is False, f"{obj_name}_NOT_STATUS_AA_COMPLIANT")
    require(boundary["formal_2024_reconciliation"] == "PENDING_CONTROLLED_COPY", f"{obj_name}_2024_RECONCILIATION_PENDING")
require(status["decision_if_green"] == "QUALIFIED_RB1_RELEASE_BOUND_TRACEABILITY_INDEX_WITH_EXPLICIT_GAPS", "DECISION_BOUNDARY")
require(status["scope_holds"]["scientific_qualification_reopened"] is False, "SCIENTIFIC_QUALIFICATION_NOT_REOPENED")
require(status["scope_holds"]["rb1_denominator_changed"] is False, "RB1_DENOMINATOR_NOT_CHANGED")

# All 30 architecture invariants remain non-adversely affected.
items = audit["items"]
require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "INVARIANT_AUDIT_OVERALL")
require(audit["mass_conservation"] == "HARD_UNCHANGED", "HARD_MASS_UNCHANGED")
require(len(items) == 30 and [x["id"] for x in items] == list(range(1, 31)), "INVARIANT_IDS_1_TO_30")
require(all(x["result"] == "PASS" for x in items), "INVARIANTS_30_OF_30_PASS")

# Evidence artifact for exact-head CI.
evidence = {
    "work_unit": "F-DOC02",
    "head": sh("git", "rev-parse", "HEAD"),
    "tree": sh("git", "rev-parse", "HEAD^{tree}"),
    "fdoc01_base": BASE,
    "rb1_scientific_source": RB1_SOURCE,
    "frb01_qualification": FRB01,
    "frb02_release_metadata": FRB02,
    "frb02_exact_head_run": FRB02_RUN,
    "required_capabilities": registry_ids,
    "required_count": len(registry_ids),
    "unresolved_tiers_per_capability": EXPECTED_OPEN_TIERS,
    "t11": "SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED",
    "t13": "RESOLVED_RB1_RELEASE_SCOPE",
    "t14": "RESOLVED_RB1_RELEASE_AUTHORITY",
    "status_a_ready": False,
    "status_a_compliant": False,
    "status_aa_compliant": False,
    "production_delta": False,
    "reference_delta": False,
    "invariant_audit": "30_OF_30_NO_ADVERSE_DELTA"
}
(ROOT / "_fdoc02_rb1_traceability_evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
print("FDOC02_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_RB1_RELEASE_BOUND_TRACEABILITY_INDEX_WITH_EXPLICIT_GAPS")
