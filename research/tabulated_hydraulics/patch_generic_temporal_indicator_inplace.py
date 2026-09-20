#!/usr/bin/env python3
"""Research-only in-place generic constitutive dispatch for canonical temporal indicator.

Applies only the Phase-A-qualified dispatch change to a copied source tree.
No formula, linear algebra, tolerance, boundary envelope, or route policy changes.
"""
from pathlib import Path
import sys
if len(sys.argv)!=2:
    raise SystemExit("usage: patch_generic_temporal_indicator_inplace.py mod_reference_richards_temporal_indicator.f90")
p=Path(sys.argv[1]); s=p.read_text()
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
new="""    ! TAB-HYD research-only generic dispatch. Preserve the exact canonical
    ! MvG dt check; table-provider dt is rebound by the copied runtime before
    ! request construction. This is characterization, not a generic dt contract.
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
if s.count(old)!=1:
    raise SystemExit(f"generic temporal dispatch anchor mismatch: {s.count(old)}")
p.write_text(s.replace(old,new,1))
print("TABHYD_GENERIC_TEMPORAL_INDICATOR_INPLACE_PATCH_APPLIED")
