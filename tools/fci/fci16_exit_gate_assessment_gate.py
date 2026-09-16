#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "integration" / "f-ci" / "F-CI16_EXIT_GATES.json"
EXPECTED_GATES = [f"CI-G{i:02d}" for i in range(1, 11)]
EXPECTED_STATUS = {
    "CI-G01": "QUALIFIED",
    "CI-G02": "BLOCKED",
    "CI-G03": "QUALIFIED",
    "CI-G04": "TESTED",
    "CI-G05": "BLOCKED",
    "CI-G06": "TESTED",
    "CI-G07": "TESTED",
    "CI-G08": "TESTED",
    "CI-G09": "TESTED",
    "CI-G10": "BLOCKED",
}
ALLOWED_STATUS = {
    "NOT_ASSESSED", "BLOCKED", "IMPLEMENTED", "PERSISTED", "TESTED", "QUALIFIED"
}
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> None:
    raise SystemExit(f"FCI16_GATE_FAIL: {message}")


def main() -> None:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    if data.get("work_unit") != "F-CI16":
        fail("work_unit")
    if data.get("canonical_branch") != "integration/f-ci-canonical":
        fail("canonical_branch")
    if data.get("gate_order") != EXPECTED_GATES:
        fail("gate_order")
    if data.get("downstream_release_allowed") is not False:
        fail("assessment must remain fail-closed")
    if data.get("production_source_unchanged_since_qualified_postimage") is not True:
        fail("unexpected production-source mutation assertion")

    gates = data.get("gates", {})
    if list(gates.keys()) != EXPECTED_GATES:
        fail("exact gate set")

    counts = Counter()
    for gate_id in EXPECTED_GATES:
        gate = gates[gate_id]
        status = gate.get("status")
        if status not in ALLOWED_STATUS:
            fail(f"{gate_id} invalid status")
        if status != EXPECTED_STATUS[gate_id]:
            fail(f"{gate_id} unexpected assessed status {status}")
        counts[status.lower()] += 1
        if gate.get("required") is not True:
            fail(f"{gate_id} must remain required")
        if not gate.get("evidence"):
            fail(f"{gate_id} lacks evidence")
        source = gate.get("source_commit")
        if not isinstance(source, str) or SHA40.fullmatch(source) is None:
            fail(f"{gate_id} source_commit")
        qual = gate.get("qualification_commit")
        if qual is not None and (not isinstance(qual, str) or SHA40.fullmatch(qual) is None):
            fail(f"{gate_id} qualification_commit")
        if status == "QUALIFIED":
            if qual is None:
                fail(f"{gate_id} qualified without qualification_commit")
            if gate.get("allows_downstream_release") is not True:
                fail(f"{gate_id} qualified but not individually releasing")
        else:
            if gate.get("allows_downstream_release") is not False:
                fail(f"{gate_id} non-qualified gate releases")
        if status == "BLOCKED" and not gate.get("blockers"):
            fail(f"{gate_id} blocked without blockers")
        if status == "TESTED" and not gate.get("holds"):
            fail(f"{gate_id} tested without qualification hold")
        if not gate.get("last_verified"):
            fail(f"{gate_id} lacks last_verified")

    summary = data.get("assessment_summary", {})
    expected_summary = {
        "qualified": counts["qualified"],
        "tested": counts["tested"],
        "blocked": counts["blocked"],
        "implemented": counts["implemented"],
        "persisted": counts["persisted"],
        "not_assessed": counts["not_assessed"],
    }
    if summary != expected_summary:
        fail(f"assessment_summary mismatch: {summary} != {expected_summary}")

    print("FCI16_EXIT_GATE_ASSESSMENT PASS")


if __name__ == "__main__":
    main()
