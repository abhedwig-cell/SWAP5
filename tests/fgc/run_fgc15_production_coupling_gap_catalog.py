#!/usr/bin/env python3
import json
import pathlib
import re
import subprocess
import sys

BASE = "82280e350ea7514cc9f394db882d5cb3ef25b18c"
CURRENT = "0b284b5f4e224c5f76d7d78b9dbb51c99514479d"
CATALOG = pathlib.Path("integration/f-gc/F-GC15_PRODUCTION_COUPLING_GAP_CATALOG.json")
AUDIT = pathlib.Path("integration/f-gc/F-GC15_ARCHITECTURE_AUDIT.json")
RECHECK = pathlib.Path("integration/f-gc/F-GC15_CURRENT_CANONICAL_RECHECK.json")
EXPECTED_IDS = [f"GC15-G{i:02d}" for i in range(1, 10)]
ALLOWED_PREFIXES = (
    "integration/f-gc/F-GC15_",
    "tests/fgc/run_fgc15_",
    ".github/workflows/fgc15-",
)

def fail(msg):
    print(f"FGC15_FAIL: {msg}")
    sys.exit(1)

def sh(*args):
    return subprocess.check_output(args, text=True).strip()

def read(path):
    return pathlib.Path(path).read_text()

def show(ref, path):
    return sh("git", "show", f"{ref}:{path}")

def type_block(text, typename):
    m = re.search(rf"type, public :: {re.escape(typename)}(.*?)end type {re.escape(typename)}", text, re.S | re.I)
    if not m:
        fail(f"missing type {typename}")
    return m.group(1).lower()

head = sh("git", "rev-parse", "HEAD")
merge_base = sh("git", "merge-base", BASE, head)
if merge_base != BASE:
    fail(f"branch is not based on frozen canonical {BASE}")

changed = [x for x in sh("git", "diff", "--name-only", f"{BASE}..HEAD").splitlines() if x]
for path in changed:
    if path.startswith("src/") or path.startswith("reference/"):
        fail(f"production/reference mutation forbidden: {path}")
    if not path.startswith(ALLOWED_PREFIXES):
        fail(f"out-of-scope path: {path}")
print("FGC15_NO_PRODUCTION_SOURCE_DELTA=PASS")

catalog = json.loads(CATALOG.read_text())
audit = json.loads(AUDIT.read_text())
recheck = json.loads(RECHECK.read_text())
if catalog.get("canonical_base") != BASE:
    fail("catalog canonical base mismatch")
if recheck.get("frozen_catalog_base") != BASE or recheck.get("rechecked_live_canonical") != CURRENT:
    fail("current-canonical recheck metadata mismatch")
if catalog.get("classification") != "PRODUCTION_COUPLING_NOT_YET_ADMITTED":
    fail("catalog classification mismatch")
if catalog.get("mass_conservation_relaxed") is not False:
    fail("mass conservation may not be relaxed")
ids = [g.get("id") for g in catalog.get("gaps", [])]
if ids != EXPECTED_IDS:
    fail(f"gap IDs/order mismatch: {ids}")
if catalog.get("implementation_order") != EXPECTED_IDS:
    fail("implementation order mismatch")
by_id = {g["id"]: g for g in catalog["gaps"]}
for gid, g in by_id.items():
    for dep in g.get("depends_on", []):
        if dep not in by_id or EXPECTED_IDS.index(dep) >= EXPECTED_IDS.index(gid):
            fail(f"invalid dependency {dep} -> {gid}")
print("FGC15_GAP_GRAPH=PASS")

inv = audit.get("invariants", {})
if set(inv) != {str(i) for i in range(1, 31)}:
    fail("architecture audit must cover invariants 1..30 exactly")
if audit.get("result") != "PASS_WITH_EXPLICIT_DOWNSTREAM_REQUIREMENTS":
    fail("architecture audit result mismatch")
print("FGC15_ARCHITECTURE_INVARIANTS_30_OF_30=PASS")

# Frozen canonical contains no production groundwater/MODFLOW/predictor-corrector orchestrator.
def assert_no_orchestrator(ref, label):
    paths = sh("git", "ls-tree", "-r", "--name-only", ref, "src").splitlines()
    for path in paths:
        low = path.lower()
        if re.search(r"modflow|groundwater.*coupl|coupling.*window|predictor.*corrector|corrector.*predictor", low):
            fail(f"unexpected production coupling orchestrator/adapter path in {label}: {path}")

assert_no_orchestrator(BASE, "frozen base")
print("FGC15_NO_EXISTING_PRODUCTION_GW_ORCHESTRATOR=PASS")

