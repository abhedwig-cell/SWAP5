#!/usr/bin/env python3
from pathlib import Path

worker=Path("src/runtime/mod_a23bu_worker_execution_context.f90").read_text()
p4=Path("src/legacy/b1_10_fci11_port/timecontrol_part04.inc").read_text()
p5=Path("src/legacy/b1_10_fci11_port/timecontrol_part05.inc").read_text()

for token in [
    "type, public :: a23bu_timestep_shadow_memory_t",
    "retain_preferred_dt",
    "evidence_preferred_dt",
    "previous_event_clamped",
    "type(a23bu_timestep_shadow_memory_t) :: timestep_shadow",
]:
    assert token in worker, token

for token in [
    "timestepPreviousEventClamped",
    "worker%timestep_shadow%retain_preferred_dt",
    "worker%timestep_shadow%evidence_preferred_dt",
    "timestepShadowDecision = b1_10_legacy_accepted_step_decision",
    "worker%timestep_shadow%previous_event_clamped = timestepEventClamped",
]:
    assert token in p4, token

# Shadow state is diagnostic/counterfactual only. It must never assign execution dt.
for source in (p4,p5):
    assert "dt = worker%timestep_shadow" not in source
    assert "dt=worker%timestep_shadow" not in source.replace(" ","")
    assert "min(worker%timestep_shadow" not in source
    assert "max(worker%timestep_shadow" not in source

# Solver retry must not rewrite accepted-step shadow memory.
assert "%timestep_shadow%" not in p5

print("F_PE_TIMEARCH08_SOURCE_SCOPE=PASS")
