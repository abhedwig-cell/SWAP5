#!/usr/bin/env python3
"""Research-only genericization of the Reference-Richards temporal indicator.

Creates a renamed research module from the pinned canonical source. The only
semantic edit is constitutive dispatch:
- b110_default_mvg_provider_t retains its exact step-duration consistency gate;
- constitutive evaluation itself is performed through the abstract provider ABI;
- non-MvG providers are no longer rejected solely by concrete type.

No indicator mathematics, normalization, boundary envelope, source/sink policy,
linear algebra, tolerances, or route-selection formula is changed.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch_generic_temporal_indicator.py INPUT.f90 OUTPUT.f90")

src=Path(sys.argv[1]).read_text()

src=src.replace(
    "module mod_reference_richards_temporal_indicator\n",
    "module mod_reference_richards_temporal_indicator_generic_research\n",1)
src=src.replace(
    "public :: evaluate_reference_richards_temporal_indicator",
    "public :: evaluate_reference_richards_temporal_indicator_generic",1)
src=src.replace(
    "subroutine evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)",
    "subroutine evaluate_reference_richards_temporal_indicator_generic(request, solve_result, indicator_request, indicator_result)",1)
src=src.replace(
    "end subroutine evaluate_reference_richards_temporal_indicator",
    "end subroutine evaluate_reference_richards_temporal_indicator_generic",1)
src=src.replace(
    "end module mod_reference_richards_temporal_indicator",
    "end module mod_reference_richards_temporal_indicator_generic_research",1)

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
new="""    ! TAB-HYD research-only generic dispatch. Preserve the canonical concrete
    ! MvG dt-consistency check exactly; do not invent a generic dt contract.
    select type (constitutive => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       scale = max(1.0_real64, abs(constitutive%step_duration), abs(dt))
       if (abs(constitutive%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
    class default
       continue
    end select
    call request%evaluation%constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, &
         capacity_base, dkdh_base)
    call request%evaluation%constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, &
         conductivity_candidate, capacity_candidate, dkdh_candidate)
"""
if src.count(old) != 1:
    raise SystemExit(f"constitutive dispatch anchor mismatch: {src.count(old)}")
src=src.replace(old,new,1)

Path(sys.argv[2]).write_text(src)
print("TABHYD_GENERIC_TEMPORAL_INDICATOR_PATCH_APPLIED")
