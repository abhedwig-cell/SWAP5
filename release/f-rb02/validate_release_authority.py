#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

BASE = "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
SCI = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
SRC_TREE = "8ceeb70a64012631ebba295f5c045ea908b0681f"
REF_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
MANIFEST = Path("release/f-rb02/SWAP5_RB1_V1_RELEASE_AUTHORITY.json")

EXPECTED_BLOBS = {
    "release/f-rb01/RESTRICTED_PRODUCTION_BASELINE_V1_SCOPE.json": "09df8417fe12bcc2eca9d9320117264737ffc83a",
    "release/f-rb01/RB1_CAPABILITY_MATRIX.json": "e20e0b2cae1cfde91c8736ad632059b4fe480d88",
    "release/f-rb01/RB1_ARCHITECTURE_INVARIANT_AUDIT.json": "ea9ac771a47e9d165af0e3a5ab445b23578b9160",
    "release/f-rb01/RB1_RELEASE_QUALIFICATION.json": "f2d55a945dde6e379f2df1c3cbbd8706b1bbaa09",
    "release/f-rb01/RESTRICTED_PRODUCTION_BASELINE_V1_RELEASE.md": "04d0f9e7c887773279c5ebcd85b03444264b8ddd",
    "release/f-rb01/RB1_TESTBANK_CROSSWALK.json": "e47deeb03e58825deab3331ab4b5f293a65dec71",
}

ALLOWED_CHANGED_PREFIXES = ("release/f-rb02/",)
ALLOWED_CHANGED_EXACT = {".github/workflows/frb02-final-release-authority.yml"}


def sh(*args):
    return subprocess.check_output(args, text=True).strip()


def require(cond, marker):
    if not cond:
        print(f"FRB02_FAIL={marker}", file=sys.stderr)
        raise SystemExit(1)
    print(f"FRB02_{marker}=PASS")


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


m = load(MANIFEST)
scope = load("release/f-rb01/RESTRICTED_PRODUCTION_BASELINE_V1_SCOPE.json")
cap = load("release/f-rb01/RB1_CAPABILITY_MATRIX.json")
audit = load("release/f-rb01/RB1_ARCHITECTURE_INVARIANT_AUDIT.json")
qual = load("release/f-rb01/RB1_RELEASE_QUALIFICATION.json")
closeout = load("release/f-rb01/F-RB01_CLOSEOUT.json")

head = sh("git", "rev-parse", "HEAD")
head_tree = sh("git", "rev-parse", "HEAD^{tree}")

require(sh("git", "merge-base", HEAD if False else "HEAD", BASE) == BASE, "FRB01_BASE_ANCESTRY")
require(sh("git", "rev-parse", f"{SCI}:src") == SRC_TREE, "SCIENTIFIC_SOURCE_SRC_TREE")
require(sh("git", "rev-parse", f"{SCI}:reference") == REF_TREE, "SCIENTIFIC_SOURCE_REFERENCE_TREE")
require(sh("git", "rev-parse", "HEAD:src") == SRC_TREE, "HEAD_SRC_TREE_IDENTITY")
require(sh("git", "rev-parse", "HEAD:reference") == REF_TREE, "HEAD_REFERENCE_TREE_IDENTITY")

for path, expected in EXPECTED_BLOBS.items():
    require(sh("git", "rev-parse", f"HEAD:{path}") == expected, "FROZEN_BLOB_" + path.split("/")[-1].replace(".", "_").upper())

changed = [x for x in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
for path in changed:
    require(path in ALLOWED_CHANGED_EXACT or path.startswith(ALLOWED_CHANGED_PREFIXES), "GOVERNANCE_ONLY_" + path.replace("/", "_").replace(".", "_").upper())

require(m["release_id"] == "SWAP5-RB1-v1", "RELEASE_ID")
require(m["three_authorities"]["RB1_SCIENTIFIC_SOURCE_AUTHORITY"]["sha"] == SCI, "MANIFEST_SCIENTIFIC_AUTHORITY")
require(m["three_authorities"]["RB1_QUALIFICATION_AUTHORITY"]["frb01_final_qualification_head"] == BASE, "MANIFEST_QUALIFICATION_AUTHORITY")
require(m["frozen_scope"]["required_denominator"] == 15, "MANIFEST_DENOMINATOR")
require(scope["required_capability_denominator"] == 15, "SCOPE_DENOMINATOR")
require(len(scope["required_capabilities"]) == 15, "SCOPE_REQUIRED_COUNT")
require(cap["summary"]["required_total"] == 15 and cap["summary"]["required_integrated_pass"] == 15 and cap["summary"]["required_gaps"] == 0, "CAPABILITY_MATRIX_15_OF_15")
require(audit["summary"]["total"] == 30 and audit["summary"]["fail"] == 0 and audit["summary"]["applicable_failures"] == 0, "ARCHITECTURE_30_ZERO_FAIL")
require(qual["status"] == "QUALIFIED" and qual["decision"] == "QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_READY_FOR_RELEASE_AUTHORITY", "FRB01_QUALIFICATION_DECISION")
require(qual["frozen_release_candidate"]["src_tree"] == SRC_TREE and qual["frozen_release_candidate"]["reference_tree"] == REF_TREE, "FROZEN_CANDIDATE_SOURCE_IDENTITY")
require(closeout["open_rb1_blockers"] == 0, "ZERO_OPEN_RB1_BLOCKERS")
require(closeout["production_changes_by_frb01"] == [] and closeout["scientific_authority_changes_by_frb01"] == [], "FRB01_ZERO_PRODUCTION_SCIENTIFIC_DELTA")
require(m["scope_change"] is False and m["production_source_change"] is False and m["reference_change"] is False and m["acceptance_threshold_change"] is False, "FRB02_ZERO_SCIENTIFIC_DELTA_DECLARATION")

# Preserve the explicit performance scope boundary rather than silently broadening it.
nonclaims = "\n".join(m["explicit_release_nonclaims"])
require("throughput/scaling remains a separate performance workunit" in nonclaims, "SURFACE_EVAP_THROUGHPUT_NONCLAIM")

report = {
    "schema": "swap5.frb02_exact_head_evidence.v1",
    "head_sha": head,
    "head_tree": head_tree,
    "base_frb01_head": BASE,
    "scientific_source_authority": SCI,
    "src_tree": sh("git", "rev-parse", "HEAD:src"),
    "reference_tree": sh("git", "rev-parse", "HEAD:reference"),
    "changed_paths_since_frb01": changed,
    "required_capabilities": 15,
    "required_pass": 15,
    "architecture_fail": 0,
    "open_rb1_blockers": 0,
    "zero_production_delta": True,
}
Path("_frb02_release_authority_evidence.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"FRB02_EXACT_HEAD_SHA={head}")
print(f"FRB02_EXACT_HEAD_TREE={head_tree}")
print("FRB02_DECISION_IF_WORKFLOW_GREEN=QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_RELEASE_AUTHORITY_ESTABLISHED")
