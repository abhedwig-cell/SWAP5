#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "integration/audits/PPA_WU05C_OXYGEN_STRESS_AUTHORITY_CONTRACT.json"
STATUS = ROOT / "integration/audits/PPA_WU05C_STATUS.json"
PREREG = ROOT / "integration/audits/PPA_WU05C_PREREGISTRATION.json"
DOC = ROOT / "docs/audits/PPA_WU05C_OXYGEN_STRESS_AUTHORITY.md"
SWAP007 = ROOT / "reference/swap-4.3.1/patches/SWAP-007/fix.patch"
ROOT_OWNER = ROOT / "src/process/mod_root_water_uptake_process.f90"

def fail(msg):
    print(f"PPA_WU05C_FAIL {msg}", file=sys.stderr)
    raise SystemExit(1)

for p in (CONTRACT, STATUS, PREREG, DOC, SWAP007, ROOT_OWNER):
    if not p.exists():
        fail(f"missing {p.relative_to(ROOT)}")

contract = json.loads(CONTRACT.read_text())
status = json.loads(STATUS.read_text())
prereg = json.loads(PREREG.read_text())
doc = DOC.read_text()
swap007 = SWAP007.read_text()
root = ROOT_OWNER.read_text()

if contract.get("workunit") != "PPA-WU05-C":
    fail("wrong contract workunit")
if status.get("work_unit") != "PPA-WU05-C":
    fail("wrong status workunit")
if prereg.get("workunit") != "PPA-WU05-C":
    fail("wrong prereg workunit")

auth = contract["authority"]["oxygenstress"]
if auth["b0_sha256"] != "2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75":
    fail("B0 oxygenstress identity drift")
if auth["b1_11_sha256"] != "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87":
    fail("B1.11 oxygenstress identity drift")
if auth["only_admitted_b0_to_b1_change"] != "SWAP-007":
    fail("SWAP-007 scope widened")
if auth["physics_model_change"]:
    fail("SWAP-007 incorrectly classified as physics change")

if "tiny(1.0d0)" not in swap007 or "huge(1.0d0)" not in swap007:
    fail("SWAP-007 exact representability guard unavailable")
if "root_extraction_sink" not in root:
    fail("current root sink owner unavailable")

owners = contract["owner_classification"]
if owners["authoritative_root_water_mass_owner"] != "existing nodewise root_extraction_sink owner":
    fail("single root-water mass owner not preserved")
if "not an independent water-mass transfer owner" not in owners["oxygen_process_role"]:
    fail("oxygen process mass role widened")

cache = contract["state_classification"]["shared_derived_cache"]
expected = {"d_soil_term1","d_soil_term2","gfp100","capac_term","nmin1","mplus1"}
if set(cache["corroborated_fields"]) != expected:
    fail("derived oxygen cache field set drift")
if cache["classification"] != "IMMUTABLE_AFTER_CONSTRUCTION_SHARED_DERIVED_DATA":
    fail("oxygen cache classification drift")
if cache["restart"] or cache["rollback"]:
    fail("derived oxygen cache wrongly placed in restart/rollback")

hold = contract["implementation_hold"]
if hold["state"] != "BLOCKED_BY_FULL_B1_11_OXYGEN_ROOT_CALLSITE_SOURCE_MATERIALIZATION":
    fail("production hold missing")
for token in (
    "production oxygen-stress module",
    "oxygen-active MODFLOW tangent claim",
    "parallel oxygen claim",
):
    if token not in hold["forbidden_until_met"]:
        fail(f"missing forbidden claim: {token}")

coupling = contract["coupling_contract"]
if not coupling["fail_closed"]:
    fail("oxygen coupling derivative coverage does not fail closed")
if coupling["runtime_finite_difference_fallback_admitted"]:
    fail("unqualified FD fallback admitted")

required_doc = [
    "PARTIAL_AUTHORITY_FROZEN",
    "SWAP-007",
    "root_extraction_sink",
    "shared derived data",
    "PPA-WU05-C1",
    "Production implementation remains held",
]
for token in required_doc:
    if token not in doc:
        fail(f"documentation missing token: {token}")

# Review-only surface: compare against current PR base/merge base if available.
subprocess.run(["git","fetch","origin","integration/f-ci-canonical","--quiet"], cwd=ROOT, check=True)
base = subprocess.check_output(
    ["git","merge-base","HEAD","origin/integration/f-ci-canonical"], cwd=ROOT, text=True
).strip()
changed = subprocess.check_output(
    ["git","diff","--name-only",f"{base}...HEAD"], cwd=ROOT, text=True
).splitlines()
for path in changed:
    if path.startswith("src/"):
        fail(f"production source mutation: {path}")
    if path.startswith("reference/"):
        fail(f"reference mutation: {path}")

allowed_prefixes = (
    "integration/audits/PPA_WU05C_",
    "docs/audits/PPA_WU05C_",
    "tests/fvq/validate_ppa_wu05c_",
    ".github/workflows/ppa-wu05c-",
)
for path in changed:
    if not path.startswith(allowed_prefixes):
        fail(f"out-of-scope review delta: {path}")

print("PPA_WU05C_B1_11_OXYGEN_AUTHORITY=PASS")
print("PPA_WU05C_SWAP007_SCOPE_PRESERVED=PASS")
print("PPA_WU05C_SINGLE_ROOT_MASS_OWNER=PASS")
print("PPA_WU05C_SHARED_DERIVED_CACHE=PASS")
print("PPA_WU05C_NO_CACHE_RESTART_ROLLBACK=PASS")
print("PPA_WU05C_COUPLING_DERIVATIVE_FAIL_CLOSED=PASS")
print("PPA_WU05C_PRODUCTION_IMPLEMENTATION_HELD=PASS")
print("PPA_WU05C_ZERO_SRC_REFERENCE_DELTA=PASS")
print("PPA-WU05-C OXYGEN-STRESS AUTHORITY REVIEW PASS")
