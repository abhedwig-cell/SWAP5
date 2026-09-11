#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "testbank/manifests/F-TB07_APPLICATION_ACCURACY_CONTRACT_CASES.json"
CONTRACT = ROOT / "integration/f-tb/F-TB07_WORK_UNIT_CONTRACT.json"
FTB06 = "163ed723cc4f2277746bdd54f338c4b06e2eaaa9"
CANONICAL = "c7379b6b5b5f529ff96de3087379712bd665276a"
SRC_TREE = "d5aec38b432242d2674885c8b8bd21d7f0fa0836"
REF_TREE = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
MODULE = "src/runtime/mod_coupling_application_accuracy_contract.f90"
MODULE_BLOB = "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc"
TEST = "tests/fci/test_fci44_application_accuracy_contract_admission.f90"
TEST_BLOB = "54200c6ded7b2783375e02cc646ec00f61b70770"
FGC10 = "a1201dc870e4f5088f50b8d00e92e83457743174"
FGC10_CLOSEOUT = "integration/f-gc/F-GC10_CLOSEOUT.json"
FGC10_CLOSEOUT_BLOB = "5fb26cbf003721791f38bbc7b78f5073886645c4"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def fail(msg: str) -> None:
    raise SystemExit("FTB07_VALIDATION_FAIL:" + msg)

m = json.loads(MANIFEST.read_text())
c = json.loads(CONTRACT.read_text())
cases = m.get("cases", [])
if len(cases) != 8:
    fail(f"case count {len(cases)} != 8")
ids = [x.get("case_id") for x in cases]
if len(ids) != len(set(ids)):
    fail("duplicate case IDs")
if not all(isinstance(x, str) and x.startswith("SWAP5-TB-COUPLING-ACC-") and x.endswith("-v1") for x in ids):
    fail("stable case-ID pattern")

expected_profiles = {"FAST": 3, "CANONICAL": 7, "RELEASE": 8, "DEEP": 8}
for p, n in expected_profiles.items():
    actual = sum(p in x.get("profiles", []) for x in cases)
    if actual != n:
        fail(f"profile {p} count {actual} != {n}")

required = {
    "SWAP5-TB-COUPLING-ACC-HEAD-0001-v1",
    "SWAP5-TB-COUPLING-ACC-DRAWDOWN-0002-v1",
    "SWAP5-TB-COUPLING-ACC-PROVENANCE-0003-v1",
    "SWAP5-TB-COUPLING-ACC-VALIDATION-0004-v1",
    "SWAP5-TB-COUPLING-ACC-STALE-0005-v1",
    "SWAP5-TB-COUPLING-ACC-BINDING-0006-v1",
    "SWAP5-TB-COUPLING-ACC-DETERMINISM-0007-v1",
    "SWAP5-TB-COUPLING-ACC-NONCLAIM-0008-v1",
}
if set(ids) != required:
    fail("required case set mismatch")

if git("rev-parse", "HEAD:src") != SRC_TREE:
    fail("current canonical source tree drift")
if git("rev-parse", "HEAD:reference") != REF_TREE:
    fail("current canonical reference tree drift")
if git("rev-parse", f"HEAD:{MODULE}") != MODULE_BLOB:
    fail("application-accuracy module blob drift")
if git("rev-parse", f"HEAD:{TEST}") != TEST_BLOB:
    fail("F-CI44 contract test blob drift")
if git("rev-parse", f"{FGC10}:{FGC10_CLOSEOUT}") != FGC10_CLOSEOUT_BLOB:
    fail("F-GC10 closeout blob drift")
if subprocess.call(["git", "merge-base", "--is-ancestor", FTB06, "HEAD"], cwd=ROOT) != 0:
    fail("F-TB07 does not descend from exact F-TB06 authority")

changed = git("diff", "--name-only", f"{FTB06}..HEAD").splitlines()
allowed_prefixes = (
    "testbank/manifests/F-TB07_",
    "testbank/runners/validate_ftb07_",
    "testbank/runners/run_ftb07_",
    "integration/f-tb/F-TB07_",
    "integration/f-tb/RUNLOG_F-TB07.md",
    "docs/testbank/F-TB07_",
    ".github/workflows/ftb07-",
)
for path in changed:
    if path and not path.startswith(allowed_prefixes):
        fail("unexpected delta from F-TB06 authority: " + path)

if c.get("canonical_authority") != CANONICAL:
    fail("work-unit canonical authority mismatch")
if c.get("target_decision") != "QUALIFIED_GROUNDWATER_APPLICATION_ACCURACY_CONTRACT_TESTBANK_ADOPTION_READY_FOR_CONTINUOUS_QUALIFICATION":
    fail("target decision mismatch")

closeout = json.loads(git("show", f"{FGC10}:{FGC10_CLOSEOUT}"))
if closeout.get("decision") != "QUALIFIED_F_GC09_APPLICATION_ACCURACY_CONTRACT_FOR_CANONICAL_ADMISSION_WITH_EXPLICIT_TEMPORAL_INDICATOR_BINDING":
    fail("F-GC10 decision mismatch")
for key in ("production_coupling_admission", "numeric_policy_qualified", "application_class_accuracy_qualified", "mass_conservation_relaxed"):
    if closeout.get(key) is not False:
        fail("F-GC10 nonclaim drift: " + key)

print(f"FTB07_CURRENT_CANONICAL_AUTHORITY=PASS:{CANONICAL}")
print(f"FTB07_FTB06_PARENT_AUTHORITY=PASS:{FTB06}")
print(f"FTB07_CASE_REGISTRY=PASS:COUNT={len(cases)}")
print("FTB07_PROFILE_COUNTS=PASS:FAST=3,CANONICAL=7,RELEASE=8,DEEP=8")
print("FTB07_FGC10_NONCLAIMS=PASS")
print("FTB07_PRODUCTION_SOURCE_CHANGED=NO")
print("FTB07_REFERENCE_CHANGED=NO")
print("FTB07_RB1_REOPENED=NO")
