#!/usr/bin/env python3
"""Research-only TAB-HYD-CTX01 context-capability candidate.

Usage:
  patch_context_capability.py CONTRACT MGV_PROVIDER TABLE_PROVIDER TEMPORAL_INPUT TEMPORAL_OUTPUT

The hot constitutive evaluate ABI is intentionally unchanged.
"""
from pathlib import Path
import sys

if len(sys.argv) != 6:
    raise SystemExit("usage: patch_context_capability.py CONTRACT MGV_PROVIDER TABLE_PROVIDER TEMPORAL_INPUT TEMPORAL_OUTPUT")

contract=Path(sys.argv[1])
mvg=Path(sys.argv[2])
table=Path(sys.argv[3])
temporal_in=Path(sys.argv[4])
temporal_out=Path(sys.argv[5])

# --- common contract: fail-closed non-deferred capability
s=contract.read_text()
old="""  type, abstract, public :: constitutive_hydraulics_provider_t
   contains
     procedure(constitutive_evaluate_ifc), deferred :: evaluate
  end type constitutive_hydraulics_provider_t
"""
new="""  type, abstract, public :: constitutive_hydraulics_provider_t
   contains
     procedure(constitutive_evaluate_ifc), deferred :: evaluate
     procedure :: context_compatible => constitutive_context_incompatible
  end type constitutive_hydraulics_provider_t
"""
if s.count(old)!=1:
    raise SystemExit(f"contract type anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

anchor="""contains

  subroutine validate_soil_water_request(request, ok)
"""
insert="""contains

  logical function constitutive_context_incompatible(self, step_duration) result(compatible)
    class(constitutive_hydraulics_provider_t), intent(in) :: self
    real(real64), intent(in) :: step_duration
    compatible = .false.
  end function constitutive_context_incompatible

  subroutine validate_soil_water_request(request, ok)
"""
if s.count(anchor)!=1:
    raise SystemExit(f"contract contains anchor mismatch: {s.count(anchor)}")
s=s.replace(anchor,insert,1)
contract.write_text(s)

# --- analytical provider override
s=mvg.read_text()
old="""   contains
     procedure :: evaluate => b110_default_mvg_evaluate
  end type b110_default_mvg_provider_t
"""
new="""   contains
     procedure :: evaluate => b110_default_mvg_evaluate
     procedure :: context_compatible => b110_default_mvg_context_compatible
  end type b110_default_mvg_provider_t
"""
if s.count(old)!=1:
    raise SystemExit(f"MvG type anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

anchor="""  subroutine b110_default_mvg_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
"""
insert="""  logical function b110_default_mvg_context_compatible(self, step_duration) result(compatible)
    class(b110_default_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: step_duration
    real(real64) :: scale

    compatible = .false.
    if (.not. associated(self%parameters)) return
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    if (.not. ieee_is_finite(self%step_duration) .or. self%step_duration <= 0.0_real64) return
    scale = max(1.0_real64, abs(self%step_duration), abs(step_duration))
    compatible = abs(self%step_duration-step_duration) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function b110_default_mvg_context_compatible

  subroutine b110_default_mvg_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
"""
if s.count(anchor)!=1:
    raise SystemExit(f"MvG evaluate anchor mismatch: {s.count(anchor)}")
s=s.replace(anchor,insert,1)
mvg.write_text(s)

# --- generated table provider override
s=table.read_text()
old="""  contains
    procedure :: evaluate => tabhyd_raw_evaluate
  end type tabhyd_raw_provider_t
"""
new="""  contains
    procedure :: evaluate => tabhyd_raw_evaluate
    procedure :: context_compatible => tabhyd_raw_context_compatible
  end type tabhyd_raw_provider_t
"""
if s.count(old)!=1:
    raise SystemExit(f"table type anchor mismatch: {s.count(old)}")
s=s.replace(old,new,1)

anchor="""  subroutine tabhyd_raw_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
"""
insert="""  logical function tabhyd_raw_context_compatible(self, step_duration) result(compatible)
    class(tabhyd_raw_provider_t), intent(in) :: self
    real(real64), intent(in) :: step_duration
    real(real64) :: scale

    compatible = .false.
    if (self%active_nodes <= 0 .or. .not. allocated(self%head)) return
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    if (.not. ieee_is_finite(self%step_duration) .or. self%step_duration <= 0.0_real64) return
    scale = max(1.0_real64, abs(self%step_duration), abs(step_duration))
    compatible = abs(self%step_duration-step_duration) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function tabhyd_raw_context_compatible

  subroutine tabhyd_raw_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
"""
if s.count(anchor)!=1:
    raise SystemExit(f"table evaluate anchor mismatch: {s.count(anchor)}")
s=s.replace(anchor,insert,1)
table.write_text(s)

# --- renamed temporal-indicator candidate using only the generic capability
src=temporal_in.read_text()
src=src.replace(
    "module mod_reference_richards_temporal_indicator\n",
    "module mod_reference_richards_temporal_indicator_context_research\n",1)
src=src.replace(
    "public :: evaluate_reference_richards_temporal_indicator",
    "public :: evaluate_reference_richards_temporal_indicator_context",1)
src=src.replace(
    "subroutine evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)",
    "subroutine evaluate_reference_richards_temporal_indicator_context(request, solve_result, indicator_request, indicator_result)",1)
src=src.replace(
    "end subroutine evaluate_reference_richards_temporal_indicator",
    "end subroutine evaluate_reference_richards_temporal_indicator_context",1)
src=src.replace(
    "end module mod_reference_richards_temporal_indicator",
    "end module mod_reference_richards_temporal_indicator_context_research",1)

old="""    select type (constitutive => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       scale = max(1.0_real64, abs(constitutive%step_duration), abs(dt))
       if (abs(constitutive%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
       call constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, capacity_base, dkdh_base)
       call constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, conductivity_candidate, &
            capacity_candidate, dkdh_candidate)
    class default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'constitutive-policy-deferred'
       return
    end select
"""
new="""    ! TAB-HYD-CTX01: generic fail-closed context capability. The hot
    ! constitutive evaluate ABI remains unchanged.
    if (.not. request%evaluation%constitutive%context_compatible(dt)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'constitutive-dt-mismatch'
       return
    end if
    call request%evaluation%constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, &
         capacity_base, dkdh_base)
    call request%evaluation%constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, &
         conductivity_candidate, capacity_candidate, dkdh_candidate)
"""
if src.count(old)!=1:
    raise SystemExit(f"temporal dispatch anchor mismatch: {src.count(old)}")
src=src.replace(old,new,1)
temporal_out.write_text(src)

print("TABHYD_CTX01_CONTEXT_CAPABILITY_PATCH_APPLIED")
