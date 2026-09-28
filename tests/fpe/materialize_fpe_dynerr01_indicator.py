#!/usr/bin/env python3
from pathlib import Path
import sys

src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])

src=src.replace("module mod_reference_richards_temporal_indicator","module mod_fpe_dynerr01_temporal_indicator",1)
src=src.replace("end module mod_reference_richards_temporal_indicator","end module mod_fpe_dynerr01_temporal_indicator",1)
src=src.replace(
"""  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED, CONSTITUTIVE_DEMAND_WATER_CONTENT, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX""",
"""  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       soil_water_boundary_conditions_t, soil_water_top_boundary_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED, SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX, &
       SW_TOP_BOUNDARY_REGIME_HEAD, CONSTITUTIVE_DEMAND_WATER_CONTENT, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER""")
src=src.replace("  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n","")
src=src.replace(
"""    real(real64), allocatable :: mass_weight(:), lower(:), diagonal(:), upper(:), rhs(:), delta(:), gamma(:), e_raw(:)
""",
"""    real(real64), allocatable :: mass_weight(:), lower(:), diagonal(:), upper(:), rhs(:), delta(:), gamma(:), e_raw(:)
    type(soil_water_boundary_conditions_t) :: dynamic_bc
    type(soil_water_top_boundary_result_t) :: dynamic_top
""")
old="""    if (request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX .or. &
        (request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'boundary-envelope-deferred'
       return
    end if
    if (.not. associated(request%evaluation%constitutive) .or. &
        .not. associated(request%evaluation%source_sink) .or. &
        .not. associated(request%evaluation%top_boundary)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'provider-envelope-incomplete'
       return
    end if

    select type (top_provider => request%evaluation%top_boundary)
    type is (fixed_flux_top_boundary_provider_t)
       continue
    class default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'fixed-top-flux-required'
       return
    end select
"""
new="""    if (request%boundary%top_mode /= FSI_TOP_MODE_DYNAMIC_PROVIDER .or. &
        (request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'dynamic-boundary-envelope-deferred'
       return
    end if
    if (.not. associated(request%evaluation%constitutive) .or. &
        .not. associated(request%evaluation%source_sink) .or. &
        .not. associated(request%evaluation%dynamic_top_boundary)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'dynamic-provider-envelope-incomplete'
       return
    end if

"""
if old not in src:
    raise SystemExit("boundary guard source drift")
src=src.replace(old,new,1)

needle="""    ! Prescribed bottom head (mode 5) contributes a Dirichlet face stiffness
"""
insert="""    dynamic_bc = soil_water_boundary_conditions_t()
    call request%evaluation%dynamic_top_boundary%evaluate( &
         solve_result%candidate_state%pressure_head(1), solve_result%candidate_state%water_content(1), &
         solve_result%candidate_state%ponding_depth, dynamic_bc, dynamic_top)
    if (dynamic_top%status /= SW_TOP_BOUNDARY_AVAILABLE) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'dynamic-top-evaluation-failed'
       return
    end if
    select case (dynamic_top%regime)
    case (SW_TOP_BOUNDARY_REGIME_FLUX)
       continue
    case (SW_TOP_BOUNDARY_REGIME_HEAD)
       if (.not. dynamic_top%surface_head_derivative_available) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'dynamic-top-derivative-missing'
          return
       end if
       if (.not. ieee_is_finite(request%parameters%node_distance(1)) .or. &
           request%parameters%node_distance(1) <= 0.0_real64) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'invalid-top-distance'
          return
       end if
       face_conductance = dynamic_top%surface_face_conductivity/request%parameters%node_distance(1) * &
            (1.0_real64-dynamic_top%surface_head_dpressure_head_top)
       if (.not. ieee_is_finite(face_conductance) .or. face_conductance < 0.0_real64) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'invalid-dynamic-top-stiffness'
          return
       end if
       diagonal(1) = diagonal(1)+face_conductance
    case default
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'dynamic-top-regime-invalid'
       return
    end select

    ! Prescribed bottom head (mode 5) contributes a Dirichlet face stiffness
"""
if needle not in src:
    raise SystemExit("operator insertion source drift")
src=src.replace(needle,insert,1)

out.write_text(src)
print("F_PE_DYNERR01_MATERIALIZE=PASS")
