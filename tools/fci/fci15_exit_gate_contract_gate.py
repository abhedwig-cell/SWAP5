#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "integration" / "f-ci" / "F-CI15_EXIT_GATES.json"
EXPECTED_GATES = [f"CI-G{i:02d}" for i in range(1, 11)]
ALLOWED_STATUS = [
    "NOT_ASSESSED",
    "BLOCKED",
    "IMPLEMENTED",
    "PERSISTED",
    "TESTED",
    "QUALIFIED",
]
REQUIRED_FIELDS = {
    "status",
    "required",
    "evidence",
    "source_commit",
    "qualification_commit",
    "blockers",
    "holds",
    "last_verified",
    "allows_downstream_release",
}
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> None:
    raise SystemExit(f"FCI15_GATE_FAIL: {message}")


def valid_sha_or_null(value) -> bool:
    return value is None or (isinstance(value, str) and SHA40.fullmatch(value) is not None)


def main() -> None:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        fail("schema_version")
    if data.get("work_unit") != "F-CI15":
        fail("work_unit")
    if data.get("canonical_branch") != "integration/f-ci-canonical":
        fail("canonical_branch")
    if data.get("status_values") != ALLOWED_STATUS:
        fail("status vocabulary")
    if data.get("gate_order") != EXPECTED_GATES:
        fail("gate order")

    gates = data.get("gates")
    if not isinstance(gates, dict) or list(gates.keys()) != EXPECTED_GATES:
        fail("exact CI-G01..CI-G10 gate set")

    release_by_gates = True
    for gate_id in EXPECTED_GATES:
        gate = gates[gate_id]
        missing = REQUIRED_FIELDS.difference(gate)
        if missing:
            fail(f"{gate_id} missing {sorted(missing)}")
        if gate["status"] not in ALLOWED_STATUS:
            fail(f"{gate_id} invalid status")
        if not isinstance(gate["required"], bool):
            fail(f"{gate_id} required must be boolean")
        for field in ("evidence", "blockers", "holds"):
            if not isinstance(gate[field], list):
                fail(f"{gate_id} {field} must be list")
        for field in ("source_commit", "qualification_commit"):
            if not valid_sha_or_null(gate[field]):
                fail(f"{gate_id} {field} must be null or 40-char lowercase SHA")
        if gate["last_verified"] is not None and not isinstance(gate["last_verified"], str):
            fail(f"{gate_id} last_verified")
        if not isinstance(gate["allows_downstream_release"], bool):
            fail(f"{gate_id} allows_downstream_release must be boolean")
        if gate["status"] != "QUALIFIED" and gate["allows_downstream_release"]:
            fail(f"{gate_id} releases without QUALIFIED status")
        if gate["required"]:
            release_by_gates = release_by_gates and gate["status"] == "QUALIFIED" and gate["allows_downstream_release"]

    if data.get("downstream_release_allowed") is not release_by_gates:
        fail("top-level downstream release flag inconsistent with required gates")

    print("FCI15_EXIT_GATE_CONTRACT PASS")


if __name__ == "__main__":
    main()
