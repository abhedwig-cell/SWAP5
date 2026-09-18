#!/usr/bin/env python3
"""PUB-GC E7 realistic component-domain qualification.

This is a publication-evidence gate only. It verifies that the already-frozen
Hupsel application requires active processes that the current production
groundwater application owner intentionally rejects. It does not modify or
exercise production physics.
"""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

sel = load("docs/publication/PUB_GC_E7_STANDALONE_SELECTION_RESULT.json")
req = load("docs/publication/PUB_GC_E7_APPLICATION_REQUIREMENTS.json")
m1 = load("integration/m1/M1_C3_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER_QUALIFICATION.json")
m1final = load("integration/m1/M1_FINAL_CLOSEOUT_20260918.json")
fapp04 = load("integration/f-app/F-APP04_TYPED_APPLICATION_COMPOSITION_QUALIFICATION.json")
src = (ROOT / "src/runtime/mod_fmr_production_application_bootstrap.f90").read_text(encoding="utf-8")

assert sel["status"] == "FROZEN_BEFORE_COUPLED_OUTPUT"
assert sel["coupled_output_observed"] is False
assert sel["selected_days"]["median_dynamics_control"]["date"] == "2003-06-17"
assert sel["selected_days"]["high_dynamics_day"]["date"] == "2003-05-20"

assert m1["qualification_verdict"] == "PASS_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER"
assert m1["m1_c3_scientific_gate_pass"] is True
assert m1["external_exact_asset_execution"]["typed_accepted_intervals"] == 32518
assert m1final["overall_verdict"] == "M1_CLOSED_CURRENT_CANONICAL"
assert m1final["formal_exit"] is True

auth = req["exact_application_authority"]
assert auth["distribution_sha256"] == m1["exact_authority"]["distribution_sha256"]
assert auth["hupsel_swap_swp_sha256"] == m1["exact_authority"]["hupsel_swap_swp_sha256"]
cfg = auth["extracted_configuration"]
assert cfg["SWCROP"] == 1 and cfg["SWETR"] == 0 and cfg["SWDRA"] == 1
crop = cfg["crop_2003"]
assert crop == {"start":"2003-05-10","end":"2003-09-29","crop_file":"potato","crop_type":2}

for day in req["selected_days"]:
    assert crop["start"] <= day["date"] <= crop["end"]
    assert day["inside_2003_crop_period"] is True
    assert day["standalone_drainage_out_cm"] > 0.0
    assert day["standalone_actual_et_cm"] > 0.0

assert m1["inherited_exact_application_trace"]["drainage_nonzero_intervals"] == 16507
assert "crop_root_uptake_input_t%potential_transpiration" in fapp04["typed_mappings"]["root"]

# Current production application owner must remain explicitly fail closed.
assert "tile%parameters%bottom_mode /= 5 .and. tile%parameters%bottom_mode /= 7" in src
assert "tile%parameters%drainage_response_active" in src
assert "tile%parameters%root_extraction_active" in src
assert "WU01 is intentionally a no-new-physics owner" in src

owner = req["production_groundwater_owner"]
assert owner["required_bottom_mode"] == 5
assert owner["wider_process_composition_owner_found_in_canonical"] is False
assert owner["ppa_wu03_found_in_canonical"] is False

print("PUB_GC_E7_SELECTION_FROZEN_BEFORE_COUPLING=PASS")
print("PUB_GC_E7_M1_WHOLE_HUPSEL_AUTHORITY=PASS")
print("PUB_GC_E7_SELECTED_DAYS_INSIDE_ACTIVE_CROP_PERIOD=PASS")
print("PUB_GC_E7_SELECTED_DAYS_POSITIVE_DRAINAGE=PASS")
print("PUB_GC_E7_ROOT_UPTAKE_TYPED_APPLICATION_REQUIREMENT=PASS")
print("PUB_GC_E7_PPA_WU01_ACTIVE_PROCESS_GUARD=PASS")
print("PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_LIMIT_STATIC_GATE=PASS")