# Solver primitive exists, but frozen transaction/canonical result carriers do not transport it.
solver = read("src/solver/mod_soil_water_solver_contract.f90")
tx = read("src/transaction/mod_transaction_reference.f90")
canon = read("src/runtime/mod_canonical_contracts.f90")
if "type, public :: soil_water_interface_sensitivity_t" not in solver or "interface_sensitivity" not in solver:
    fail("solver interface sensitivity primitive missing")
if "interface_sensitivity" in type_block(tx, "transaction_result_t"):
    fail("transaction_result_t unexpectedly transports interface sensitivity; catalog stale")
if "interface_sensitivity" in type_block(canon, "canonical_result_t"):
    fail("canonical_result_t unexpectedly transports interface sensitivity; catalog stale")
print("FGC15_ACCEPTED_SENSITIVITY_TRANSPORT_GAP=PASS")

# Pin the canonical application-accuracy and transactional primitives.
expected_blobs = {
    "src/runtime/mod_coupling_application_accuracy_contract.f90": "c07d573d21e7d013ab962c0a9d28102ab7b5cdfc",
    "src/runtime/mod_coupling_application_accuracy_adapter.f90": "9212d600e89c85287e9280832c7e0a94befb642e",
    "src/transaction/mod_transaction_reference.f90": "2fd932b74dbd0ffc0ec089f49e632b7ac8852df4",
    "src/runtime/mod_canonical_contracts.f90": "c06aa869a0bd479df4c7d6e1d0b4f5c07a207144",
    "src/runtime/mod_canonical_interval_runtime.f90": "55f3d271aa6200a994fd0144d6fce0701c918a74",
}
for path, expected in expected_blobs.items():
    actual = sh("git", "rev-parse", f"{BASE}:{path}")
    if actual != expected:
        fail(f"blob drift {path}: {actual} != {expected}")
print("FGC15_CANONICAL_PRIMITIVE_BLOBS=PASS")

# Pin upstream qualification nonclaims.
checks = [
    ("277dda9b7d808ca4e3233488e087e4e2179ddc2a", "integration/f-gc/F-GC07_CLOSEOUT.json", "\"production_admission\": false", "\"whole_coupling_window_derivative_composition_qualified\": false"),
    ("5b514e678d0d794e5837f161033b0bac58385707", "integration/f-si/F-SI28_CLOSEOUT.json", "\"whole_coupling_window_derivative_composition_qualified\": false", "\"MODFLOW_coupling_admitted\": false"),
]
for commit, path, token1, token2 in checks:
    try:
        body = show(commit, path)
    except subprocess.CalledProcessError:
        fail(f"historical authority object unavailable: {commit}:{path}")
    if token1 not in body or token2 not in body:
        fail(f"upstream nonclaim pin failed: {path}")
print("FGC15_UPSTREAM_NONCLAIMS_PINNED=PASS")

# F-CI48 moved canonical after preregistration. It is an allowed live recheck only
# if it leaves the coupling/result-transport evidence unchanged.
if sh("git", "merge-base", BASE, CURRENT) != BASE:
    fail("live canonical is not a descendant of the frozen catalog base")
expected_fci48_src = {
    "src/runtime/mod_fmr_restart_state_contract.f90",
    "src/runtime/mod_fmr_runtime_core.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
}
actual_fci48_src = set(x for x in sh("git", "diff", "--name-only", f"{BASE}..{CURRENT}", "--", "src").splitlines() if x)
if actual_fci48_src != expected_fci48_src:
    fail(f"unexpected F-CI48 source delta: {sorted(actual_fci48_src)}")
for path, expected in expected_blobs.items():
    actual = sh("git", "rev-parse", f"{CURRENT}:{path}")
    if actual != expected:
        fail(f"live canonical changed coupling primitive {path}: {actual} != {expected}")
assert_no_orchestrator(CURRENT, "F-CI48 live canonical")
current_tx = show(CURRENT, "src/transaction/mod_transaction_reference.f90")
current_canon = show(CURRENT, "src/runtime/mod_canonical_contracts.f90")
if "interface_sensitivity" in type_block(current_tx, "transaction_result_t"):
    fail("F-CI48 transaction_result_t now transports interface sensitivity; catalog stale")
if "interface_sensitivity" in type_block(current_canon, "canonical_result_t"):
    fail("F-CI48 canonical_result_t now transports interface sensitivity; catalog stale")
if recheck.get("revalidated_findings", {}).get("gap_catalog_decision_changed") is not False:
    fail("live recheck must preserve gap decision")
print("FGC15_FCI48_LIVE_CANONICAL_RECHECK=PASS")

if catalog.get("decision") != "PRODUCTION_COUPLING_RUNTIME_NOT_READY_IMPLEMENT_MISSING_CAPABILITIES_IN_DEPENDENCY_ORDER":
    fail("decision mismatch")
print("FGC15_PRODUCTION_COUPLING_READINESS_DECISION=PASS")
print("FGC15_PRODUCTION_COUPLING_GAP_CATALOG PASS")
