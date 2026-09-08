#!/usr/bin/env python3
"""Fail-closed structural validation for F-TA01 artifacts."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTER = ROOT / "test-architecture" / "test-register.json"
IMPACT = ROOT / "test-architecture" / "test-impact-map.json"
TEMPLATE = ROOT / "test-architecture" / "verification-contract-template.json"
STATUS = ROOT / "integration" / "f-ta" / "F-TA01_STATUS.json"

REQUIRED = {
    "test_id", "name", "category", "component", "workstream_owner",
    "scientific_process_or_contract", "requirement_or_invariant", "source_surface",
    "dependencies", "fixture", "expected_value_source", "tolerance_policy",
    "execution_command", "cost_class", "qualification_role", "current_status",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    registry, impact, template, status = map(load, (REGISTER, IMPACT, TEMPLATE, STATUS))
    tests = registry["tests"]
    ids = [item["test_id"] for item in tests]
    assert len(ids) == len(set(ids)), "test IDs are not unique"
    assert all(REQUIRED <= item.keys() for item in tests), "registry record lacks required fields"
    assert all(item["cost_class"] in {"FAST", "FOCUSED", "BROAD", "QUALIFICATION"} for item in tests)
    assert all(item["expected_value_source"] in {"ANALYTICAL", "THEORY", "CORRECTED_LEGACY_REFERENCE", "QUALIFIED_GOLDEN_CASE", "ARCHITECTURE_CONTRACT", "INVARIANT", "UNKNOWN", "NOT_ASSESSED"} for item in tests)
    registered = {item["artifact_path"] for item in tests}
    tracked = subprocess.check_output(["git", "ls-files", "tests", ".github/workflows"], cwd=ROOT, text=True).splitlines()
    missing = sorted(path for path in tracked if path not in registered)
    assert not missing, f"unregistered test/workflow artifacts: {missing}"
    assert impact["dependency_types"] == ["READ_ONLY", "STATE_MUTATING", "SHARED_CONTRACT", "NUMERICAL_POLICY", "PHYSICS", "QUALIFICATION_ONLY"]
    assert template["checkpoint_commit"] == "REQUIRED_BEFORE_BROAD_OR_QUALIFICATION"
    assert status["production_source_changed"] is False
    print(f"FTA01_STRUCTURE_PASS records={len(tests)} tracked_artifacts={len(tracked)}")


if __name__ == "__main__":
    main()
