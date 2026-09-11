#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess

VALID = "37a146cab2207668e500379cbd569e9241be4bdb"
INCIDENT = "a840c0ce545eb2aafd74b90c46864da166af2f1e"
REPAIR = "82280e350ea7514cc9f394db882d5cb3ef25b18c"
VALID_TREE = "80f3b62037eec92e83d981df1f57489ddd1af76e"
INCIDENT_TREE = "3fdf0a09ee0199b5aaa26710fb82cff54397ca45"
EMPTY_BLOB = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
RECORD = Path("integration/f-ci/F-CI47R_INCIDENT_REMEDIATION.json")


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, text=True, capture_output=True).stdout.strip()


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit("FCI47R_FAIL: " + msg)


for sha in (VALID, INCIDENT, REPAIR):
    subprocess.run(["git", "cat-file", "-e", f"{sha}^{{commit}}"], check=True)

require(git("rev-parse", f"{INCIDENT}^") == VALID, "incident parent is not valid F-CI47 promotion")
require(git("rev-parse", f"{REPAIR}^") == INCIDENT, "repair parent is not incident")
require(git("rev-parse", f"{VALID}^{{tree}}") == VALID_TREE, "valid promotion tree drift")
require(git("rev-parse", f"{INCIDENT}^{{tree}}") == INCIDENT_TREE, "incident tree drift")
require(git("rev-parse", f"{REPAIR}^{{tree}}") == VALID_TREE, "repair tree does not restore valid promotion tree")
print("FCI47R_TREE_RESTORATION_IDENTITY=PASS")

incident_delta = [x for x in git("diff", "--name-only", VALID, INCIDENT).splitlines() if x]
repair_delta = [x for x in git("diff", "--name-only", INCIDENT, REPAIR).splitlines() if x]
require(incident_delta == ["dummy"], f"unexpected incident delta {incident_delta}")
require(repair_delta == ["dummy"], f"unexpected repair delta {repair_delta}")
require(git("rev-parse", f"{INCIDENT}:dummy") == EMPTY_BLOB, "dummy is not exact empty blob")
print("FCI47R_ACCIDENTAL_PATH_SCOPE=PASS")

require(git("diff", "--name-only", VALID, REPAIR, "--", "src", "reference") == "", "src/reference net delta")
require(git("rev-parse", f"{VALID}:src") == git("rev-parse", f"{REPAIR}:src"), "src tree drift")
require(git("rev-parse", f"{VALID}:reference") == git("rev-parse", f"{REPAIR}:reference"), "reference tree drift")
print("FCI47R_SRC_REFERENCE_UNCHANGED=PASS")

record = json.loads(RECORD.read_text())
require(record["incident"]["commit"] == INCIDENT, "incident record mismatch")
require(record["remediation"]["commit"] == REPAIR, "repair record mismatch")
require(record["post_remediation_qualification"]["canonical_workflow_run"] == 34646474926, "workflow run mismatch")
require(record["post_remediation_qualification"]["overall_conclusion"] == "success", "overall workflow not recorded green")
require(record["post_remediation_qualification"]["current_restricted_canonical_preservation_conclusion"] == "success", "preservation job not recorded green")
require(record["incident"]["production_src_changed"] is False, "incident source-change claim")
require(record["incident"]["reference_changed"] is False, "incident reference-change claim")
print("FCI47R_INCIDENT_RECORD_INTERNAL_CONSISTENCY=PASS")

require(git("diff", "--name-only", REPAIR, "HEAD", "--", "src", "reference") == "", "audit branch changes src/reference")
print("FCI47R_AUDIT_BRANCH_SUPPORT_ONLY=PASS")
print("FCI47R_INCIDENT_REMEDIATION_AUDIT=PASS")
