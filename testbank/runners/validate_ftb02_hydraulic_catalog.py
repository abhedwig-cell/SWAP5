#!/usr/bin/env python3
"""Fail-closed validator and evidence replay for F-TB02.

F-TB02 qualifies catalog bindings and replayable historical evidence only. It does
not requalify production SWAP5 physics and it must never upgrade a historical or
source-presence record into moving-current preservation by implication.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "testbank/manifests/F-TB02_HYDRAULIC_CASE_REGISTRY.json"
SCHEMA = ROOT / "testbank/schema/F-TB02_HYDRAULIC_CASE_REGISTRY.schema.json"
STATUS = ROOT / "integration/f-tb/F-TB02_STATUS.json"
AUDIT = ROOT / "integration/f-tb/F-TB02_INVARIANT_AUDIT.json"
RESULT = ROOT / "reference/swap-4.3.1/patches/SWAP-009/tests/result_gfortran14_2.json"
SWAP009_QUAL = ROOT / "reference/swap-4.3.1/patches/SWAP-009/qualification.md"
SWAP011_QUAL = ROOT / "reference/swap-4.3.1/patches/SWAP-011/qualification.md"

ARCH_COMMIT = "1d039292d5768496c4550a8e1b35a92c6f836504"
ARCH_TREE = "217ad406db38b564a8b03e6c34c26b9123b58c6c"
CURRENT_COMMIT = "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
CURRENT_TREE = "c77ac75aea522ac20a60da012595af9166efcff6"
SWAP009_COMMIT = "7b5f4650b0c7aa2799a33c49f0d5f36983b2f9f5"
SWAP009_TREE = "cf12791ea4bcbda3bf6b3238c68ec043ea4885e1"
EXIT_TARGET = "QUALIFIED_FTB02_HYDRAULIC_CASE_CATALOG_FOUNDATION_READY_FOR_INCREMENTAL_ORACLE_EXPANSION"
CASE_RE = re.compile(r"^SWAP5-TB-[A-Z0-9_-]+-[0-9]{3,5}-v[1-9][0-9]*$")
SHA40 = re.compile(r"^[0-9a-f]{40}$")

EXPECTED_BLOBS = {
    (SWAP009_COMMIT, "reference/swap-4.3.1/patches/SWAP-009/tests/run_hydraulic_gate.py"): "d76d95ce25257774f0594877949e84d341de7d6e",
    (SWAP009_COMMIT, "reference/swap-4.3.1/patches/SWAP-009/tests/result_gfortran14_2.json"): "b27adf27eb1d197470edbb8682d815765f989b45",
    (SWAP009_COMMIT, "reference/swap-4.3.1/patches/SWAP-011/qualification.md"): "b0dd8e5a3ad812c8e18cac3c96108ace3bf64162",
    (CURRENT_COMMIT, "tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90"): "ecacaf1c004c7118f1ada388c672166d9ad19345",
}

REQUIRED_CASE_KEYS = {
    "case_id", "version", "title", "layer", "category", "artifact_kind",
    "physics", "solver", "parameters", "forcing", "initial_state", "interval",
    "oracle", "tolerance_policy", "provenance", "source_authority",
    "test_matrix_authority", "evidence_authority", "governance_authority",
    "admission_purpose", "maturity", "compiler_requirements", "cost_class",
    "profiles", "requiredness", "invariants", "negative_paths", "mass_gate",
    "current_preservation_eligible", "lineage", "notes",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def fail(message: str) -> None:
    raise SystemExit(f"F-TB02 VALIDATION FAIL: {message}")


def git(*args: str) -> str:
    cp = subprocess.run(["git", *args], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if cp.returncode != 0:
        fail(f"git {' '.join(args)} failed: {cp.stderr.strip()}")
    return cp.stdout.strip()


def assert_exact_commit(commit: str, tree: str, label: str) -> None:
    if not SHA40.fullmatch(commit) or not SHA40.fullmatch(tree):
        fail(f"{label} is not exact 40-hex authority")
    git("cat-file", "-e", f"{commit}^{{commit}}")
    actual = git("rev-parse", f"{commit}^{{tree}}")
    if actual != tree:
        fail(f"{label} tree mismatch: {actual} != {tree}")


manifest = load(MANIFEST)
load(SCHEMA)
status = load(STATUS)
audit = load(AUDIT)

if manifest.get("schema_version") != "1.0" or manifest.get("registry_id") != "F-TB02-HYDRAULIC_CONSTITUTIVE_FRAGMENT":
    fail("registry identity/version drift")
arch = manifest.get("architecture_authority", {})
if arch != {"work_unit": "F-TB01", "commit": ARCH_COMMIT, "tree": ARCH_TREE}:
    fail("F-TB01 architecture authority drift")
cur = manifest.get("current_canonical_context", {})
if cur.get("ref") != "integration/f-ci-canonical" or cur.get("commit") != CURRENT_COMMIT or cur.get("tree") != CURRENT_TREE:
    fail("current canonical context drift")
if cur.get("use") != "SOURCE_CONTEXT_ONLY_NOT_AUTOMATIC_PRESERVATION_AUTHORITY":
    fail("current canonical context semantics drift")

assert_exact_commit(ARCH_COMMIT, ARCH_TREE, "architecture authority")
assert_exact_commit(CURRENT_COMMIT, CURRENT_TREE, "current canonical context")
assert_exact_commit(SWAP009_COMMIT, SWAP009_TREE, "SWAP-009 historical authority")

cases = manifest.get("cases")
if not isinstance(cases, list) or len(cases) != 5:
    fail("initial fragment must contain exactly five bounded cases")
seen = set()
for case in cases:
    if set(case) != REQUIRED_CASE_KEYS:
        fail(f"{case.get('case_id', '<unknown>')}: case metadata contract mismatch")
    cid = case["case_id"]
    if not CASE_RE.fullmatch(cid) or cid in seen:
        fail(f"invalid or duplicate case id: {cid}")
    seen.add(cid)
    if case["current_preservation_eligible"] is not False:
        fail(f"{cid}: historical/source-presence case may not claim current preservation")
    if case["admission_purpose"] not in {"HISTORICAL_QUALIFICATION", "CHARACTERIZATION"}:
        fail(f"{cid}: unsupported admission purpose in bounded F-TB02 fragment")
    if case["maturity"] not in {"OWNER_TESTED", "CHARACTERIZATION"}:
        fail(f"{cid}: maturity overclaim")
    if not isinstance(case["invariants"], list) or not case["invariants"] or any((not isinstance(i, int) or i < 1 or i > 30) for i in case["invariants"]):
        fail(f"{cid}: invalid architecture invariant bindings")
    sa = case["source_authority"]
    commit, tree, path = sa.get("commit", ""), sa.get("tree", ""), sa.get("path", "")
    assert_exact_commit(commit, tree, f"{cid} source authority")
    obj = git("rev-parse", f"{commit}:{path}")
    expected_blob = EXPECTED_BLOBS.get((commit, path))
    if expected_blob is not None and obj != expected_blob:
        fail(f"{cid}: exact source blob drift {obj} != {expected_blob}")
    tp = case["tolerance_policy"]
    if tp.get("mode") == "EXACT_OR_HARD_ONLY" and tp.get("bindings"):
        fail(f"{cid}: exact/hard policy may not carry soft bindings")
    if tp.get("mode") == "GOVERNED_BINDINGS":
        if not tp.get("bindings"):
            fail(f"{cid}: governed tolerance policy lacks binding")
        for binding in tp["bindings"]:
            needed = {"id", "version", "class", "quantity", "unit", "meaning", "scope", "rationale", "provenance", "owner", "evidence"}
            if set(binding) != needed:
                fail(f"{cid}: incomplete governed tolerance binding")
            if binding["id"] != "F-TB02-TOL-PDI-KELVIN-RATIO" or binding["version"] != 1:
                fail(f"{cid}: unexpected tolerance identity")
            if binding["meaning"] != "relative error <= 1e-9":
                fail(f"{cid}: historical Kelvin tolerance was reinterpreted")

by_id = {c["case_id"]: c for c in cases}
dk = by_id.get("SWAP5-TB-HYD-DKDH-0004-v1")
if dk is None or dk["admission_purpose"] != "CHARACTERIZATION" or dk["maturity"] != "CHARACTERIZATION" or dk["governance_authority"]["kind"] != "NOT_ADMITTED":
    fail("SWAP-011 must remain fail-closed CHARACTERIZATION / NOT_ADMITTED")
fsi = by_id.get("SWAP5-TB-SOLVER-B110-0005-v1")
if fsi is None or fsi["admission_purpose"] != "CHARACTERIZATION" or fsi["maturity"] != "CHARACTERIZATION":
    fail("current FSI24 source presence must remain characterization")
if any(c["admission_purpose"] == "MOVING_CURRENT_PRESERVATION" for c in cases):
    fail("F-TB02 contains an unqualified moving-current preservation claim")

# Replay the independent Kelvin calculation from the frozen recorded evidence.
result = load(RESULT)
if result.get("status") != "PASS" or result.get("gate") != "SWAP-009-exact-candidate-PDI-hydraulic-function-level":
    fail("SWAP-009 recorded function gate status/identity drift")
if result.get("model") != 8 or result.get("temperature_c") != 20.0 or result.get("ratio_tolerance") != 1e-9:
    fail("SWAP-009 frozen matrix/tolerance drift")
rows = result.get("comparisons", [])
if [r.get("h_cm") for r in rows] != [-100000.0, -1000000.0, -10000000.0]:
    fail("SWAP-009 frozen head matrix drift")
mg_rt = (0.018015 * 9.81 / 8.314) / (20.0 + 273.15)
max_rel = 0.0
for row in rows:
    if row["water_content_delta"] != 0.0 or row["k_no_vap_delta"] != 0.0:
        fail("SWAP-009 non-target exact identity failed")
    ratio = row["old_kvap"] / row["corrected_kvap"]
    theory = math.exp(2.0 * abs(row["h_cm"]) / 100.0 * mg_rt)
    rel = abs(ratio - theory) / theory
    if not math.isclose(ratio, row["old_over_corrected_kvap"], rel_tol=0.0, abs_tol=1e-13):
        fail("recorded SWAP-009 vapor ratio is internally inconsistent")
    if not math.isclose(theory, row["independent_kelvin_ratio"], rel_tol=0.0, abs_tol=max(1e-15, abs(theory)*1e-15)):
        fail("recorded SWAP-009 analytical Kelvin target is internally inconsistent")
    if not math.isclose(rel, row["relative_ratio_error"], rel_tol=1e-9, abs_tol=1e-18):
        fail("recorded SWAP-009 relative error is internally inconsistent")
    if rel > result["ratio_tolerance"] or row.get("pass") is not True:
        fail("SWAP-009 Kelvin replay exceeds frozen tolerance")
    max_rel = max(max_rel, rel)

q009 = SWAP009_QUAL.read_text(encoding="utf-8")
if "Current B1 admission status: **ADMITTED IN B1.6**" not in q009:
    fail("SWAP-009 B1.6 admission statement missing")
q011 = SWAP011_QUAL.read_text(encoding="utf-8")
if "B1 admission status: **CANDIDATE, NOT YET ADMITTED**" not in q011 or "exact final E7 `fix.patch` payload must be recovered" not in q011:
    fail("SWAP-011 non-admission/provenance blocker statement missing")

items = audit.get("items", [])
if audit.get("overall") != "30_OF_30_NO_ADVERSE_DELTA" or len(items) != 30 or {i.get("id") for i in items} != set(range(1, 31)) or any(i.get("result") != "PASS" for i in items):
    fail("F-TB02 architecture invariant audit incomplete")
if audit.get("mass_conservation") != "HARD_UNCHANGED":
    fail("hard mass contract drift")

if status.get("exit_target") != EXIT_TARGET:
    fail("F-TB02 exit target drift")
if status.get("decision") not in {"PENDING_VALIDATION", EXIT_TARGET}:
    fail("unexpected F-TB02 status decision")
for key in ("production_source_changed", "existing_test_changed", "qualified_reference_changed", "physics_changed", "solver_policy_changed", "runtime_semantics_changed", "io_adapter_changed"):
    if status.get("scope_holds", {}).get(key) is not False:
        fail(f"scope hold not explicit false: {key}")

print(f"F-TB02_CASES={len(cases)}")
print("F-TB02_LAYERS=TB-L0,TB-L1,TB-L3")
print("F-TB02_EXACT_SOURCE_AUTHORITIES=PASS")
print("F-TB02_SWAP009_B16_ADMISSION_BINDING=PASS")
print("F-TB02_SWAP011_FAIL_CLOSED_CHARACTERIZATION=PASS")
print("F-TB02_CURRENT_SOURCE_PRESENCE_NOT_PRESERVATION=PASS")
print(f"F-TB02_KELVIN_REPLAY_MAX_RELERR={max_rel:.17g}")
print("F-TB02_KELVIN_REPLAY=PASS")
print("F-TB02_NON_TARGET_EXACT_IDENTITY=PASS")
print("F-TB02_INVARIANT_AUDIT=30/30_PASS")
print("F-TB02_HARD_MASS_POLICY=PASS")
print("F-TB02_GATE=PASS")
