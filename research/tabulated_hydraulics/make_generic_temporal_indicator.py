#!/usr/bin/env python3
"""Create a research-only provider-generic copy of the canonical temporal indicator.

Only the constitutive-provider dispatch is changed. For the canonical analytical
provider the existing step-duration check remains exact. All providers then use
the same abstract evaluate() calls and unchanged indicator mathematics.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: make_generic_temporal_indicator.py INPUT.f90 OUTPUT.f90")

src=Path(sys.argv[1]).read_text()

src=src.replace(
    "module mod_reference_richards_temporal_indicator\n",
    "module mod_reference_richards_temporal_indicator_generic_research\n",1)
src=src.replace(
    "  public :: evaluate_reference_richards_temporal_indicator\n",
    "  public :: evaluate_reference_richards_temporal_indicator_generic\n",1)
src=src.replace(
    "  subroutine evaluate_reference_richards_temporal_indicator(request, solve_result, indicator_request, indicator_result)\n",
    "  subroutine evaluate_reference_richards_temporal_indicator_generic(request, solve_result, indicator_request, indicator_result)\n",1)
src=src.replace(
    "  end subroutine evaluate_reference_richards_temporal_indicator\n\nend module mod_reference_richards_temporal_indicator\n",
    "  end subroutine evaluate_reference_richards_temporal_indicator_generic\n\nend module mod_reference_richards_temporal_indicator_generic_research\n",1)

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
new="""    select type (constitutive => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       ! Preserve the canonical analytical-provider context check exactly.
       scale = max(1.0_real64, abs(constitutive%step_duration), abs(dt))
       if (abs(constitutive%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
    class default
       ! Research characterization only: the common provider ABI has no
       ! generic step-duration capability method yet.
       continue
    end select
    call request%evaluation%constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, &
         capacity_base, dkdh_base)
    call request%evaluation%constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, &
         conductivity_candidate, capacity_candidate, dkdh_candidate)
"""
if src.count(old)!=1:
    raise SystemExit(f"constitutive dispatch anchor mismatch: {src.count(old)}")
src=src.replace(old,new,1)

Path(sys.argv[2]).write_text(src)
print("TABHYD_GENERIC_TEMPORAL_INDICATOR_PATCHED")
