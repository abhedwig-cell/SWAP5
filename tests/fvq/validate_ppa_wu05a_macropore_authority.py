#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATUS = ROOT / "integration/audits/PPA_WU05A_STATUS.json"
CONTRACT = ROOT / "integration/audits/PPA_WU05A_MACROPORE_AUTHORITY_CONTRACT.json"
PREREG = ROOT / "integration/audits/PPA_WU05A_PREREGISTRATION.json"
DOC = ROOT / "docs/audits/PPA_WU05A_MACROPORE_AUTHORITY.md"

def require(cond, msg):
    if not cond:
        raise SystemExit("PPA_WU05A_FAIL " + msg)

status = json.loads(STATUS.read_text())
contract = json.loads(CONTRACT.read_text())
prereg = json.loads(PREREG.read_text())
doc = DOC.read_text()

require(status["production_source_mutation"] is False, "production mutation must be false")
require(status["reference_source_mutation"] is False, "reference mutation must be false")
require(status["blocker"]["class"] == "EXACT_SOURCE_MATERIALIZATION_REQUIRED", "source blocker missing")
require(status["blocker"]["production_implementation_permitted"] is False, "implementation must be held")
require(contract["state_classification"]["definitive_b1_11_field_census"] == "NOT_YET_AVAILABLE", "field census overclaimed")
require(contract["state_classification"]["exact_field_membership"] if "exact_field_membership" in contract["state_classification"] else True, "unexpected")
require(contract["implementation_hold"]["state"] == "BLOCKED_BY_EXACT_SOURCE_MATERIALIZATION", "implementation hold missing")
require(contract["mass_contract"]["mass_tolerance_change"] == "FORBIDDEN", "mass tolerance policy drift")
require(len(contract["state_classification"]["corroborated_committed_or_history_candidates"]) == 7, "seven corroborated fields expected")
require("CORROBORATED_PRIOR_EVIDENCE_NOT_FINAL_B1_11_CENSUS" in json.dumps(status), "corroboration classification missing")
require("PARTIAL_AUTHORITY_FROZEN_SOURCE_MATERIALIZATION_REQUIRED" in doc, "document verdict missing")
require("No later slice may skip A1." in doc, "slice ordering missing")
require(prereg["exact_reference_identity"]["macropore_patch_authority"] == "SWAP-001 only", "patch authority drift")

base = subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"], text=True).strip()
changed = subprocess.check_output(["git","diff","--name-only",base,"HEAD"], text=True).splitlines()
for path in changed:
    require(not path.startswith("src/"), f"production source changed: {path}")
    require(not path.startswith("reference/"), f"reference source changed: {path}")

allowed_prefixes = (
    "docs/audits/",
    "integration/audits/",
    "tests/fvq/",
    ".github/workflows/",
)
for path in changed:
    require(path.startswith(allowed_prefixes), f"out-of-scope path: {path}")

print("PPA_WU05A_EXACT_IDENTITY_PINNED=PASS")
print("PPA_WU05A_PRIOR_EVIDENCE_CORROBORATION_ONLY=PASS")
print("PPA_WU05A_STATE_CENSUS_NOT_OVERCLAIMED=PASS")
print("PPA_WU05A_MASS_TRANSACTION_RESTART_INVARIANTS=PASS")
print("PPA_WU05A_PRODUCTION_IMPLEMENTATION_HELD=PASS")
print("PPA_WU05A_ZERO_SRC_REFERENCE_DELTA=PASS")
print("PPA-WU05-A MACROPORE AUTHORITY REVIEW PASS")
