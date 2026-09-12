#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REG = ROOT / "docs/scientific/registries/fdoc15-status-a-readiness-gap-assessment.json"
SCI = ROOT / "docs/scientific/F-DOC15_SCI_FOUND_01_ASSESSMENT.md"
MAIN = ROOT / "docs/scientific/F-DOC15_STATUS_A_READINESS_FINAL_GAP_ASSESSMENT.md"
STATUS = ROOT / "docs/scientific/registries/F-DOC15_STATUS.json"

x = json.loads(REG.read_text())
assert x["criterion_authority"]["denominator_count"] == 22
assert x["criterion_authority"]["percentage_reporting"] is False
assert len(x["requirements"]) == 22
ids = [r["id"] for r in x["requirements"]]
expected = ["1.1","1.2","2.1","2.2","2.3","3.1","3.2","3.3","3.4","4.1","4.2","4.3","4.4","4.5","5.1","5.2","6.1","6.2","6.3","6.4","7.1","7.2"]
assert ids == expected
allowed = set(x["allowed_classifications"])
for row in x["requirements"]:
    assert row["rb1"] in allowed
    assert row["current"] in allowed
assert x["formal_status_a_certification_claimed"] is False
assert x["ready_for_formal_status_a_assessment"] is False
assert x["documentation_authority_recheck"]["qualified"] == [f"F-DOC{i:02d}" for i in range(1,14)]
assert x["documentation_authority_recheck"]["not_independent_authority"] == ["F-DOC14"]
assert x["assessment_objects"]["rb1"]["scientific_source_sha"] == "0aeb0a2ed4096e1f9493d3dabc70962ea5270182"
assert x["assessment_objects"]["rb1"]["qualification_sha"] == "aeb74560d801c4ac7314df7b8845fcc5daf8bba6"
assert x["assessment_objects"]["rb1"]["release_metadata_sha"] == "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
assert x["assessment_objects"]["current_canonical_snapshot"]["sha"] == "e537baf521e633c432a9f33de495fab9f18e918d"
assert x["assessment_objects"]["current_canonical_snapshot"]["tree"] == "b55f077657fc82b421a63f927965ff47821fc987"
assert x["scientific_foundation"]["id"] == "SCI-FOUND-01"
assert x["scientific_foundation"]["state"] == "OPEN_BLOCKER"
assert x["scientific_foundation"]["rb1_closed"] is False
assert x["scientific_foundation"]["current_closed"] is False
chain = x["scientific_foundation"]["required_chain"]
assert chain == ["physical_system","modelling_purpose","spatial_temporal_scales","system_boundary","abstraction_idealisation","conceptual_model","formal_mathematical_model","numerical_realization","implementation"]
assert x["scientific_foundation"]["process_specific_formal_authorities_remain_authoritative"] is True
for req in ("1.1","1.2","4.5","7.1"):
    row = next(r for r in x["requirements"] if r["id"] == req)
    assert "SCI-FOUND-01" in row["blockers"]
assert any(b["id"] == "WR-QA-2024" and b["blocks"] for b in x["closure_backlog"])
assert any(b["id"] == "APPLICATION-VALIDATION-T12" and b["blocks"] for b in x["closure_backlog"])
assert any(b["id"] == "CURRENT-CANONICAL-FREEZE" and b.get("blocks_current") for b in x["closure_backlog"])

sci = SCI.read_text()
for token in [
    "physical system -> modelling purpose -> spatial and temporal scales -> system boundary -> abstraction and idealisation -> conceptual model -> formal mathematical model -> numerical realization -> implementation",
    "one-dimensional column abstraction",
    "Status-A closure gap",
    "F-DOC16",
    "process-specific formal authorities remain authoritative"
]:
    assert token in sci

main = MAIN.read_text()
for token in [
    "QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_AND_CLOSURE_PLAN_ESTABLISHED",
    "does **not** claim `QUALIFIED_READY_FOR_FORMAL_STATUS_A_ASSESSMENT`",
    "Verification, conservation, legacy comparison and cross-solver qualification are not validation",
    "F-DOC14: **not** a distinct qualified authority",
    "22 requirements"
]:
    assert token in main

if STATUS.exists():
    status = json.loads(STATUS.read_text())
    assert status["decision"] == "QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_AND_CLOSURE_PLAN_ESTABLISHED_WHEN_EXACT_HEAD_CI_GREEN"
    assert status["ready_for_formal_status_a_assessment"] is False
    assert status["status_a_certified"] is False

print("FDOC15_DENOMINATOR_22_EXACT=PASS")
print("FDOC15_ALLOWED_CLASSIFICATIONS_ONLY=PASS")
print("FDOC15_RB1_CURRENT_SEPARATED=PASS")
print("FDOC15_DOC01_DOC13_QUALIFIED_DOC14_EXCLUDED=PASS")
print("FDOC15_SCI_FOUND_01_OPEN_BLOCKER=PASS")
print("FDOC15_VERIFICATION_NOT_VALIDATION=PASS")
print("FDOC15_NO_STATUS_A_CERTIFICATION=PASS")
print("FDOC15_CLOSURE_BACKLOG_PRESENT=PASS")
print("FDOC15_DECISION_IF_EXACT_HEAD_GREEN=QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_AND_CLOSURE_PLAN_ESTABLISHED")
