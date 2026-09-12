#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REG = ROOT / "docs/scientific/registries/fdoc16-conceptual-foundation.json"
MAIN = ROOT / "docs/scientific/F-DOC16_PHYSICAL_SYSTEM_1D_COLUMN_CONCEPTUAL_MODEL_AUTHORITY.md"
STATUS = ROOT / "docs/scientific/registries/F-DOC16_STATUS.json"

x = json.loads(REG.read_text())

assert x["work_unit"] == "F-DOC16"
assert x["sci_foundation_id"] == "SCI-FOUND-01"
assert x["decision_if_exact_head_green"] == "QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY"
assert x["base_documentation_authority"]["work_unit"] == "F-DOC15"
assert x["base_documentation_authority"]["sha"] == "1c4d97de16cf6d1eaf6289e920a32c4167536060"
assert x["base_documentation_authority"]["tree"] == "4fc5f0d44be496f2ebfe66d74a53e78b7d875d1b"
assert x["live_context_snapshot"]["sha"] == "ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868"
assert x["live_context_snapshot"]["tree"] == "d3142c34b55befaae129aeb360c415ec7d56043c"

assert x["required_chain"] == [
    "physical_system",
    "modelling_purpose",
    "spatial_temporal_scales",
    "system_boundary",
    "abstraction_idealisation",
    "conceptual_model",
    "formal_mathematical_model",
    "numerical_realization",
    "implementation",
]

sources = x["source_provenance"]
assert len(sources) >= 5
source_ids = [s["id"] for s in sources]
assert len(source_ids) == len(set(source_ids))
assert any(s.get("persistent_identifier") == "doi:10.18174/416321" for s in sources)
assert any(s.get("persistent_identifier") == "doi:10.18174/121243" for s in sources)
assert any(s.get("persistent_identifier") == "doi:10.1016/j.agwat.2024.108883" for s in sources)
assert any(s["provenance_class"] == "LEGACY_MANUAL" and s["lineage"] == "STRUCTURALLY_REIMPLEMENTED" for s in sources)

phen = x["physical_phenomena"]
assert phen == [{
    "id": "SW5-PHEN-0001",
    "title": "Local soil-plant-atmosphere hydrological system",
    "tier": "T0",
    "status": "ACTIVE",
}]

concepts = x["conceptual_entities"]
assert len(concepts) == 11
concept_ids = [c["id"] for c in concepts]
assert concept_ids == [f"SW5-CONCEPT-{i:04d}" for i in range(1, 12)]
assert len(concept_ids) == len(set(concept_ids))
assert all(c["tier"] == "T2" and c["status"] == "ACTIVE" for c in concepts)

conditions = x["one_d_admissibility_conditions"]
assert len(conditions) == 5
assert any("vertical" in c for c in conditions)
assert any("2D or 3D" in c for c in conditions)
assert any("representative" in c for c in conditions)

allowed = set(x["allowed_process_dispositions"])
assert allowed == {
    "RESOLVED",
    "PARAMETERISED",
    "FORCING",
    "BOUNDARY_CONDITION",
    "EXTERNAL_COMPONENT",
    "OUT_OF_SCOPE",
}
rows = x["process_dispositions"]
assert len(rows) >= 25
assert all(r["disposition"] in allowed for r in rows)
by_process = {r["process"]: r["disposition"] for r in rows}
assert by_process["vertical matrix soil-water flow"] == "RESOLVED"
assert by_process["lateral drainage/infiltration exchange"] == "PARAMETERISED"
assert by_process["bottom head or bottom flux"] == "BOUNDARY_CONDITION"
assert by_process["groundwater aquifer dynamics"] == "EXTERNAL_COMPONENT"
assert by_process["deep-vadose travel/storage below SWAP column"] == "EXTERNAL_COMPONENT"
assert by_process["horizontal unsaturated flow field"] == "OUT_OF_SCOPE"

questions = x["foundation_questions"]
assert len(questions) == 7
assert sum(q["state"] == "CLOSED_AT_CONCEPTUAL_FOUNDATION" for q in questions) == 6
assert sum(q["state"] == "CLOSED_AT_FOUNDATION_EDGE_LEVEL" for q in questions) == 1

nonclaims = x["hard_nonclaims"]
for key in [
    "broad_process_table_is_rb1_feature_list",
    "bottom_flux_is_universally_groundwater_recharge",
    "multiple_columns_are_a_horizontally_coupled_soil_model",
    "conceptual_admissibility_is_validation",
    "process_equations_adopted_by_this_workunit",
    "ready_for_formal_status_a_assessment",
    "status_a_certified",
    "status_aa_certified",
]:
    assert nonclaims[key] is False

assert x["mass_conservation"] == "HARD_UNCHANGED"
assert x["production_source_changed"] is False
assert x["reference_data_changed"] is False
assert x["rb1_scientific_source_reopened"] is False
assert x["invariant_review"]["count"] == 30
assert x["invariant_review"]["all_reviewed"] is True
assert x["invariant_review"]["adverse_delta"] is False
assert 13 in x["invariant_review"]["direct_bindings"]

main = MAIN.read_text()
for token in [
    "QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY",
    "Representative one-dimensional column",
    "Why the 1D abstraction is admissible",
    "The column has **no universal fixed horizontal area**",
    "The lower boundary is **not universally identical to deep groundwater recharge**",
    "A day, month or year is not a fundamental computational unit",
    "process-specific T1-T4",
    "broader conceptual process table above must not be read as an RB1 feature list",
    "conceptual screening rule. It does not substitute for T12 validation",
    "SCI-FOUND-01 is closed **only as the missing model-foundation authority**",
    "does not claim `READY_FOR_FORMAL_STATUS_A_ASSESSMENT`",
]:
    assert token in main

if STATUS.exists():
    s = json.loads(STATUS.read_text())
    assert s["decision"] == "QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY_WHEN_EXACT_HEAD_CI_GREEN"
    assert s["science"]["sci_found_01"] == "CLOSED_AT_CONCEPTUAL_FOUNDATION_WHEN_EXACT_HEAD_CI_GREEN"
    assert s["science"]["process_specific_t1_t4_replaced"] is False
    assert s["science"]["application_validation_closed"] is False
    assert s["rb1"]["scope_broadened"] is False
    assert s["ready_for_formal_status_a_assessment"] is False
    assert s["status_a_certified"] is False
    assert s["production_source_changed"] is False

print("FDOC16_BASE_FDOC15_EXACT=PASS")
print("FDOC16_SCI_FOUND_01_FOUNDATION_CLOSED=PASS")
print("FDOC16_1D_ADMISSIBILITY_CONDITIONAL=PASS")
print("FDOC16_PROCESS_DISPOSITIONS_EXPLICIT=PASS")
print("FDOC16_BOTTOM_FLUX_NOT_UNIVERSAL_RECHARGE=PASS")
print("FDOC16_MULTISWAP_NOT_HORIZONTAL_SOIL_MODEL=PASS")
print("FDOC16_RB1_SCOPE_NOT_BROADENED=PASS")
print("FDOC16_PROCESS_FORMAL_AUTHORITIES_NOT_REPLACED=PASS")
print("FDOC16_VALIDATION_REMAINS_SEPARATE=PASS")
print("FDOC16_MASS_CONSERVATION_HARD=PASS")
print("FDOC16_ALL_30_INVARIANTS_REVIEWED=PASS")
print("FDOC16_NO_STATUS_A_CERTIFICATION=PASS")
print("FDOC16_DECISION_IF_EXACT_HEAD_GREEN=QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY")
