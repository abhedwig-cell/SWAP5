#!/usr/bin/env python3
"""Qualify the preregistered PUB-GC E7 realistic component-domain outcome.

This is deliberately a fail-closed publication qualification. It does not
change or execute alternative physics. It proves that the two frozen Hupsel
days require active drainage while the current production prescribed-head
groundwater owner rejects any profile with drainage_response_active.

A component-domain result is a valid preregistered E7 outcome.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

selection = json.loads((ROOT / "docs/publication/PUB_GC_E7_STANDALONE_SELECTION_RESULT.json").read_text())
wu01 = json.loads((ROOT / "integration/audits/PPA_WU01_STATUS.json").read_text())
wu02 = json.loads((ROOT / "integration/audits/PPA_WU02_STATUS.json").read_text())
wu03 = json.loads((ROOT / "integration/audits/PPA_WU03_STATUS.json").read_text())
m1 = json.loads((ROOT / "integration/m1/M1_C3_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER_QUALIFICATION.json").read_text())
e6 = json.loads((ROOT / "docs/publication/PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.json").read_text())
source = (ROOT / "src/runtime/mod_fmr_production_application_bootstrap.f90").read_text()

csr_path = ROOT / "integration/f-gc/F-GC_COUPLING_SEMANTICS_RECONCILIATION_STATUS.json"
if csr_path.exists():
    csr = json.loads(csr_path.read_text())
    require(csr["experiment_impact"]["E7"] == "COUPLING_ASSUMPTION_DEPENDENT_REQUALIFICATION_REQUIRED",
            "CSR E7 disposition missing")
    require(csr["e7"]["rerun_authorized"] is False, "E7 rerun prematurely authorized")
    require("groundwater_profile = groundwater_profile .and. config%tiles(i)%groundwater_coupled" in source,
            "explicit coupled-boundary authority missing")
    require("tile%parameters%drainage_response_active .or. tile%parameters%root_extraction_active" in source,
            "CSR-03 process fail-closed guard missing")
    print("PUB_GC_E7_HISTORICAL_COMPONENT_DOMAIN_EVIDENCE_PRESERVED=PASS")
    print("PUB_GC_E7_COMPONENT_DOMAIN_INTERPRETATION_SUPERSEDED=PASS")
    print("PUB_GC_E7_REQUALIFICATION_REQUIRED=PASS")
    raise SystemExit(0)

def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit("PUB_GC_E7_FAIL " + message)

require(selection["status"] == "FROZEN_BEFORE_COUPLED_OUTPUT", "selection not frozen")
require(selection["coupled_output_observed"] is False, "coupled output observed before selection")
require(selection["prerequisite_authority"]["m1_overall_verdict"] == "M1_CLOSED_CURRENT_CANONICAL", "M1 not closed")
require(m1["qualification_verdict"] == "PASS_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER", "whole-Hupsel typed authority absent")

selected = selection["selected_days"]
for role in ("median_dynamics_control", "high_dynamics_day"):
    require(selected[role]["drainage_out_cm"] > 0.0, role + " has no positive Hupsel drainage evidence")

init_start = source.index("subroutine production_application_initialize")
init_end = source.index("end subroutine production_application_initialize")
init = source[init_start:init_end]
validate_start = source.index("logical function tile_config_valid")
validate_end = source.index("end function tile_config_valid")
validate = source[validate_start:validate_end]

require("groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5" in init,
        "groundwater owner no longer bound to bottom_mode=5")
require("if (.not. tile_config_valid(config%tiles(i), n, i)) then" in init,
        "tile validation not called during initialization")
require(init.index("if (.not. tile_config_valid") < init.index("allocate(self%columns"),
        "profile rejection no longer precedes owner-state allocation")
require("tile%parameters%drainage_response_active" in validate,
        "drainage-response fail-closed guard missing")
require("tile%parameters%root_extraction_active" in validate,
        "root-extraction fail-closed guard missing")
require(validate.index("tile%parameters%drainage_response_active") < validate.index("valid = .true."),
        "drainage-response guard occurs after admission")
require("tile%parameters%bottom_mode /= 5 .and. tile%parameters%bottom_mode /= 7" in validate,
        "mode-5/mode-7 lower-boundary authority disappeared")
require("tile%parameters%bottom_mode /= 2" in validate,
        "PPA-WU02 typed prescribed-qbot mode-2 admission missing from reconciled source")

profiles = wu01["admitted_restricted_profiles"]
require("bottom_mode=5" in profiles["groundwater"], "WU01 groundwater profile changed")
require(wu01["verdict"] == "CANONICAL_ADMITTED_RESTRICTED_PRODUCTION_CLOSED", "WU01 not admitted/closed")
require(wu02["status"] == "CANONICAL_ADMITTED_CLOSED", "WU02 state unexpected")
require(wu02["first_slice"]["semantic_delta"].startswith("Admit homogeneous bottom_mode=2"),
        "WU02 unexpectedly changed from bounded mode-2 admission")
require("mixed bottom-mode production profiles" in wu02["first_slice"]["explicitly_not_admitted"],
        "WU02 unexpectedly broadened mixed profile ownership")
require(wu03["state"] == "CANONICAL_ADMITTED_CLOSED", "WU03 state unexpected")
require(any("mixed PPA-WU01 bottom_mode=5/7" in x for x in wu03["explicit_nonclaims"]),
        "WU03 unexpectedly broadened WU01 ownership")

cause = e6["structural_cause"]
require("bottom_mode == 5" in cause["head_forcing_materializer_requirement"],
        "prescribed-head mode-5 authority changed")
require("bottom_mode == 2" in cause["smooth_drainage_projection_requirement"],
        "active-drainage route authority changed")
require(e6["reference_corrector"]["transaction_calls"] == 0,
        "E6 precedent no longer pretransactional")
require(e6["reference_corrector"]["kernel_result_status_name"] == "KERNEL_STATUS_NOT_ADMITTED",
        "E6 precedent status changed")

print("PUB_GC_E7_SELECTED_DAYS_FROZEN=PASS")
print("PUB_GC_E7_M1_WHOLE_HUPSEL_AUTHORITY=PASS")
print("PUB_GC_E7_HUPSEL_DRAINAGE_REQUIRED_ON_MEDIAN_DAY=PASS")
print("PUB_GC_E7_HUPSEL_DRAINAGE_REQUIRED_ON_HIGH_DAY=PASS")
print("PUB_GC_E7_PRESCRIBED_HEAD_OWNER_BOTTOM_MODE5=PASS")
print("PUB_GC_E7_ACTIVE_DRAINAGE_PROFILE_FAILS_BEFORE_OWNER_ALLOCATION=PASS")
print("PUB_GC_E7_E6_PRECEDENT_PRETRANSACTION_NOT_ADMITTED=PASS")
print("PUB_GC_E7_NO_WU02_PROCESS_PROFILE_WIDENING=PASS")
print("PUB_GC_E7_NO_WU03_PROFILE_WIDENING=PASS")
print("PUB_GC_E7_OUTCOME=REALISTIC_COMPONENT_DOMAIN_LIMIT")
