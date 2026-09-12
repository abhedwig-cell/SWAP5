#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REG = ROOT / "docs/scientific/registries/fdoc15-status-a-readiness-gap-assessment.json"
MAIN = ROOT / "docs/scientific/F-DOC15_STATUS_A_READINESS_FINAL_GAP_ASSESSMENT.md"
STATUS = ROOT / "docs/scientific/registries/F-DOC15_STATUS.json"

r = json.loads(REG.read_text())
s = json.loads(STATUS.read_text())

expected = ["1.1","1.2","2.1","2.2","2.3","3.1","3.2","3.3","3.4","4.1","4.2","4.3","4.4","4.5","5.1","5.2","6.1","6.2","6.3","6.4","7.1","7.2"]
allowed = {
    "SATISFIED",
    "EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE",
    "DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE",
    "PARTIAL",
    "MISSING",
    "NOT_APPLICABLE_WITH_RATIONALE",
}

assert r["schema"] == "swap5.fdoc15_status_a_readiness_gap_assessment.v2"
assert s["schema"] == "swap5.fdoc15_status.v2"
assert r["revision"] == s["revision"] == "R1"
assert r["criterion_authority"]["denominator_count"] == 22
assert r["criterion_authority"]["percentage_reporting"] is False
assert [x["id"] for x in r["requirements"]] == expected
assert [x["requirement"] for x in s["requirement_classifications"]] == expected
assert all(x["rb1"] in allowed and x["current"] in allowed for x in r["requirements"])
assert all(x["rb1"] in allowed and x["current"] in allowed for x in s["requirement_classifications"])

assert s["prior_qualified_authority"]["sha"] == "1c4d97de16cf6d1eaf6289e920a32c4167536060"
assert s["qualified_downstream_closure_inputs"]["F-DOC16"]["sha"] == "b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b"
assert s["qualified_downstream_closure_inputs"]["F-DOC18"]["sha"] == "bddb43d821fd757a307aad88528464dd0c89a484"
assert s["parallel_candidate_not_authority"]["sha"] == "81af9e509445b8e31caba00ef7c1d158da17dc45"

assert s["scientific_foundation"]["state"] == "CLOSED_BY_QUALIFIED_F-DOC16"
assert s["hard_findings"]["sci_found_01_open"] is False
assert s["hard_findings"]["physical_science_t0_t7_open"] is False
assert s["hard_findings"]["hybrid_t0_t7_open"] is True
assert r["remaining_t0_t7"]["family"] == "HYBRID"
assert r["remaining_t0_t7"]["capabilities"] == ["RB1-CORE-MASS", "RB1-ROOT-PARALLEL"]
assert s["t0_t7_reconciliation"]["total_capabilities"] == 15
assert s["t0_t7_reconciliation"]["families_closed_capability_count"] == 13
assert s["t0_t7_reconciliation"]["remaining_capability_count"] == 2

assert s["rb1"]["release_authority_sha"] == "b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0"
assert s["rb1"]["release_authority_path"] == "release/f-rb02/F-RB02_CLOSEOUT.json"
assert s["current_canonical_snapshot"]["sha"] == "eba90d79010b095b6556e93bd8b77a8c28d25560"
assert s["current_canonical_snapshot"]["tree"] == "ed3187c068697f17886cc85ddb9291dfbbd161d4"
assert s["current_canonical_snapshot"]["ahead_of_rb1_scientific_source"] == 112

for side in ("rb1", "current"):
    counts = s["classification_counts"][side]
    assert sum(counts.values()) == 22
    assert counts["SATISFIED"] == 2
    assert counts["PARTIAL"] == 13
    assert counts["DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE"] == 3
    assert counts["MISSING"] == 4

assert r["formal_status_a_certification_claimed"] is False
assert r["ready_for_formal_status_a_assessment"] is False
assert s["ready_for_formal_status_a_assessment"] is False
assert s["status_a_certified"] is False
assert s["hard_findings"]["verification_is_validation"] is False
assert s["hard_findings"]["mass_conservation_relaxed"] is False
assert s["architecture_invariants"]["total"] == 30
assert s["architecture_invariants"]["reviewed"] == 30
assert s["architecture_invariants"]["adverse_delta"] == 0
assert s["architecture_invariants"]["mass_conservation"] == "HARD_UNCHANGED"

open_ids = {x["id"] for x in r["closure_backlog"]}
for required in {
    "WR-QA-2024-CONTROLLED-RECONCILIATION",
    "RB1-HYBRID-T0-T7",
    "PARAMETER-PROVENANCE-CALIBRATION",
    "APPLICATION-VALIDATION-T12",
    "CURRENT-CANONICAL-FREEZE-REBASELINE",
    "SENSITIVITY-UNCERTAINTY",
    "FITNESS-AND-USE",
    "COMPLETE-T8-T11-TRACEABILITY",
    "METADATA-MANAGEMENT-EXTERNAL-USE",
    "STATUS-A-READY-USER-GUIDANCE",
}:
    assert required in open_ids
assert "SCI-FOUND-01" not in open_ids
assert "PHYSICAL-SCIENCE-T0-T7" not in open_ids

main = MAIN.read_text()
for token in [
    "QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_RECONCILED_R1",
    "RB1-CORE-MASS",
    "RB1-ROOT-PARALLEL",
    "release/f-rb02/F-RB02_CLOSEOUT.json",
    "eba90d79010b095b6556e93bd8b77a8c28d25560",
    "Verification was not relabelled as validation",
    "No Status-A or Status-AA certification is claimed",
]:
    assert token in main

print("FDOC15_R1_DENOMINATOR_22_EXACT=PASS")
print("FDOC15_R1_LINEAGE_RECONCILED=PASS")
print("FDOC15_R1_SCI_FOUND_01_CLOSED=PASS")
print("FDOC15_R1_PHYSICAL_SCIENCE_T0_T7_CLOSED=PASS")
print("FDOC15_R1_HYBRID_T0_T7_REMAINS_EXACTLY_2=PASS")
print("FDOC15_R1_RB1_RELEASE_PATH_CORRECT=PASS")
print("FDOC15_R1_CURRENT_SNAPSHOT_PINNED=PASS")
print("FDOC15_R1_VERIFICATION_NOT_VALIDATION=PASS")
print("FDOC15_R1_NO_STATUS_A_CERTIFICATION=PASS")
print("FDOC15_R1_ARCHITECTURE_30_NO_ADVERSE_DELTA=PASS")
print("FDOC15_R1_DECISION_IF_EXACT_HEAD_GREEN=QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_RECONCILED_R1")
