#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RG = ROOT / "integration" / "f-rg"
POLICY = ROOT / "docs" / "governance" / "F-RG04_SCIENTIFIC_EVIDENCE_ASSURANCE_GOVERNANCE.md"

FILES = {
    "evidence": RG / "F-RG04_EVIDENCE_CLASSIFICATION.json",
    "object": RG / "F-RG04_BOUNDED_QUALIFICATION_OBJECT_SCHEMA.json",
    "assurance": RG / "F-RG04_ASSURANCE_LEVELS.json",
    "composition": RG / "F-RG04_COMPOSITION_AUTHORITY_PROMOTION_RULES.json",
    "provenance": RG / "F-RG04_PROVENANCE_REPLAY_RULES.json",
    "animo": RG / "F-RG04_ANIMO_LESSON_MAPPING.json",
    "swap": RG / "F-RG04_SWAP_AUTHORITY_RECONCILIATION.json",
}


def load(path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def require(cond, msg):
    if not cond:
        raise SystemExit(f"FRG04_FAIL: {msg}")


for name, path in FILES.items():
    require(path.is_file(), f"missing {name}: {path}")
require(POLICY.is_file(), "missing readable governance policy")

E = load(FILES["evidence"])
O = load(FILES["object"])
A = load(FILES["assurance"])
C = load(FILES["composition"])
P = load(FILES["provenance"])
L = load(FILES["animo"])
S = load(FILES["swap"])
text = POLICY.read_text(encoding="utf-8")

expected_evidence = {
    "FROZEN_SOURCE_EVIDENCE", "HISTORICAL_REFERENCE_BEHAVIOR_EVIDENCE",
    "RECONSTRUCTED_EVIDENCE", "SYNTHETIC_ORACLE_EVIDENCE", "NUMERICAL_EVIDENCE",
    "SCIENTIFIC_PHYSICAL_EVIDENCE", "TRANSACTION_CONSERVATION_EVIDENCE",
    "RUNTIME_INTEGRATION_EVIDENCE", "TESTBANK_PRESERVATION_EVIDENCE",
    "DOCUMENTATION_PROVENANCE_EVIDENCE", "RESEARCH_EVIDENCE", "PRODUCTION_ADMISSION_EVIDENCE"
}
ids = {x["id"] for x in E["classes"]}
require(ids == expected_evidence, f"evidence classes mismatch: {ids ^ expected_evidence}")
for item in E["classes"]:
    for field in ["can_demonstrate", "cannot_demonstrate", "consumers", "historical_fidelity_claim_supported", "production_admission_support", "production_admission_sufficient_alone"]:
        require(field in item, f"evidence class {item['id']} missing {field}")
require(E["principle"] == "EVIDENCE_IS_NOT_AUTHORITY", "evidence principle changed")

required_object_fields = set(O["required"])
for field in ["object_id", "object_kind", "claim", "non_claims", "scope", "source_identity", "evidence", "uncertainty_labels", "assurance_required", "qualification_outcome", "parent_child", "composition_required", "admission_required"]:
    require(field in required_object_fields, f"bounded object missing required field {field}")
object_kinds = set(O["properties"]["object_kind"]["enum"])
for kind in ["EQUATION_OR_PROCESS_LAW", "PROCESS_CONTRACT", "SOLVER_BEHAVIOR", "BOUNDARY_CONDITION", "STATE_VARIABLE", "TRANSACTION_PROPERTY", "CONSERVATION_PROPERTY", "COUPLING_PROPERTY", "MODULE_CAPABILITY", "SUB_CAPABILITY", "COMPOSED_CAPABILITY", "COMPLETE_V1_DOMAIN"]:
    require(kind in object_kinds, f"bounded object kind missing {kind}")
outcomes = set(O["properties"]["qualification_outcome"]["enum"])
for outcome in ["QUALIFIED_POSITIVE", "QUALIFIED_NEGATIVE", "BLOCKED_BY_EVIDENCE", "NOT_SCIENTIFICALLY_DEFENSIBLE", "HISTORICAL_BEHAVIOR_UNKNOWN", "OUTSIDE_CURRENT_SCOPE"]:
    require(outcome in outcomes, f"negative/positive outcome missing {outcome}")

levels = {x["id"]: x for x in A["levels"]}
for level in ["OWNER_VERIFIED", "PROCESS_SELF_REVIEWED_NOT_INDEPENDENT", "ADVERSARIALLY_SELF_REVIEWED_NOT_INDEPENDENT", "INDEPENDENTLY_QUALIFIED"]:
    require(level in levels, f"assurance missing {level}")
require(levels["PROCESS_SELF_REVIEWED_NOT_INDEPENDENT"]["independent"] is False, "self review mislabeled independent")
require(levels["ADVERSARIALLY_SELF_REVIEWED_NOT_INDEPENDENT"]["independent"] is False, "adversarial self review mislabeled independent")
require(levels["INDEPENDENTLY_QUALIFIED"]["independent"] is True, "independent qualification not marked independent")
require(A["existing_hard_gates_may_be_downgraded"] is False, "risk tier weakens hard gates")
require(A["same_agent_may_be_called_independent"] is False, "same-agent independence leak")
require({x["id"] for x in A["risk_tiers"]} == {"R0_GOVERNANCE_DOCUMENTATION", "R1_BOUNDED_NONPRODUCTION", "R2_PRODUCTION_LOCAL", "R3_STATE_CONSERVATION_TRANSACTION", "R4_COMPOSITION_COUPLING_PRODUCTION"}, "risk tiers changed")

for promotion in [
    "EVIDENCE_TO_AUTHORITY", "QUALIFICATION_TO_ADMISSION", "CHILD_QUALIFIED_TO_PARENT_QUALIFIED",
    "ALL_CHILDREN_QUALIFIED_TO_PARENT_OR_COMPOSITION_QUALIFIED", "AGGREGATE_AUTHORITY_TO_COMPOSITION_COMPLETENESS",
    "COMPOSITION_COMPLETENESS_TO_PRODUCTION_AUTHORITY", "RESEARCH_AUTHORITY_TO_PRODUCTION_AUTHORITY"
]:
    require(promotion in C["forbidden_implicit_promotions"], f"missing forbidden promotion {promotion}")
require(C["composition_gate"]["all_children_pass_is_sufficient"] is False, "children passes incorrectly imply composition")
require(C["admission_serialization"]["F_CI_admissions_serialized"] is True, "F-CI admission not serialized")
require(C["admission_serialization"]["stale_qualification_auto_admission_forbidden"] is True, "stale qualification could auto-admit")
require(C["negative_qualification_rule"]["completion_percentage_effect_automatic"] is False, "negative qualification changes score")

prov_ids = {x["id"] for x in P["classes"]}
require(prov_ids == {"SOURCE_PROVENANCE", "BEHAVIORAL_REPLAY", "RECONSTRUCTED_REPLAY", "SYNTHETIC_ORACLE", "PRODUCTION_REGRESSION"}, "provenance/replay classes mismatch")
rec = next(x for x in P["classes"] if x["id"] == "RECONSTRUCTED_REPLAY")
require(rec["historical_truth_possible"] is False, "reconstruction can masquerade as historical truth")
require(P["reuse_policy"]["strength_promotion_by_reuse_forbidden"] is True, "evidence reuse promotes strength")

allowed_dispositions = {"ADOPTED", "ALREADY_PRESENT", "ADAPTED", "REJECTED_AS_ANIMO_SPECIFIC"}
require({x["disposition"] for x in L["lessons"]} <= allowed_dispositions, "invalid ANIMO lesson disposition")
require({x["disposition"] for x in L["lessons"]} == allowed_dispositions, "not all ANIMO disposition classes exercised")
require(L["gov06"]["authority_used"] is False, "nonexistent/unqualified GOV06 used")

areas = {x["area"] for x in S["examples"]}
for area in ["production_physics", "full_richards_reference", "rossfast_research", "energy_balance_research", "groundwater_coupling", "transactions_and_mass", "restart", "numerical_execution_policy", "multiswap", "testbank", "documentation_status_a", "independent_qualification", "canonical_admission"]:
    require(area in areas, f"SWAP authority mapping missing {area}")
require(S["governance_authorities"]["F_RG01C"] == "56b86e29e0960e396059caf47c193440d571b709", "F-RG01C authority changed")
require(S["governance_authorities"]["F_RG03"] == "aac2644149dda47282a25a39892c6dc808323dd0", "F-RG03 authority changed")

for phrase in [
    "Evidence is not authority", "Qualification is not admission", "Negative qualification is first-class",
    "Parent, child and composition governance", "Immutable adversarial review boundary",
    "F-RG01C completion-model protection", "F-RG01D module-contract bridge",
    "Documentation bridge", "Admission serialization"
]:
    require(phrase in text, f"policy missing section/phrase {phrase}")

for forbidden in ["B0 -> B1 -> B2 -> B3 -> B4", "TCD lifecycle is adopted by SWAP"]:
    require(forbidden not in text, f"mechanical ANIMO lifecycle leak: {forbidden}")

print("FRG04_EVIDENCE_NOT_AUTHORITY=PASS")
print("FRG04_BOUNDED_OBJECTS=PASS")
print("FRG04_NEGATIVE_QUALIFICATION_NONCREDIT=PASS")
print("FRG04_ASSURANCE_INDEPENDENCE_HONEST=PASS")
print("FRG04_COMPOSITION_FAIL_CLOSED=PASS")
print("FRG04_PROVENANCE_REPLAY=PASS")
print("FRG04_ANIMO_TRANSLATION_NO_MECHANICAL_B3_TCD=PASS")
print("FRG04_SWAP_AUTHORITY_RECONCILIATION=PASS")
print("FRG04_GOVERNANCE_PACKAGE=PASS")
