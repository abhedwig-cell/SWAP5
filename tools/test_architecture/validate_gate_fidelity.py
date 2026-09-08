#!/usr/bin/env python3
"""Fail-closed F-TA03 executable-gate fidelity and claim validation."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OVERLAY = ROOT / "test-architecture" / "gate-fidelity-metadata.json"
REGISTER = ROOT / "test-architecture" / "test-register.json"
CASES = ROOT / "test-architecture" / "gate-fidelity-validation-cases.json"

REQUIRED = {
    "physical_fixture_fidelity",
    "numerical_solver_fidelity",
    "state_update_capability",
    "solver_tolerance_provenance",
    "numerical_control_provenance",
    "claim_classes",
    "owner_qualification_status",
}

FUNCTIONAL_NUMERICAL_FIDELITY = {
    "PRODUCTION_REFERENCE",
    "QUALIFIED_REFERENCE_SUBSTITUTE",
    "SYNTHETIC_FUNCTIONAL",
}
COMPLETE_PROVENANCE = {
    "EXPLICIT_SOURCE_BOUND",
    "RUNNER_LOCAL_EXPLICIT",
    "OWNER_EVIDENCE_EXTERNAL",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def assess(record: dict, numerical_behavior_claims: set[str]) -> dict:
    blockers: list[str] = []
    missing = sorted(REQUIRED - record.keys())
    if missing:
        return {"decision": "BLOCKED", "blockers": ["MISSING_REQUIRED_METADATA"] + [f"MISSING:{item}" for item in missing]}

    claims = set(record["claim_classes"])
    if claims & numerical_behavior_claims:
        if record["state_update_capability"] != "CAPABLE":
            blockers.append("NUMERICAL_STATE_UPDATE_NOT_CAPABLE")
        if record["numerical_solver_fidelity"] not in FUNCTIONAL_NUMERICAL_FIDELITY:
            blockers.append("NUMERICAL_SOLVER_FIDELITY_INCOMPATIBLE")
        if record["solver_tolerance_provenance"] not in COMPLETE_PROVENANCE:
            blockers.append("SOLVER_TOLERANCE_PROVENANCE_INCOMPLETE")
        if record["numerical_control_provenance"] not in COMPLETE_PROVENANCE:
            blockers.append("NUMERICAL_CONTROL_PROVENANCE_INCOMPLETE")

    if "SCIENTIFIC_ADMISSION" in claims and not str(record["owner_qualification_status"]).startswith("OWNER_"):
        blockers.append("SCIENTIFIC_ADMISSION_REQUIRES_EXTERNAL_OWNER_AUTHORITY")

    return {
        "decision": "BLOCKED" if blockers else "CLAIMS_COMPATIBLE",
        "blockers": blockers,
    }


def validate_enums(record: dict, overlay: dict) -> None:
    assert record["physical_fixture_fidelity"] in set(overlay["physical_fixture_fidelity_classes"])
    assert record["numerical_solver_fidelity"] in set(overlay["numerical_solver_fidelity_classes"])
    assert record["state_update_capability"] in set(overlay["state_update_capability_classes"])
    assert record["solver_tolerance_provenance"] in set(overlay["solver_tolerance_provenance_classes"])
    assert record["numerical_control_provenance"] in set(overlay["numerical_control_provenance_classes"])
    assert set(record["claim_classes"]) <= set(overlay["claim_classes"])


def validate_evidence(record: dict) -> None:
    evidence = record.get("numerical_fidelity_evidence", [])
    assert evidence, f"{record['artifact_path']}: numerical fidelity has no source evidence"
    for item in evidence:
        path = ROOT / item["path"]
        assert path.is_file(), f"{record['artifact_path']}: missing evidence path {item['path']}"
        text = path.read_text(encoding="utf-8")
        for token in item["required_tokens"]:
            assert token in text, f"{record['artifact_path']}: missing evidence token {token!r} in {item['path']}"


def main() -> None:
    overlay = load(OVERLAY)
    registry = load(REGISTER)
    corpus = load(CASES)
    numerical_behavior_claims = set(overlay["numerical_behavior_claims"])

    assert overlay["authority"] == "TEST_REGISTER_FIDELITY_OVERLAY_ONLY"
    assert overlay["join_key"] == "artifact_path"
    assert numerical_behavior_claims == {"CONVERGENCE_BEHAVIOR", "SOLVER_COST", "PERFORMANCE_TAIL"}

    registered = {item["artifact_path"]: item for item in registry["tests"]}
    paths = [record["artifact_path"] for record in overlay["records"]]
    assert len(paths) == len(set(paths)), "duplicate gate-fidelity artifact_path"

    reviewed = 0
    for record in overlay["records"]:
        path = record["artifact_path"]
        assert path in registered, f"gate fidelity metadata references unregistered artifact: {path}"
        assert registered[path]["execution_command"] != "NOT_DIRECTLY_EXECUTABLE", f"metadata target is not executable: {path}"
        assert REQUIRED <= record.keys(), f"{path}: required fidelity metadata missing"
        validate_enums(record, overlay)
        result = assess(record, numerical_behavior_claims)
        assert result["decision"] == "CLAIMS_COMPATIBLE", f"{path}: incompatible claims {result['blockers']}"
        validate_evidence(record)
        reviewed += 1

    positive = negative = 0
    for case in corpus["cases"]:
        record = case["record"]
        validate_enums(record, overlay)
        result = assess(record, numerical_behavior_claims)
        assert result["decision"] == case["expected_decision"], f"{case['case_id']}: decision {result}"
        required = set(case.get("required_blockers", []))
        assert required <= set(result["blockers"]), f"{case['case_id']}: missing blockers {required - set(result['blockers'])}"
        if result["decision"] == "CLAIMS_COMPATIBLE":
            positive += 1
        else:
            negative += 1

    print(f"FTA03_GATE_FIDELITY_OVERLAY_PASS reviewed={reviewed}")
    print(f"FTA03_CLAIM_CORPUS_PASS positive={positive} negative_fail_closed={negative}")
    print("FTA03_ZERO_STEP_NUMERICAL_BEHAVIOR_CLAIMS=FAIL_CLOSED")
    print("FTA03_SCIENTIFIC_ADMISSION_AUTHORITY=EXTERNAL_OWNER_ONLY")


if __name__ == "__main__":
    main()
