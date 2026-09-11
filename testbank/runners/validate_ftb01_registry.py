#!/usr/bin/env python3
"""Fail-closed validator for the F-TB01 proof-of-concept registry."""

from __future__ import annotations

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "testbank" / "manifests" / "F-TB01_CASE_REGISTRY.json"
REPORT_SCHEMA = ROOT / "testbank" / "schema" / "F-TB01_REPORT.schema.json"
STATUS = ROOT / "integration" / "f-tb" / "F-TB01_STATUS.json"
AUDIT = ROOT / "integration" / "f-tb" / "F-TB01_INVARIANT_AUDIT.json"

SHA40 = re.compile(r"^[0-9a-f]{40}$")
CASE_ID = re.compile(r"^SWAP5-TB-[A-Z0-9-]+-v[1-9][0-9]*$")
LEVELS = {f"TB-L{i}" for i in range(13)}
PROFILES = {"FAST", "CANONICAL", "RELEASE", "DEEP"}
ORACLES = {
    "O1_MATHEMATICAL_EXACT",
    "O2_MANUFACTURED_SOLUTION",
    "O3_INDEPENDENT_NUMERICAL_REFERENCE",
    "O4_QUALIFIED_FULL_RICHARDS_REFERENCE",
    "O5_LEGACY_SWAP431_SOURCE_BOUND",
    "O6_PROPERTY_INVARIANT",
    "O7_CROSS_SOLVER_CONSISTENCY",
}
TOLERANCE_CLASSES = {
    "FP_IDENTITY",
    "NUMERICAL_SOLVER",
    "SCIENTIFIC_COMPARISON",
    "APPLICATION",
    "COUPLING",
}


def load(path: pathlib.Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def fail(message: str) -> None:
    raise SystemExit(f"F-TB01 VALIDATION FAIL: {message}")


registry = load(REGISTRY)
load(REPORT_SCHEMA)
status = load(STATUS)
audit = load(AUDIT)

if registry.get("schema") != "swap5.testbank.case_registry.v1":
    fail("unexpected registry schema")
if set(registry.get("profiles", [])) != PROFILES:
    fail("profile vocabulary drift")
if set(registry.get("oracle_classes", [])) != ORACLES:
    fail("oracle vocabulary drift")
if set(registry.get("tolerance_classes", [])) != TOLERANCE_CLASSES:
    fail("tolerance vocabulary drift")
if audit.get("overall") != "30_OF_30_NO_ADVERSE_DELTA" or len(audit.get("items", [])) != 30:
    fail("architecture invariant audit is incomplete")
if status.get("exit_target") != "SWAP5_TESTBANK_ARCHITECTURE_AND_CASE_REGISTRY_READY_FOR_INCREMENTAL_IMPLEMENTATION":
    fail("exit target drift")

seen = set()
for case in registry.get("cases", []):
    case_id = case.get("case_id", "")
    if not CASE_ID.match(case_id):
        fail(f"unversioned or invalid case id: {case_id}")
    if case_id in seen:
        fail(f"duplicate case id: {case_id}")
    seen.add(case_id)

    if case.get("level") not in LEVELS:
        fail(f"{case_id}: invalid level")
    profiles = set(case.get("profiles", []))
    if not profiles or not profiles <= PROFILES:
        fail(f"{case_id}: invalid or empty profiles")

    oracle = case.get("oracle", {})
    if oracle.get("class") not in ORACLES:
        fail(f"{case_id}: unknown oracle class")
    tolerance_classes = set(case.get("tolerances", {}).get("classes", []))
    if not tolerance_classes <= TOLERANCE_CLASSES:
        fail(f"{case_id}: unknown tolerance class")

    mass = case.get("mass_gate", {})
    if mass.get("mode") == "REQUIRED":
        if not mass.get("rule") or not mass.get("ledger"):
            fail(f"{case_id}: required mass gate lacks ledger or rule")
    elif mass.get("mode") == "NOT_APPLICABLE":
        if not mass.get("reason"):
            fail(f"{case_id}: NOT_APPLICABLE mass gate lacks reason")
    else:
        fail(f"{case_id}: mass gate must be REQUIRED or NOT_APPLICABLE")

    registry_status = case.get("status")
    source = case.get("source_authority")
    immutable_oracle = oracle.get("immutable_authority")
    if registry_status == "REGISTERED_EXISTING":
        if not isinstance(source, dict):
            fail(f"{case_id}: existing case lacks source authority")
        if not SHA40.match(source.get("commit", "")) or not SHA40.match(source.get("tree", "")):
            fail(f"{case_id}: existing authority is not exact commit/tree")
        if not source.get("path"):
            fail(f"{case_id}: existing authority lacks path")
        path = pathlib.PurePosixPath(source["path"])
        if path.is_absolute() or ".." in path.parts:
            fail(f"{case_id}: unsafe source path")
        if not SHA40.match(immutable_oracle or ""):
            fail(f"{case_id}: existing oracle lacks immutable authority")
    elif registry_status == "REGISTERED_FUTURE":
        if not case.get("gap_reason"):
            fail(f"{case_id}: future case lacks explicit gap reason")
    else:
        fail(f"{case_id}: unsupported registry status")

if len(seen) < 8:
    fail("proof-of-concept registry is too small to exercise the architecture")

print(f"F-TB01_REGISTRY_CASES={len(seen)}")
print("F-TB01_REPORT_SCHEMA_JSON=PASS")
print("F-TB01_INVARIANT_AUDIT=30/30_PASS")
print("F-TB01_HARD_MASS_POLICY=PASS")
print("F-TB01_GATE=PASS")
