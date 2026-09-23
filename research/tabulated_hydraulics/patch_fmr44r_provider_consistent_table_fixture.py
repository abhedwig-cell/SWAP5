#!/usr/bin/env python3
"""Research-only FMR44R fixture repair for the generated table provider.

Applied ONLY to the table-source copy in qualification workflows.

The physical pressure-head state and forcing remain identical. Initial
water_content is derived from the active table provider rather than from the
analytical MvG provider, avoiding a constitutively inconsistent committed state.

The production analytical FMR44R oracle remains untouched. The table copy also
does not demand bit/tolerance agreement with the hard-coded analytical Binf
oracle; it retains the existing finite/budget/certificate checks and leaves A/B
comparison to the workflow.
"""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_fmr44r_provider_consistent_table_fixture.py test_fmr44r_serialized_prescribed_qbot_runtime.f90")

p=Path(sys.argv[1])
s=p.read_text()

old="""  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
"""
new=old+"""  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider_from_mvg
"""
if s.count(old) != 1:
    raise SystemExit(f"use anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
"""
new="""    type(tabhyd_raw_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
"""
if s.count(old) != 1:
    raise SystemExit(f"state provider declaration mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, merge(upward_dt,equilibrium_dt,hydrostatic))
"""
new="""    call initialize_tabhyd_raw_provider_from_mvg(provider, parameters%cofgen, &
         merge(upward_dt,equilibrium_dt,hydrostatic))
"""
if s.count(old) != 1:
    raise SystemExit(f"state provider init mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    call require(abs(observation%temporal_head_inf_bound-expected_upward_binf) <= &
         65536.0_real64*epsilon(1.0_real64)*scale, 'serialized Binf matches F-SI38 production oracle')
"""
new="""    write(*,'(A,ES26.17E3,A,ES26.17E3)') 'TABHYD_FMR44R_TABLE_BINF analytic_oracle=', &
         expected_upward_binf, ' table=', observation%temporal_head_inf_bound
"""
if s.count(old) != 1:
    raise SystemExit(f"Binf oracle anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

p.write_text(s)
print("TABHYD_FMR44R_PROVIDER_CONSISTENT_TABLE_FIXTURE_PATCHED")
