#!/usr/bin/env python3
"""Research-only serialized backend binding to the generated raw-head typed provider.

The canonical source is copied into a workflow workspace before applying this
patch. No production branch is modified. Preprocessed table state is cached by
parameter_set_id because kernel configure_parameters is called for every trial.
"""
from pathlib import Path
import sys

if len(sys.argv)!=2:
    raise SystemExit("usage: patch_serialized_backend_typed_table.py mod_fmr_serialized_reference_backend.f90")

p=Path(sys.argv[1])
s=p.read_text()

old="""  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
"""
new=old+"""  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, &
       initialize_tabhyd_raw_provider_from_mvg, bind_tabhyd_raw_provider_step_duration
"""
if s.count(old)!=1: raise SystemExit(f"use anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    type(b110_default_mvg_parameters_t), pointer :: hydraulic_parameters => null()
    type(b110_default_mvg_provider_t), pointer :: constitutive => null()
    type(b110_source_sink_provider_t), pointer :: source_sink => null()
"""
new="""    type(b110_default_mvg_parameters_t), pointer :: hydraulic_parameters => null()
    type(b110_default_mvg_provider_t), pointer :: constitutive => null()
    type(tabhyd_raw_provider_t), pointer :: tab_constitutive => null()
    integer(int64) :: tab_parameter_set_id = -1_int64
    type(b110_source_sink_provider_t), pointer :: source_sink => null()
"""
if s.count(old)!=1: raise SystemExit(f"type anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""      if (associated(self%hydraulic_parameters)) deallocate(self%hydraulic_parameters)
      if (associated(self%constitutive)) deallocate(self%constitutive)
      if (associated(self%source_sink)) deallocate(self%source_sink)
"""
new="""      if (associated(self%hydraulic_parameters)) deallocate(self%hydraulic_parameters)
      if (associated(self%constitutive)) deallocate(self%constitutive)
      if (associated(self%tab_constitutive)) then
        if (self%tab_parameter_set_id /= parameters%parameter_set_id) then
          deallocate(self%tab_constitutive)
          self%tab_parameter_set_id = -1_int64
        end if
      end if
      if (associated(self%source_sink)) deallocate(self%source_sink)
"""
if s.count(old)!=1: raise SystemExit(f"deallocate anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""      call initialize_b110_default_mvg_parameters(self%hydraulic_parameters, parameters%cofgen, &
           enable_ksatexm_extension=parameters%ksatexm_extension_active)
      self%bottom_mode = parameters%bottom_mode
"""
new="""      call initialize_b110_default_mvg_parameters(self%hydraulic_parameters, parameters%cofgen, &
           enable_ksatexm_extension=parameters%ksatexm_extension_active)
      if (.not. associated(self%tab_constitutive)) then
        allocate(self%tab_constitutive)
        call initialize_tabhyd_raw_provider_from_mvg(self%tab_constitutive, parameters%cofgen, 1.0_real64)
        self%tab_parameter_set_id = parameters%parameter_set_id
      end if
      self%bottom_mode = parameters%bottom_mode
"""
if s.count(old)!=1: raise SystemExit(f"initialization anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    if (.not. self%forcing_admitted .or. .not. associated(self%soil_parameters) .or. &
        .not. associated(self%hydraulic_parameters) .or. .not. associated(self%constitutive) .or. &
        .not. associated(self%source_sink) .or. .not. associated(self%top_boundary)) return
"""
new="""    if (.not. self%forcing_admitted .or. .not. associated(self%soil_parameters) .or. &
        .not. associated(self%hydraulic_parameters) .or. .not. associated(self%constitutive) .or. &
        .not. associated(self%tab_constitutive) .or. &
        .not. associated(self%source_sink) .or. .not. associated(self%top_boundary)) return
"""
if s.count(old)!=1: raise SystemExit(f"associated guard mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
    request%parameters => self%soil_parameters
"""
new="""    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
    call bind_tabhyd_raw_provider_step_duration(self%tab_constitutive, step_duration)
    request%parameters => self%soil_parameters
"""
if s.count(old)!=1: raise SystemExit(f"bind anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

old="""    request%evaluation%constitutive => self%constitutive
"""
new="""    request%evaluation%constitutive => self%tab_constitutive
"""
if s.count(old)!=1: raise SystemExit(f"request pointer anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

p.write_text(s)
print("TABHYD_SERIALIZED_BACKEND_TYPED_TABLE_PATCH_APPLIED")
