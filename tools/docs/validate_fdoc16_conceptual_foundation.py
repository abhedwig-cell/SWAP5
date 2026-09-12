#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REG = ROOT / "docs/scientific/registries/fdoc16-conceptual-foundation.json"
MAIN = ROOT / "docs/scientific/F-DOC16_PHYSICAL_SYSTEM_1D_COLUMN_CONCEPTUAL_MODEL_AUTHORITY.md"
STATUS = ROOT / "docs/scientific/registries/F-DOC16_STATUS.json"

x = json.loads(REG.read_text())
s = json.loads(STATUS.read_text())
main = MAIN.read_text()
main_lower = main.lower()

# Exact authority lineage and bounded decision.
assert x["work_unit"] == "F-DOC16"
assert x["sci_foundation_id"] == "SCI-FOUND-01"
assert x["decision_if_exact_head_green"] == "QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY"
assert x["base_documentation_authority"] == {
    "work_unit": "F-DOC15",
    "sha": "1c4d97de16cf6d1eaf6289e920a32c4167536060",
    "tree": "4fc5f0d44be496f2ebfe66d74a53e78b7d875d1b",
}
assert x["live_context_snapshot"]["sha"] == "ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868"
assert x["live_context_snapshot"]["tree"] == "d3142c34b55befaae129aeb360c415ec7d56043c"

assert x["required_chain"] == [
    "physical_system", "modelling_purpose", "spatial_temporal_scales",
    "system_boundary", "abstraction_idealisation", "conceptual_model",
    "formal_mathematical_model", "numerical_realization", "implementation",
]

# Provenance is explicit and legacy material is not silently promoted to SWAP5 truth.
sources = x["source_provenance"]
assert len(sources) >= 5
assert len({r["id"] for r in sources}) == len(sources)
for doi in (
    "doi:10.18174/416321",
    "doi:10.18174/121243",
    "doi:10.1016/j.agwat.2024.108883",
):
    assert any(r.get("persistent_identifier") == doi for r in sources)
assert any(
    r["provenance_class"] == "LEGACY_MANUAL"
    and r["lineage"] == "STRUCTURALLY_REIMPLEMENTED"
    for r in sources
)

# Stable T0/T2 scientific identities.
assert x["physical_phenomena"] == [{
    "id": "SW5-PHEN-0001",
    "title": "Local soil-plant-atmosphere hydrological system",
    "tier": "T0",
    "status": "ACTIVE",
}]
concepts = x["conceptual_entities"]
assert [c["id"] for c in concepts] == [f"SW5-CONCEPT-{i:04d}" for i in range(1, 12)]
assert all(c["tier"] == "T2" and c["status"] == "ACTIVE" for c in concepts)

# Conditional 1D admissibility is explicit rather than universal.
conditions = x["one_d_admissibility_conditions"]
assert len(conditions) == 5
joined_conditions = " ".join(conditions)
for token in ("vertical", "horizontal", "representative", "2D or 3D"):
    assert token in joined_conditions

# Every major process has one admitted conceptual disposition class.
allowed = {
    "RESOLVED", "PARAMETERISED", "FORCING",
    "BOUNDARY_CONDITION", "EXTERNAL_COMPONENT", "OUT_OF_SCOPE",
}
assert set(x["allowed_process_dispositions"]) == allowed
rows = x["process_dispositions"]
assert len(rows) >= 25
assert all(r["disposition"] in allowed for r in rows)
by_process = {r["process"]: r["disposition"] for r in rows}
expected = {
    "vertical matrix soil-water flow": "RESOLVED",
    "lateral drainage/infiltration exchange": "PARAMETERISED",
    "bottom head or bottom flux": "BOUNDARY_CONDITION",
    "groundwater aquifer dynamics": "EXTERNAL_COMPONENT",
    "deep-vadose travel/storage below SWAP column": "EXTERNAL_COMPONENT",
    "horizontal unsaturated flow field": "OUT_OF_SCOPE",
}
for process, disposition in expected.items():
    assert by_process[process] == disposition

# SCI-FOUND-01 is closed only at its bounded foundation layer.
questions = x["foundation_questions"]
assert len(questions) == 7
assert sum(q["state"] == "CLOSED_AT_CONCEPTUAL_FOUNDATION" for q in questions) == 6
assert sum(q["state"] == "CLOSED_AT_FOUNDATION_EDGE_LEVEL" for q in questions) == 1

# Hard nonclaims and invariant/mass boundary remain fail-closed.
for value in x["hard_nonclaims"].values():
    assert value is False
assert x["mass_conservation"] == "HARD_UNCHANGED"
assert x["production_source_changed"] is False
assert x["reference_data_changed"] is False
assert x["rb1_scientific_source_reopened"] is False
assert x["invariant_review"]["count"] == 30
assert x["invariant_review"]["all_reviewed"] is True
assert x["invariant_review"]["adverse_delta"] is False
assert 13 in x["invariant_review"]["direct_bindings"]

# Human-readable authority must state the same scientific boundaries semantically.
for token in (
    "representative one-dimensional column",
    "why the 1d abstraction is admissible",
    "no universal fixed horizontal area",
    "not universally identical to deep groundwater recharge",
    "day, month or year is not a fundamental computational unit",
    "process-specific t1-t4",
    "broader conceptual process table above must not be read as an rb1 feature list",
    "conceptual screening rule. it does not substitute for t12 validation",
    "closed **only as the missing model-foundation authority**",
    "does not claim `ready_for_formal_status_a_assessment`",
):
    assert token in main_lower

# Persisted closeout status must remain exactly conditional on exact-head green CI.
assert s["decision"] == "QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY_WHEN_EXACT_HEAD_CI_GREEN"
assert s["science"]["sci_found_01"] == "CLOSED_AT_CONCEPTUAL_FOUNDATION_WHEN_EXACT_HEAD_CI_GREEN"
assert s["science"]["process_specific_t1_t4_replaced"] is False
assert s["science"]["application_validation_closed"] is False
assert s["science"]["conceptual_admissibility_is_validation"] is False
assert s["rb1"]["scope_broadened"] is False
assert s["rb1"]["broader_process_table_is_feature_list"] is False
assert s["ready_for_formal_status_a_assessment"] is False
assert s["status_a_certified"] is False
assert s["status_aa_certified"] is False
assert s["production_source_changed"] is False
assert s["reference_data_changed"] is False
assert s["mass_conservation"] == "HARD_UNCHANGED"
assert s["all_30_invariants_reviewed"] is True
assert s["adverse_invariant_delta"] is False

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
