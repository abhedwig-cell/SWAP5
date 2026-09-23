#!/usr/bin/env python3
"""Create the F-TAB02-D generated-provider variant of the admitted FMR44R oracle.

Input is the current production FMR44R test. Only provider-specific fixture
construction and the explicit generated selector are changed. Transaction,
forcing, temporal-history, mass and solver policies remain byte-for-byte from
the source oracle.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: make_ftab02d_generated_fmr44r.py INPUT OUTPUT")

src=Path(sys.argv[1])
out=Path(sys.argv[2])
s=src.read_text()

old="""  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
"""
new=old+"""  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
"""
if s.count(old) != 1:
    raise SystemExit(f"default-provider use anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
"""
new="""    parameters%tabulated_hydraulics_active = .false.
    parameters%generated_mvg_acceleration_active = .true.
    parameters%elasticity_active = .false.
"""
if s.count(old) != 1:
    raise SystemExit(f"generated-selector anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

start=s.index("  subroutine initialize_physical_state")
end=s.index("  end subroutine initialize_physical_state",start)
block=s[start:end]
old="""    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
"""
new="""    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_generated_mvg_table_state_t), target :: table_state
    type(b110_generated_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: table_status
"""
if block.count(old) != 1:
    raise SystemExit(f"physical-state provider declaration mismatch: {block.count(old)}")
block=block.replace(old,new,1)
old="""    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, merge(upward_dt,equilibrium_dt,hydrostatic))
"""
new="""    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call initialize_b110_generated_mvg_table_state(table_state,hp,table_status)
    call require(table_status == F_TAB02_STATE_OK .and. table_state%ready(), 'generated fixture table state')
    call bind_b110_generated_mvg_provider(provider,table_state, &
         merge(upward_dt,equilibrium_dt,hydrostatic),table_status)
    call require(table_status == F_TAB02_PROVIDER_OK .and. provider%ready(), 'generated fixture provider')
"""
if block.count(old) != 1:
    raise SystemExit(f"physical-state provider init mismatch: {block.count(old)}")
block=block.replace(old,new,1)
s=s[:start]+block+s[end:]

start=s.index("  subroutine determine_initial_conductivity")
end=s.index("  end subroutine determine_initial_conductivity",start)
block=s[start:end]
old="""    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
"""
new="""    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_generated_mvg_table_state_t), target :: table_state
    type(b110_generated_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: table_status
"""
if block.count(old) != 1:
    raise SystemExit(f"conductivity provider declaration mismatch: {block.count(old)}")
block=block.replace(old,new,1)
old="""    call initialize_parameters(parameters, 2)
    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, equilibrium_dt)
"""
new="""    call initialize_parameters(parameters, 2)
    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call initialize_b110_generated_mvg_table_state(table_state,hp,table_status)
    call require(table_status == F_TAB02_STATE_OK .and. table_state%ready(), 'generated conductivity table state')
    call bind_b110_generated_mvg_provider(provider,table_state,equilibrium_dt,table_status)
    call require(table_status == F_TAB02_PROVIDER_OK .and. provider%ready(), 'generated conductivity provider')
"""
if block.count(old) != 1:
    raise SystemExit(f"conductivity provider init mismatch: {block.count(old)}")
block=block.replace(old,new,1)
s=s[:start]+block+s[end:]

old="""    scale = max(1.0_real64,abs(expected_upward_binf),abs(observation%temporal_head_inf_bound))
    call require(abs(observation%temporal_head_inf_bound-expected_upward_binf) <= &
         65536.0_real64*epsilon(1.0_real64)*scale, 'serialized Binf matches F-SI38 production oracle')
"""
new="""    scale = max(1.0_real64,abs(expected_upward_binf),abs(observation%temporal_head_inf_bound))
    write(*,'(A,ES26.17E3,A,ES26.17E3)') 'F_TAB02_D_GENERATED_BINF analytical_oracle=', &
         expected_upward_binf, ' generated=', observation%temporal_head_inf_bound
"""
if s.count(old) != 1:
    raise SystemExit(f"Binf oracle anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

out.write_text(s)
print("F_TAB02_D_GENERATED_FMR44R_FIXTURE=PASS")
