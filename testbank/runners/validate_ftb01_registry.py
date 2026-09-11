#!/usr/bin/env python3
"""Fail-closed validator for the F-TB01 proof-of-concept registry.

The validator qualifies registry mechanics only. It does not execute or reinterpret
scientific assertions owned by the registered F-SI/F-MQ/F-CI/F-VQ authorities.
"""

from __future__ import annotations

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "testbank" / "manifests" / "F-TB01_CASE_REGISTRY.json"
REGISTRY_SCHEMA = ROOT / "testbank" / "schema" / "F-TB01_CASE_REGISTRY.schema.json"
REPORT_SCHEMA = ROOT / "testbank" / "schema" / "F-TB01_REPORT.schema.json"
STATUS = ROOT / "integration" / "f-tb" / "F-TB01_STATUS.json"
AUDIT = ROOT / "integration" / "f-tb" / "F-TB01_INVARIANT_AUDIT.json"

SHA40 = re.compile(r"^[0-9a-f]{40}$")
CASE_ID = re.compile(r"^SWAP5-TB-[A-Z0-9_-]+-[0-9]{3,5}$")
LEVELS = {f"TB-L{i}" for i in range(13)}
PROFILES = {"FAST", "CANONICAL", "RELEASE", "DEEP"}
CATEGORIES = {
    "PRIMITIVE", "HYDRAULICS", "PROCESS", "SOLVER", "TRANSACTION",
    "RESTART", "INTEGRATED", "LEGACY_REFERENCE", "COUPLING",
    "MULTISWAP", "PERFORMANCE", "ROBUSTNESS", "RELEASE",
}
ARTIFACT_KINDS = {"SOURCE_TEST", "QUALIFICATION_EVIDENCE", "GOVERNANCE_REPLAY"}
PURPOSES = {
    "HISTORICAL_QUALIFICATION", "MOVING_CURRENT_PRESERVATION",
    "BROAD_RELEASE_REGRESSION", "OWNER_VERIFICATION", "CHARACTERIZATION",
}
MATURITY = {
    "CHARACTERIZATION", "OWNER_TESTED", "INDEPENDENTLY_QUALIFIED",
    "CANONICAL_PRESERVATION", "RELEASE_MANDATORY",
}
ORACLES = {
    "O1_MATHEMATICAL_EXACT", "O2_MANUFACTURED_SOLUTION",
    "O3_INDEPENDENT_NUMERICAL_REFERENCE", "O4_QUALIFIED_FULL_RICHARDS_REFERENCE",
    "O5_LEGACY_SWAP431_SOURCE_BOUND", "O6_PROPERTY_INVARIANT",
    "O7_CROSS_SOLVER_CONSISTENCY",
}
MASS_GATES = {"REQUIRED", "NOT_WATER_BEARING", "INHERITED_EXACT_AUTHORITY"}
REQUIRED_CASE_KEYS = {
    "case_id", "version", "title", "layer", "category", "artifact_kind",
    "primary_path", "authority_ref", "admission_purpose", "maturity",
    "oracle_class", "profiles", "invariants", "negative_paths", "mass_gate",
    "current_preservation_eligible", "notes",
}
FROZEN_COMMIT = "3c5f5bd3686e1632058b906be21abd73883e30ef"
FROZEN_TREE = "6baaf40271497db831698c5a01de355b5d296dbe"
EXIT_TARGET = "SWAP5_TESTBANK_ARCHITECTURE_AND_CASE_REGISTRY_READY_FOR_INCREMENTAL_IMPLEMENTATION"


