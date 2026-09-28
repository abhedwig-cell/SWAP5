#!/usr/bin/env python3
from pathlib import Path

contract=Path("src/runtime/mod_timestep_controller_contract.f90").read_text()
for token in [
    "type, abstract, public :: timestep_controller_t",
    "type, public :: timestep_accepted_context_t",
    "type, public :: timestep_controller_limits_t",
    "legacy_compat_timestep_controller_t",
    "auto_reference_null_controller_t",
    "apply_timestep_safety_limits",
]:
    assert token in contract, token

for p in [
    Path("src/legacy/b1_10_fci11_port/timecontrol_part01.inc"),
    Path("src/legacy/b1_10_fci11_port/timecontrol_part04.inc"),
    Path("src/legacy/b1_10_fci11_port/timecontrol_part05.inc"),
]:
    text=p.read_text()
    assert "mod_timestep_controller_contract" not in text

profile=Path("src/runtime/mod_timestep_numerical_profile.f90").read_text()
assert "controller_admitted = .false." in profile
print("F_PE_TIMEARCH11_SOURCE_ISOLATION=PASS")
