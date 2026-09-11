#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = "82280e350ea7514cc9f394db882d5cb3ef25b18c"
COMPOSE = "4172e7e639d13e178fb75471263636a6cfa792fc"
FTB07 = "4fd0e3a4cb30254135c8da086a733eb3c790b834"
FGC14 = "6d91bedc305504cc2fa08b196e6a9903c48c9461"
SRC_TREE = "c03a94cdfdf96e61e1a7a5aa92ff4d7533d234be"
REF_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
ADAPTER = "src/runtime/mod_coupling_application_accuracy_adapter.f90"
ADAPTER_BLOB = "9212d600e89c85287e9280832c7e0a94befb642e"
CONTRACT = "src/runtime/mod_coupling_application_accuracy_contract.f90"
CONTRACT_BLOB = "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
DONOR_TEST = "tests/fgc/test_fgc14_external_accuracy_adapter.f90"
DONOR_TEST_BLOB = "7f4f8f044b06ad3e445e4499b575bb98e424c2a0"
FGC14_CLOSEOUT = "integration/f-gc/F-GC14_CLOSEOUT.json"
FGC14_CLOSEOUT_BLOB = "202dd875b44e1865c6d96da981b690137e451a38"
FCI46_STATUS = "integration/f-ci/F-CI46_STATUS.json"
FCI46_STATUS_BLOB = "3c49657ad84294c4c48e080dba3726bdd3f1734a"
MANIFEST = ROOT / "testbank/manifests/F-TB08_EXTERNAL_ACCURACY_ADAPTER_CASES.json"
WU = ROOT / "integration/f-tb/F-TB08_WORK_UNIT_CONTRACT.json"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def fail(msg):
    raise SystemExit("FTB08_VALIDATION_FAIL:" + msg)

def require(ok, msg):
    if not ok: fail(msg)

m = json.loads(MANIFEST.read_text())
w = json.loads(WU.read_text())
cases = m.get("cases", [])
require(len(cases) == 8, "case count")
ids = [c.get("case_id") for c in cases]
require(len(ids) == len(set(ids)), "duplicate IDs")
require(all(isinstance(x, str) and x.startswith("SWAP5-TB-COUPLING-EXTACC-") and x.endswith("-v1") for x in ids), "case ID pattern")
for profile, expected in {"FAST":3,"CANONICAL":7,"RELEASE":8,"DEEP":8}.items():
    require(sum(profile in c.get("profiles", []) for c in cases) == expected, "profile count " + profile)

require(git("rev-parse", f"{COMPOSE}^") == CANONICAL, "composition parent")
require(git("diff", "--name-only", CANONICAL, COMPOSE, "--", "src", "reference") == "", "composition touched src/reference")
require(git("rev-parse", f"{COMPOSE}:testbank") == git("rev-parse", f"{FTB07}:testbank"), "F-TB07 testbank subtree drift")
require(git("rev-parse", f"{COMPOSE}:docs/testbank") == git("rev-parse", f"{FTB07}:docs/testbank"), "F-TB07 docs subtree drift")
require(git("rev-parse", f"{COMPOSE}:integration/f-tb") == git("rev-parse", f"{FTB07}:integration/f-tb"), "F-TB07 evidence subtree drift")
for wf in (
    "ftb01-testbank-architecture.yml","ftb02-hydraulic-case-catalog.yml","ftb03-rb1-release-bank.yml",
    "ftb04-transaction-restart-determinism-multiswap.yml","ftb05-current-canonical-continuous-qualification.yml",
    "ftb06-soil-temperature-runtime-adoption.yml","ftb07-application-accuracy-contract-adoption.yml"):
    path = ".github/workflows/" + wf
    require(git("rev-parse", f"{COMPOSE}:{path}") == git("rev-parse", f"{FTB07}:{path}"), "inherited workflow drift " + wf)

require(git("rev-parse", "HEAD:src") == SRC_TREE, "canonical src tree drift")
require(git("rev-parse", "HEAD:reference") == REF_TREE, "reference tree drift")
require(git("rev-parse", f"HEAD:{ADAPTER}") == ADAPTER_BLOB, "adapter blob drift")
require(git("rev-parse", f"HEAD:{CONTRACT}") == CONTRACT_BLOB, "accuracy contract blob drift")
require(git("rev-parse", f"{FGC14}:{DONOR_TEST}") == DONOR_TEST_BLOB, "donor test drift")
require(git("rev-parse", f"{FGC14}:{FGC14_CLOSEOUT}") == FGC14_CLOSEOUT_BLOB, "F-GC14 closeout drift")
require(git("rev-parse", f"HEAD:{FCI46_STATUS}") == FCI46_STATUS_BLOB, "F-CI46 status drift")

changed = [x for x in git("diff", "--name-only", COMPOSE, "HEAD").splitlines() if x]
allowed = (
    "testbank/manifests/F-TB08_", "testbank/runners/validate_ftb08_", "testbank/runners/run_ftb08_",
    "integration/f-tb/F-TB08_", "integration/f-tb/RUNLOG_F-TB08.md", "docs/testbank/F-TB08_",
    ".github/workflows/ftb08-"
)
require(all(p.startswith(allowed) for p in changed), "unexpected F-TB08 delta: " + ",".join(changed))
require(w.get("canonical_authority") == CANONICAL, "canonical authority in contract")
require(w.get("target_decision") == "QUALIFIED_EXTERNAL_ACCURACY_RUNTIME_ADAPTER_TESTBANK_ADOPTION_READY_FOR_CONTINUOUS_QUALIFICATION", "target decision")

closeout = json.loads(git("show", f"{FGC14}:{FGC14_CLOSEOUT}"))
require(closeout.get("status") == "CLOSED_QUALIFIED", "F-GC14 not closed qualified")
require(closeout.get("canonical_admission") is False, "F-GC14 canonical nonclaim drift")
require(closeout.get("production_coupling_admission") is False, "production coupling nonclaim drift")
require(closeout.get("numeric_project_policy_qualified") is False, "numeric policy nonclaim drift")
require(closeout.get("mass_conservation_relaxed") is False, "mass nonclaim drift")
require(closeout.get("external_source_bytes_verified_by_adapter") is False, "source verification boundary drift")

src = (ROOT / ADAPTER).read_text().lower()
for forbidden in ("open(", "read(", "json", ".swp", "filepath", "file_path"):
    require(forbidden not in src, "adapter contains forbidden I/O/policy token " + forbidden)

print(f"FTB08_CURRENT_CANONICAL_AUTHORITY=PASS:{CANONICAL}")
print(f"FTB08_FTB07_SUPPORT_AUTHORITY=PASS:{FTB07}")
print("FTB08_IMMUTABLE_TESTBANK_COMPOSITION=PASS")
print("FTB08_ADAPTER_PROVENANCE=PASS")
print("FTB08_CASE_REGISTRY=PASS:COUNT=8")
print("FTB08_PROFILE_COUNTS=PASS:FAST=3,CANONICAL=7,RELEASE=8,DEEP=8")
print("FTB08_SOURCE_VERIFICATION_BOUNDARY=PASS")
print("FTB08_PRODUCTION_SOURCE_CHANGED=NO")
print("FTB08_REFERENCE_CHANGED=NO")
print("FTB08_MASS_CONSERVATION_RELAXED=NO")
