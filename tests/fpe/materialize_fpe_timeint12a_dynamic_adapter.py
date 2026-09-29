#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()
old="mod_b110_dynamic_top_boundary_solver_adapter"
new="mod_fpe_timeint12a_dynamic_top_boundary_solver_adapter"
src=src.replace(f"module {old}",f"module {new}",1)
src=src.replace(f"end module {old}",f"end module {new}",1)

src=src.replace(
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t\n",
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n       bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity\n  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction\n"
)

old_decl="""    type(b110_dynamic_top_boundary_request_t) :: b110_request
    type(b110_dynamic_top_boundary_result_t) :: b110_result
"""
new_decl="""    type(b110_dynamic_top_boundary_request_t) :: b110_request
    type(b110_dynamic_top_boundary_result_t) :: b110_result
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64), allocatable :: heads(:), dirs(:), dtheta(:), dk(:), basek(:)
    real(real64) :: ksat, ktop, dk_top, kf, dkf, a, p1, p1p, denom, aprime
    logical :: dir_ok, k_ok
    character(len=64) :: dir_route
"""
if old_decl not in src: raise SystemExit("declaration patch point missing")
src=src.replace(old_decl,new_decl,1)

marker="""    if (b110_result%status /= B110_DYN_TOP_AVAILABLE) then
       result%status = SW_TOP_BOUNDARY_UNAVAILABLE
       result%route = b110_result%route
       return
    end if

    result%status = SW_TOP_BOUNDARY_AVAILABLE
"""
insert="""    if (b110_result%status /= B110_DYN_TOP_AVAILABLE) then
       result%status = SW_TOP_BOUNDARY_UNAVAILABLE
       result%route = b110_result%route
       return
    end if

    ! TIMEINT12A test-only: publish the qualified fully implicit surface-head
    ! derivative when the value provider is on a smooth head-regime route and
    ! top conductivity is not fixed.
    if (.not. b110_result%surface_head_derivative_available .and. &
        b110_result%regime == B110_DYN_TOP_REGIME_HEAD .and. &
        self%fixed_top_node_conductivity < 0.0_real64 .and. self%conductivity_mean_method == 1) then
       allocate(heads(self%hydraulics%active_nodes), dirs(self%hydraulics%active_nodes), &
                dtheta(self%hydraulics%active_nodes), dk(self%hydraulics%active_nodes), &
                basek(self%hydraulics%active_nodes))
       heads = pressure_head_top
       dirs = 0.0_real64
       dirs(1) = 1.0_real64
       call bind_b110_default_mvg_provider(constitutive, self%hydraulics, self%step_duration)
       call evaluate_b110_default_mvg_state_direction(constitutive, heads, dirs, dtheta, dk, &
            dir_ok, dir_route, basek)
       call evaluate_b110_default_mvg_conductivity(self%hydraulics, 1, 0.0_real64, ksat, k_ok)
       if (dir_ok .and. k_ok) then
          ktop = basek(1)
          dk_top = dk(1)
          kf = 0.5_real64*(ksat+ktop)
          dkf = 0.5_real64*dk_top
          a = self%step_duration/self%geometry%node_distance(1)
          p1 = a*kf
          p1p = a*dkf
          denom = 1.0_real64+p1
          if (trim(b110_result%route) == 'ponded-head-linear-runoff') &
             denom = denom+self%step_duration/self%runoff_resistance
          aprime = -dkf*self%step_duration+p1p*pressure_head_top+p1
          b110_result%surface_head_dpressure_head_top = &
               (aprime-b110_result%surface_head_cm*p1p)/denom
          b110_result%surface_head_derivative_available = .true.
       end if
    end if

    result%status = SW_TOP_BOUNDARY_AVAILABLE
"""
if marker not in src: raise SystemExit("status patch point missing")
src=src.replace(marker,insert,1)
Path(args.output).write_text(src)
print("F_PE_TIMEINT12A_ADAPTER_MATERIALIZER=PASS")
