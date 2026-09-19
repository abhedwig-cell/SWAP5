#!/usr/bin/env python3
"""Validate PUB-GC E7 preservation against the current canonical application envelope."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(path: str) -> bytes:
    return (ROOT / path).read_bytes()

def load(path: str):
    return json.loads(read(path).decode("utf-8"))

def git_blob_sha(path: str) -> str:
    data = read(path)
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

rec = load("docs/publication/PUB_GC_E7_CURRENT_CANONICAL_RECONCILIATION_20260919.json")
manifest = load("docs/publication/PUB_GC_REPRODUCIBILITY_MANIFEST.json")
e7 = load("docs/publication/PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json")
req = load("docs/publication/PUB_GC_E7_APPLICATION_REQUIREMENTS.json")
wu02 = load("integration/audits/PPA_WU02_STATUS.json")
wu03 = load("integration/audits/PPA_WU03_STATUS.json")
wu04 = load("integration/audits/PPA_WU04_STATUS.json")
wu05 = load("integration/audits/PPA_WU05_STATUS.json")
wu05a = load("integration/audits/PPA_WU05A_STATUS.json")
low02 = load("integration/audits/PPA_LOW02_TIME_STATUS.json")
root_hyd01 = load("integration/audits/PPA_ROOT_HYD01_R1_RESULT.json")
root_hyd02 = load("integration/audits/PPA_ROOT_HYD02_RESULT.json")
wu05c = load("integration/audits/PPA_WU05C_STATUS.json")
wu04a = load("integration/audits/PPA_WU04A_STATUS.json")
wu04b = load("integration/audits/PPA_WU04B_STATUS.json")
src_path = "src/runtime/mod_fmr_production_application_bootstrap.f90"
backend_path = "src/runtime/mod_fmr_serialized_reference_backend.f90"
temporal_path = "src/solver/mod_reference_richards_temporal_indicator.f90"
src = read(src_path).decode("utf-8")

assert e7["status"] == "CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT"
assert e7["outcome"] == "REALISTIC_COMPONENT_DOMAIN_LIMIT"
assert git_blob_sha("docs/publication/PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json") == rec["e7"]["result_blob"]
assert git_blob_sha("docs/publication/PUB_GC_E7_APPLICATION_REQUIREMENTS.json") == rec["e7"]["application_requirements_blob"]
assert req["status"] == "FROZEN_APPLICATION_REQUIREMENTS_WITH_CURRENT_CANONICAL_AUTHORITY_RECONCILED"
assert req["frozen_selection"]["coupled_output_observed_before_freeze"] is False
assert req["current_canonical_authority"]["PPA_WU03"]["state"] == "CANONICAL_ADMITTED_CLOSED"
assert req["current_canonical_authority"]["PPA_WU03"]["broadens_mode5_process_composition"] is False
assert req["current_canonical_authority"]["production_groundwater_owner"]["wider_process_complete_groundwater_owner_found_in_canonical"] is False

assert git_blob_sha(src_path) == rec["current_production_boundary"]["bootstrap_blob"]
assert "groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5" in src
assert "prescribed_qbot_profile = prescribed_qbot_profile .and. config%tiles(i)%parameters%bottom_mode == 2" in src
assert "standalone_profile = standalone_profile .and. config%tiles(i)%parameters%bottom_mode == 7" in src
assert "tile%parameters%drainage_response_active .or. tile%parameters%root_extraction_active" in src
assert git_blob_sha(backend_path) == rec["current_production_boundary"]["serialized_backend_blob"]
assert git_blob_sha(temporal_path) == rec["current_production_boundary"]["temporal_indicator_blob"]

assert git_blob_sha("integration/audits/PPA_WU02_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU02"]["status_blob"]
assert wu02["status"] == "CANONICAL_ADMITTED_CLOSED"
assert "bottom_mode=2" in wu02["admission"]["scope"]
assert "PPA-WU01/F-GC mode5 groundwater" in wu02["first_slice"]["preserved_application_authority"]
assert "mixed bottom-mode production profiles" in wu02["admission"]["nonclaims"]

assert git_blob_sha("integration/audits/PPA_WU03_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU03"]["status_blob"]
assert wu03["state"] == "CANONICAL_ADMITTED_CLOSED"
assert "mixed PPA-WU01 bottom_mode=5/7 ownership" in wu03["explicit_nonclaims"]
assert "new physics or tolerance changes" in wu03["explicit_nonclaims"]

assert git_blob_sha("integration/audits/PPA_WU04_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU04"]["status_blob"]
assert wu04["scope"]["production_source_mutation"] is False
assert wu04["production_admission"] == "NONE_REVIEW_ONLY"

assert git_blob_sha("integration/audits/PPA_WU05_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU05"]["status_blob"]
assert wu05["production_source_mutation"] is False
assert wu05["first_target"]["production_admission"] == "NONE"

assert git_blob_sha("integration/audits/PPA_WU05A_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU05A"]["status_blob"]
assert wu05a["production_source_mutation"] is False
assert wu05a["production_admission"] == "NONE_REVIEW_ONLY"

assert git_blob_sha("integration/audits/PPA_LOW02_TIME_STATUS.json") == rec["later_canonical_workunits"]["PPA_LOW02_TIME"]["status_blob"]
assert low02["status"] == "CANONICAL_ADMITTED_CLOSED"
assert "bottom_mode=2" in low02["production_scope"]["route"]
assert "new groundwater-coupling semantics" in low02["explicit_nonclaims"]
assert backend_path in low02["production_scope"]["production_source"]

assert git_blob_sha("integration/audits/PPA_ROOT_HYD01_R1_RESULT.json") == rec["later_canonical_workunits"]["PPA_ROOT_HYD01"]["result_blob"]
assert root_hyd01["decision"] == "QUALIFIED_RESTRICTED_PRESCRIBED_ROOT_SINK_TEMPORAL_CERTIFICATE"
assert root_hyd01["production_delta"] == [temporal_path]
assert root_hyd01["source_semantics"]["headcalc_changed"] is False
assert root_hyd01["source_semantics"]["richards_solver_changed"] is False
assert root_hyd01["source_semantics"]["transaction_core_changed"] is False
assert root_hyd01["source_semantics"]["tolerance_changed"] is False
assert root_hyd01["implication_for_hydro_memory"]["stage0_authorized"] is False

assert git_blob_sha("integration/audits/PPA_WU05C_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU05C"]["status_blob"]
assert wu05c["scope"]["production_source_mutation"] is False
assert wu05c["production_admission"] == "NONE_REVIEW_ONLY"

assert git_blob_sha("integration/audits/PPA_ROOT_HYD02_RESULT.json") == rec["later_canonical_workunits"]["PPA_ROOT_HYD02"]["result_blob"]
assert root_hyd02["decision"] == "QUALIFIED_RESTRICTED_PRESCRIBED_ROOT_TANGENT_COVERAGE"
assert "no real live-MODFLOW root-active application admission by this workunit alone" in root_hyd02["nonclaims"]
assert rec["later_canonical_workunits"]["PPA_ROOT_HYD02"]["application_owner_broadened"] is False
assert rec["later_canonical_workunits"]["PPA_ROOT_HYD02"]["groundwater_owner_broadened"] is False

assert git_blob_sha("integration/audits/PPA_WU04A_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU04A"]["status_blob"]
assert wu04a["work_unit"] == "PPA-WU04-A"
assert "groundwater mode 5 Black composition" in wu04a["admitted_claim_boundary"]["nonclaims"]
assert rec["later_canonical_workunits"]["PPA_WU04A"]["mode5_black_composition_admitted"] is False

assert git_blob_sha("integration/audits/PPA_WU04B_STATUS.json") == rec["later_canonical_workunits"]["PPA_WU04B"]["status_blob"]
assert wu04b["work_unit"] == "PPA-WU04-B"
assert wu04b["qualification"]["conclusion"] == "PASS"
assert wu04b["qualification"]["gates"]["ppa_wu01_behavioral_preservation"] == "PASS"
assert wu04b["qualification"]["gates"]["ppa_wu03_behavioral_preservation"] == "PASS"
assert rec["later_canonical_workunits"]["PPA_WU04B"]["mode5_boesten_composition_admitted"] is False
assert rec["later_canonical_workunits"]["PPA_WU04B"]["root_or_drainage_owner_broadened"] is False
assert "tile%parameters%boesten_evaporation_active" in src
assert "if (tile%parameters%bottom_mode == 5) return" in src

assert e7["canonical_reconciliation"]["production_bootstrap_blob"] == rec["current_production_boundary"]["bootstrap_blob"]
assert e7["canonical_reconciliation"]["ppa_root_hyd02_result_blob"] == rec["later_canonical_workunits"]["PPA_ROOT_HYD02"]["result_blob"]
assert e7["canonical_reconciliation"]["ppa_wu04a_status_blob"] == rec["later_canonical_workunits"]["PPA_WU04A"]["status_blob"]
assert e7["canonical_reconciliation"]["ppa_wu04b_status_blob"] == rec["later_canonical_workunits"]["PPA_WU04B"]["status_blob"]
assert rec["verdict"] == "E7_CURRENT_CANONICAL_PRESERVED"

# Reproducibility manifest must bind the current, journal-facing closeout assets.
required_assets = (
    "manuscript",
    "claim_ledger",
    "tables",
    "figure_manifest",
    "submission_readiness",
    "supplement",
    "e7_result",
    "e7_application_requirements",
    "e7_selection_result",
    "e7_selected_days",
    "e7_current_canonical_reconciliation",
)
for key in required_assets:
    asset = manifest["publication_assets"][key]
    assert git_blob_sha(asset["path"]) == asset["blob"], f"manifest blob mismatch: {key}"
assert manifest["canonical_basis"] == rec["canonical_head_at_reconcile"]
assert manifest["E7"]["current_canonical_reconciliation"]["verdict"] == "E7_CURRENT_CANONICAL_PRESERVED"
assert manifest["E7"]["current_canonical_reconciliation"]["production_bootstrap_blob"] == rec["current_production_boundary"]["bootstrap_blob"]

# Current-state/journal-facing anti-drift scan. Historical preregistration is excluded.
anti_drift_paths = (
    "docs/publication/PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md",
    "docs/publication/PUB_GC_COUPLE_CLAIM_EVIDENCE_LEDGER.md",
    "docs/publication/PUB_GC_SUBMISSION_READINESS.md",
    "docs/publication/PUB_GC_MANUSCRIPT_TABLES.md",
    "docs/publication/PUB_GC_MANUSCRIPT_FIGURE_TABLE_PLAN.md",
    "docs/publication/PUB_GC_MANUSCRIPT_CONSOLIDATION_STATUS.md",
    "docs/publication/PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md",
    "docs/publication/PUB_GC_MANUSCRIPT_CLAIM_SENTENCE_AUDIT.md",
    "docs/publication/PUB_GC_SUBMISSION_PROSE_AUDIT.md",
    "docs/publication/PUBLICATION_PROGRAMME.md",
)
forbidden = (
    "E7 coupled execution pending",
    "E7 blocked",
    "F7 pending",
    "T6 blocked",
    "RQ5 unanswered",
    "coupled Hupsel execution is next required action",
)
for path in anti_drift_paths:
    body = read(path).decode("utf-8").lower()
    for phrase in forbidden:
        assert phrase.lower() not in body, f"stale current-state phrase in {path}: {phrase}"

print("PUB_GC_E7_CURRENT_RESULT_CLOSED=PASS")
print("PUB_GC_E7_CURRENT_BOOTSTRAP_BLOB=PASS")
print("PUB_GC_E7_CURRENT_MODE5_GROUNDWATER_PROFILE=PASS")
print("PUB_GC_E7_CURRENT_ACTIVE_DRAINAGE_ROOT_GUARD=PASS")
print("PUB_GC_E7_PPA_WU02_NO_GW_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU03_NO_GW_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU04_REVIEW_ONLY=PASS")
print("PUB_GC_E7_PPA_WU05_REVIEW_ONLY=PASS")
print("PUB_GC_E7_PPA_WU05A_REVIEW_ONLY=PASS")
print("PUB_GC_E7_PPA_LOW02_TIME_NO_GW_WIDENING=PASS")
print("PUB_GC_E7_ROOT_HYD01_TEMPORAL_ONLY_NO_OWNER_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU05C_REVIEW_ONLY=PASS")
print("PUB_GC_E7_ROOT_HYD02_TANGENT_ONLY_NO_OWNER_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU04A_NO_MODE5_PROCESS_WIDENING=PASS")
print("PUB_GC_E7_PPA_WU04B_NO_MODE5_PROCESS_WIDENING=PASS")
print("PUB_GC_E7_APPLICATION_REQUIREMENTS_CURRENT_PROVENANCE=PASS")
print("PUB_GC_E7_REPRODUCIBILITY_MANIFEST_BOUND=PASS")
print("PUB_GC_E7_CURRENT_STATE_ANTI_DRIFT=PASS")
print("PUB_GC_E7_CURRENT_CANONICAL_PRESERVED=PASS")
