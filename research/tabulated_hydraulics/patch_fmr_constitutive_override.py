#!/usr/bin/env python3
"""Research-only provider injection seam for a copied FMR serialized backend.

This patch is for benchmark compilation only. It does not modify the repository
production backend. The existing analytical provider remains allocated/bound;
the override only changes the request-level constitutive pointer when explicitly set.
"""
from pathlib import Path
import sys
if len(sys.argv)!=2:
    raise SystemExit("usage: patch_fmr_constitutive_override.py mod_fmr_serialized_reference_backend.f90")
p=Path(sys.argv[1]); s=p.read_text()

old="""  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_solver_diagnostics_t, top_boundary_provider_t, SW_SOLVE_CONVERGED, &"""
new="""  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_solver_diagnostics_t, constitutive_hydraulics_provider_t, &
       top_boundary_provider_t, SW_SOLVE_CONVERGED, &"""
if s.count(old)!=1: raise SystemExit("contract use anchor mismatch")
s=s.replace(old,new,1)

old="""     type(b110_default_mvg_provider_t), pointer :: constitutive => null()
     type(b110_source_sink_provider_t), pointer :: source_sink => null()"""
new="""     type(b110_default_mvg_provider_t), pointer :: constitutive => null()
     class(constitutive_hydraulics_provider_t), pointer :: research_constitutive_override => null()
     type(b110_source_sink_provider_t), pointer :: source_sink => null()"""
if s.count(old)!=1: raise SystemExit("model field anchor mismatch")
s=s.replace(old,new,1)

old="""    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: configure_soil_water_model => fmr_serialized_backend_configure_soil_water_model"""
new="""    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: set_research_constitutive_override => fmr_serialized_backend_set_research_constitutive_override
    procedure, public :: configure_soil_water_model => fmr_serialized_backend_configure_soil_water_model"""
if s.count(old)!=1: raise SystemExit("backend method anchor mismatch")
s=s.replace(old,new,1)

old="""    request%evaluation%constitutive => self%constitutive
    request%evaluation%source_sink => self%source_sink"""
new="""    if (associated(self%research_constitutive_override)) then
      request%evaluation%constitutive => self%research_constitutive_override
    else
      request%evaluation%constitutive => self%constitutive
    end if
    request%evaluation%source_sink => self%source_sink"""
if s.count(old)!=1: raise SystemExit("request bind anchor mismatch")
s=s.replace(old,new,1)

# Insert setter immediately before configure method implementation.
anchor="  subroutine fmr_serialized_backend_configure_soil_water_model("
idx=s.find(anchor)
if idx<0: raise SystemExit("configure implementation anchor missing")
setter="""  subroutine fmr_serialized_backend_set_research_constitutive_override(self, provider)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    class(constitutive_hydraulics_provider_t), target, intent(in) :: provider
    self%model%research_constitutive_override => provider
  end subroutine fmr_serialized_backend_set_research_constitutive_override

"""
s=s[:idx]+setter+s[idx:]
p.write_text(s)
print("TABHYD_FMR_CONSTITUTIVE_OVERRIDE_PATCH_APPLIED")
