#!/usr/bin/env python3
from pathlib import Path

contract=Path("src/runtime/mod_timestep_numerical_profile.f90").read_text()
for token in [
    "TIMESTEP_PROFILE_LEGACY_NUMERICS",
    "TIMESTEP_PROFILE_AUTO_REFERENCE",
    "type, public :: legacy_numerics_profile_t",
    "type, public :: auto_reference_profile_t",
    "controller_admitted = .false.",
    "timestep_profile_execution_ready",
]:
    assert token in contract, token

for p in [
    Path("src/legacy/b1_10_fci11_port/timecontrol_part01.inc"),
    Path("src/legacy/b1_10_fci11_port/timecontrol_part04.inc"),
    Path("src/legacy/b1_10_fci11_port/timecontrol_part05.inc"),
]:
    text=p.read_text()
    assert "mod_timestep_numerical_profile" not in text
    assert "TIMESTEP_PROFILE_AUTO_REFERENCE" not in text

print("F_PE_TIMEARCH10_SOURCE_SCOPE=PASS")