def load(path: pathlib.Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def fail(message: str) -> None:
    raise SystemExit(f"F-TB01 VALIDATION FAIL: {message}")


registry = load(REGISTRY)
registry_schema = load(REGISTRY_SCHEMA)
load(REPORT_SCHEMA)
status = load(STATUS)
audit = load(AUDIT)

if registry_schema.get("properties", {}).get("schema_version", {}).get("const") != "1.0":
    fail("registry schema version contract drift")
if registry.get("schema_version") != "1.0":
    fail("registry does not conform to schema version 1.0")
if not re.fullmatch(r"F-TB01-[A-Z0-9_-]+", registry.get("registry_id", "")):
    fail("invalid registry_id")
source = registry.get("source_authority", {})
if source.get("repository") != "abhedwig-cell/SWAP5" or source.get("ref") != "integration/f-ci-canonical":
    fail("unexpected source repository/ref authority")
if not SHA40.fullmatch(source.get("commit", "")) or not SHA40.fullmatch(source.get("tree", "")):
    fail("source authority is not exact commit/tree")
if source.get("commit") != FROZEN_COMMIT or source.get("tree") != FROZEN_TREE:
    fail("F-TB01 frozen canonical source authority drift")

items = audit.get("items", [])
if audit.get("overall") != "30_OF_30_NO_ADVERSE_DELTA" or len(items) != 30:
    fail("architecture invariant audit is incomplete")
if {item.get("id") for item in items} != set(range(1, 31)):
    fail("architecture invariant audit does not cover exactly invariants 1..30")
if any(item.get("result") != "PASS" for item in items):
    fail("architecture invariant audit contains a non-PASS item")
if audit.get("mass_conservation") != "HARD_UNCHANGED":
    fail("hard mass-conservation audit drift")
if status.get("exit_target") != EXIT_TARGET:
    fail("exit target drift")
for key in (
    "production_source_changed", "existing_test_changed", "qualified_reference_changed",
    "physics_changed", "solver_policy_changed", "runtime_semantics_changed", "io_adapter_changed",
):
    if status.get("scope_holds", {}).get(key) is not False:
        fail(f"scope hold is not explicitly false: {key}")

cases = registry.get("cases")
if not isinstance(cases, list) or not (5 <= len(cases) <= 10):
    fail("proof-of-concept registry must contain 5..10 representative cases")

seen = set()
resolved_paths = 0
for case in cases:
    if set(case) != REQUIRED_CASE_KEYS:
        missing = sorted(REQUIRED_CASE_KEYS - set(case))
        extra = sorted(set(case) - REQUIRED_CASE_KEYS)
        fail(f"case schema mismatch missing={missing} extra={extra}")
    case_id = case["case_id"]
    if not CASE_ID.fullmatch(case_id):
        fail(f"invalid case id: {case_id}")
    if case_id in seen:
        fail(f"duplicate case id: {case_id}")
    seen.add(case_id)
    if not isinstance(case["version"], int) or case["version"] < 1:
        fail(f"{case_id}: invalid version")
    if case["layer"] not in LEVELS:
        fail(f"{case_id}: invalid layer")
    if case["category"] not in CATEGORIES:
        fail(f"{case_id}: invalid category")
    if case["artifact_kind"] not in ARTIFACT_KINDS:
        fail(f"{case_id}: invalid artifact kind")
    if case["admission_purpose"] not in PURPOSES:
        fail(f"{case_id}: invalid admission purpose")
    if case["maturity"] not in MATURITY:
        fail(f"{case_id}: invalid maturity")
    if case["oracle_class"] not in ORACLES:
        fail(f"{case_id}: invalid oracle class")

    profiles = case["profiles"]
    if not isinstance(profiles, list) or not profiles or len(profiles) != len(set(profiles)) or not set(profiles) <= PROFILES:
        fail(f"{case_id}: invalid profiles")
    invariants = case["invariants"]
    if not isinstance(invariants, list) or not invariants or len(invariants) != len(set(invariants)):
        fail(f"{case_id}: invalid invariant bindings")
    if any(not isinstance(i, int) or i < 1 or i > 30 for i in invariants):
        fail(f"{case_id}: invariant binding outside 1..30")
    negatives = case["negative_paths"]
    if not isinstance(negatives, list) or len(negatives) != len(set(negatives)):
        fail(f"{case_id}: invalid negative paths")
    if case["mass_gate"] not in MASS_GATES:
        fail(f"{case_id}: invalid mass gate")
    if not isinstance(case["current_preservation_eligible"], bool):
        fail(f"{case_id}: preservation eligibility must be boolean")
    if not isinstance(case["authority_ref"], str) or not case["authority_ref"].strip():
        fail(f"{case_id}: empty authority ref")

    rel = pathlib.PurePosixPath(case["primary_path"])
    if rel.is_absolute() or ".." in rel.parts:
        fail(f"{case_id}: unsafe primary path")
    asset = ROOT.joinpath(*rel.parts)
    if not asset.is_file():
        fail(f"{case_id}: registered primary asset does not exist: {case['primary_path']}")
    resolved_paths += 1

if not any(case["mass_gate"] == "REQUIRED" for case in cases):
    fail("prototype contains no hard water-mass-gated case")
if not any(case["negative_paths"] for case in cases):
    fail("prototype contains no negative-path mapping")
if not any(case["admission_purpose"] == "BROAD_RELEASE_REGRESSION" for case in cases):
    fail("prototype contains no broad moving/release regression case")

print(f"F-TB01_REGISTRY_CASES={len(seen)}")
print(f"F-TB01_REGISTERED_PRIMARY_ASSETS_RESOLVED={resolved_paths}/{len(seen)}")
print("F-TB01_CASE_REGISTRY_SCHEMA_CONTRACT=PASS")
print("F-TB01_REPORT_SCHEMA_JSON=PASS")
print("F-TB01_INVARIANT_AUDIT=30/30_PASS")
print("F-TB01_HARD_MASS_POLICY=PASS")
print("F-TB01_GATE=PASS")
