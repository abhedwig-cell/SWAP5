module mod_b110_dynamic_top_boundary_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       evaluate_b110_default_mvg_conductivity
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t, &
       surface_evaporation_hydraulic_input_t, surface_evaporation_result_t, &
       evaluate_restricted_surface_evaporation, SURFACE_EVAP_AVAILABLE
  implicit none
  private

  integer, parameter, public :: B110_DYN_TOP_NOT_RUN = 0
  integer, parameter, public :: B110_DYN_TOP_AVAILABLE = 1
  integer, parameter, public :: B110_DYN_TOP_INVALID_INPUT = 2
  integer, parameter, public :: B110_DYN_TOP_UNSUPPORTED = 3

  integer, parameter, public :: B110_DYN_TOP_REGIME_NONE = 0
  integer, parameter, public :: B110_DYN_TOP_REGIME_FLUX = 1
  integer, parameter, public :: B110_DYN_TOP_REGIME_HEAD = 2

  real(real64), parameter, public :: B110_DYN_TOP_ATMOSPHERIC_HEAD_CM = -2.75e5_real64
  real(real64), parameter, public :: B110_DYN_TOP_PONDING_CLASSIFICATION_CM = 1.0e-10_real64
  real(real64), parameter, public :: B110_DYN_TOP_HEAD_SWITCH_CM = 1.0e-6_real64
  real(real64), parameter :: B110_DYN_TOP_RUNOFF_ZERO_CM = 1.0e-6_real64
  real(real64), parameter :: B110_DYN_TOP_MIN_LINEAR_RSRO_DAY = 1.0e-3_real64

  type, public :: b110_dynamic_top_boundary_request_t
    integer :: conductivity_mean_method = 0
    real(real64) :: pressure_head_top_cm = 0.0_real64
    real(real64) :: water_content_top = 0.0_real64
    real(real64) :: candidate_ponding_depth_cm = 0.0_real64
    real(real64) :: previous_ponding_depth_cm = 0.0_real64
    real(real64) :: step_duration_day = 0.0_real64
    real(real64) :: precipitation_rate_cm_per_day = 0.0_real64
    real(real64) :: irrigation_rate_cm_per_day = 0.0_real64
    real(real64) :: snowmelt_rate_cm_per_day = 0.0_real64
    real(real64) :: runon_rate_cm_per_day = 0.0_real64
    real(real64) :: potential_bare_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: potential_pond_evaporation_cm_per_day = 0.0_real64
    real(real64) :: ponding_max_cm = 0.0_real64
    real(real64) :: runoff_resistance_day = 0.0_real64
    real(real64) :: runoff_exponent = 1.0_real64
  end type b110_dynamic_top_boundary_request_t

  type, public :: b110_dynamic_top_boundary_result_t
    integer :: status = B110_DYN_TOP_NOT_RUN
    integer :: regime = B110_DYN_TOP_REGIME_NONE
    real(real64) :: actual_top_flux_cm_per_day = 0.0_real64
    real(real64) :: surface_head_cm = 0.0_real64
    real(real64) :: surface_face_conductivity_cm_per_day = 0.0_real64
    real(real64) :: candidate_ponding_depth_cm = 0.0_real64
    real(real64) :: bare_soil_evaporation_cm_per_day = 0.0_real64
    real(real64) :: ponded_water_evaporation_cm_per_day = 0.0_real64
    real(real64) :: runoff_depth_cm = 0.0_real64
    real(real64) :: net_potential_surface_flux_cm_per_day = 0.0_real64
    real(real64) :: evaporation_capacity_cm_per_day = 0.0_real64
    logical :: runoff_potential = .false.
    character(len=48) :: route = 'not-run'
  end type b110_dynamic_top_boundary_result_t

  public :: evaluate_b110_dynamic_top_boundary

contains

  subroutine evaluate_b110_dynamic_top_boundary(geometry, hydraulics, request, result)
    type(soil_water_parameter_set_t), intent(in) :: geometry
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    type(b110_dynamic_top_boundary_request_t), intent(in) :: request
    type(b110_dynamic_top_boundary_result_t), intent(out) :: result

    type(surface_evaporation_demand_t) :: demand
    type(surface_evaporation_hydraulic_input_t) :: evap_hydraulic
    type(surface_evaporation_result_t) :: evaporation
    real(real64) :: k_atm, k_top, k_sat, k1_atm, k1_max
    real(real64) :: emax, q0, q1, h0, h0max, p1, p2, current_runoff
    real(real64) :: top_dz, top_distance
    logical :: ok

    result = b110_dynamic_top_boundary_result_t()

    call validate_request(geometry, hydraulics, request, ok)
    if (.not. ok) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'invalid-input'
      return
    end if

    top_dz = geometry%dz(1)
    top_distance = geometry%node_distance(1)

    call evaluate_b110_default_mvg_conductivity(hydraulics, 1, B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, k_atm, ok)
    if (.not. ok) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'invalid-atmospheric-k'
      return
    end if
    call evaluate_b110_default_mvg_conductivity(hydraulics, 1, request%pressure_head_top_cm, k_top, ok)
    if (.not. ok) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'invalid-top-k'
      return
    end if
    call evaluate_b110_default_mvg_conductivity(hydraulics, 1, 0.0_real64, k_sat, ok)
    if (.not. ok) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'invalid-saturated-k'
      return
    end if

    call restricted_hcomean(request%conductivity_mean_method, k_atm, k_top, top_dz, top_dz, k1_atm, ok)
    if (.not. ok) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'invalid-atmospheric-face-k'
      return
    end if
    call restricted_hcomean(request%conductivity_mean_method, k_sat, k_top, top_dz, top_dz, k1_max, ok)
    if (.not. ok) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'invalid-saturated-face-k'
      return
    end if

    emax = -k1_atm * ((B110_DYN_TOP_ATMOSPHERIC_HEAD_CM-request%pressure_head_top_cm)/top_distance + 1.0_real64)
    if (.not. ieee_is_finite(emax)) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'nonfinite-emax'
      return
    end if
    result%evaporation_capacity_cm_per_day = emax

    demand%bare_soil_demand = request%potential_bare_soil_evaporation_cm_per_day
    demand%ponded_water_demand = request%potential_pond_evaporation_cm_per_day
    evap_hydraulic%surface_is_ponded = request%previous_ponding_depth_cm > B110_DYN_TOP_PONDING_CLASSIFICATION_CM
    evap_hydraulic%evaporation_capacity = emax
    call evaluate_restricted_surface_evaporation(demand, evap_hydraulic, evaporation)
    if (evaporation%status /= SURFACE_EVAP_AVAILABLE) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'evaporation-rejected'
      return
    end if
    result%bare_soil_evaporation_cm_per_day = evaporation%bare_soil_evaporation
    result%ponded_water_evaporation_cm_per_day = evaporation%ponded_water_evaporation

    q0 = request%precipitation_rate_cm_per_day + request%irrigation_rate_cm_per_day + &
         request%snowmelt_rate_cm_per_day + request%runon_rate_cm_per_day - &
         result%bare_soil_evaporation_cm_per_day - result%ponded_water_evaporation_cm_per_day
    q1 = -q0 - request%previous_ponding_depth_cm/request%step_duration_day
    result%net_potential_surface_flux_cm_per_day = q0

    if (q1 >= 0.0_real64 .and. q1 > emax) then
      result%regime = B110_DYN_TOP_REGIME_HEAD
      result%surface_head_cm = B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
      result%surface_face_conductivity_cm_per_day = k1_atm
      result%candidate_ponding_depth_cm = 0.0_real64
      result%runoff_depth_cm = 0.0_real64
      result%runoff_potential = .false.
      result%actual_top_flux_cm_per_day = -k1_atm * &
           ((result%surface_head_cm-request%pressure_head_top_cm)/top_distance + 1.0_real64)
      result%status = B110_DYN_TOP_AVAILABLE
      result%route = 'atmospheric-head'
      return
    end if

    if (k1_max <= 0.0_real64) then
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'nonpositive-saturated-face-k'
      return
    end if
    h0 = request%pressure_head_top_cm - top_distance*(q1/k1_max + 1.0_real64)
    if (h0 <= B110_DYN_TOP_HEAD_SWITCH_CM) then
      result%regime = B110_DYN_TOP_REGIME_FLUX
      result%actual_top_flux_cm_per_day = q1
      result%surface_head_cm = 0.0_real64
      result%surface_face_conductivity_cm_per_day = 0.0_real64
      result%candidate_ponding_depth_cm = 0.0_real64
      result%runoff_depth_cm = 0.0_real64
      result%runoff_potential = .false.
      result%status = B110_DYN_TOP_AVAILABLE
      result%route = 'surface-flux'
      return
    end if

    result%regime = B110_DYN_TOP_REGIME_HEAD
    result%surface_face_conductivity_cm_per_day = k1_max
    result%runoff_potential = .true.
    p1 = k1_max/top_distance * request%step_duration_day
    p2 = 1.0_real64/(p1+1.0_real64)
    h0max = p2 * (request%previous_ponding_depth_cm + q0*request%step_duration_day - &
         k1_max*request%step_duration_day + p1*request%pressure_head_top_cm)

    if (h0max <= request%ponding_max_cm) then
      result%candidate_ponding_depth_cm = max(0.0_real64, h0max)
      result%runoff_depth_cm = 0.0_real64
    else
      current_runoff = restricted_linear_runoff_depth(request%candidate_ponding_depth_cm, request)
      if (abs(current_runoff) < B110_DYN_TOP_RUNOFF_ZERO_CM) then
        result%candidate_ponding_depth_cm = max(0.0_real64, h0max)
        result%runoff_depth_cm = current_runoff
      else
        if (request%runoff_resistance_day < B110_DYN_TOP_MIN_LINEAR_RSRO_DAY .or. &
            request%runoff_exponent /= 1.0_real64) then
          result%status = B110_DYN_TOP_UNSUPPORTED
          result%route = 'active-runoff-outside-profile'
          return
        end if
        p2 = 1.0_real64/(p1 + 1.0_real64 + request%step_duration_day/request%runoff_resistance_day)
        result%candidate_ponding_depth_cm = p2 * (request%previous_ponding_depth_cm + &
             q0*request%step_duration_day - k1_max*request%step_duration_day + &
             p1*request%pressure_head_top_cm + &
             request%step_duration_day/request%runoff_resistance_day*request%ponding_max_cm)
        result%candidate_ponding_depth_cm = max(0.0_real64, result%candidate_ponding_depth_cm)
        result%runoff_depth_cm = restricted_linear_runoff_depth(result%candidate_ponding_depth_cm, request)
      end if
    end if

    result%surface_head_cm = result%candidate_ponding_depth_cm
    result%actual_top_flux_cm_per_day = -k1_max * &
         ((result%surface_head_cm-request%pressure_head_top_cm)/top_distance + 1.0_real64)
    if (.not. all_finite_result(result)) then
      result = b110_dynamic_top_boundary_result_t()
      result%status = B110_DYN_TOP_INVALID_INPUT
      result%route = 'nonfinite-result'
      return
    end if
    result%status = B110_DYN_TOP_AVAILABLE
    if (result%runoff_depth_cm == 0.0_real64) then
      result%route = 'ponded-head'
    else
      result%route = 'ponded-head-linear-runoff'
    end if
  end subroutine evaluate_b110_dynamic_top_boundary

  subroutine validate_request(geometry, hydraulics, request, ok)
    type(soil_water_parameter_set_t), intent(in) :: geometry
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    type(b110_dynamic_top_boundary_request_t), intent(in) :: request
    logical, intent(out) :: ok
    real(real64) :: values(14)
    integer :: n

    ok = .false.
    n = geometry%active_nodes
    if (n <= 0 .or. hydraulics%active_nodes /= n) return
    if (.not. allocated(geometry%dz) .or. .not. allocated(geometry%node_distance)) return
    if (size(geometry%dz) /= n .or. size(geometry%node_distance) /= n) return
    if (geometry%dz(1) <= 0.0_real64 .or. geometry%node_distance(1) <= 0.0_real64) return
    if (request%conductivity_mean_method < 1 .or. request%conductivity_mean_method > 6) return

    values = [request%pressure_head_top_cm, request%water_content_top, &
         request%candidate_ponding_depth_cm, request%previous_ponding_depth_cm, &
         request%step_duration_day, request%precipitation_rate_cm_per_day, &
         request%irrigation_rate_cm_per_day, request%snowmelt_rate_cm_per_day, &
         request%runon_rate_cm_per_day, request%potential_bare_soil_evaporation_cm_per_day, &
         request%potential_pond_evaporation_cm_per_day, request%ponding_max_cm, &
         request%runoff_resistance_day, request%runoff_exponent]
    if (.not. all(ieee_is_finite(values))) return
    if (request%candidate_ponding_depth_cm < 0.0_real64) return
    if (request%previous_ponding_depth_cm < 0.0_real64) return
    if (request%step_duration_day <= 0.0_real64) return
    if (request%potential_bare_soil_evaporation_cm_per_day < 0.0_real64) return
    if (request%potential_pond_evaporation_cm_per_day < 0.0_real64) return
    if (request%ponding_max_cm < 0.0_real64) return
    if (request%runoff_resistance_day < 0.0_real64) return
    ok = .true.
  end subroutine validate_request

  pure real(real64) function restricted_linear_runoff_depth(ponding_depth_cm, request) result(runoff_depth)
    real(real64), intent(in) :: ponding_depth_cm
    type(b110_dynamic_top_boundary_request_t), intent(in) :: request
    runoff_depth = 0.0_real64
    if (ponding_depth_cm <= request%ponding_max_cm) return
    if (request%runoff_resistance_day < B110_DYN_TOP_MIN_LINEAR_RSRO_DAY) then
      runoff_depth = ponding_depth_cm-request%ponding_max_cm
    else if (request%runoff_exponent == 1.0_real64) then
      runoff_depth = request%step_duration_day/request%runoff_resistance_day * &
           (ponding_depth_cm-request%ponding_max_cm)
    else
      runoff_depth = huge(1.0_real64)
    end if
  end function restricted_linear_runoff_depth

  pure logical function all_finite_result(result) result(ok)
    type(b110_dynamic_top_boundary_result_t), intent(in) :: result
    real(real64) :: values(9)
    values = [result%actual_top_flux_cm_per_day, result%surface_head_cm, &
         result%surface_face_conductivity_cm_per_day, result%candidate_ponding_depth_cm, &
         result%bare_soil_evaporation_cm_per_day, result%ponded_water_evaporation_cm_per_day, &
         result%runoff_depth_cm, result%net_potential_surface_flux_cm_per_day, &
         result%evaporation_capacity_cm_per_day]
    ok = all(ieee_is_finite(values))
  end function all_finite_result

  subroutine restricted_hcomean(method, kup, klow, dzup, dzlow, kmean, ok)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow
    real(real64), intent(out) :: kmean
    logical, intent(out) :: ok
    real(real64) :: a1, a2, denom

    kmean = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(kup) .or. .not. ieee_is_finite(klow) .or. &
        .not. ieee_is_finite(dzup) .or. .not. ieee_is_finite(dzlow)) return
    if (kup < 0.0_real64 .or. klow < 0.0_real64 .or. dzup <= 0.0_real64 .or. dzlow <= 0.0_real64) return
    denom = dzup+dzlow
    if (denom <= 0.0_real64) return
    a1 = dzup/denom
    a2 = 1.0_real64-a1

    select case (method)
    case (1)
      kmean = 0.5_real64*(kup+klow)
    case (2)
      kmean = (dzup*kup+dzlow*klow)/denom
    case (3)
      kmean = sqrt(kup*klow)
    case (4)
      kmean = kup**a1 * klow**a2
    case (5)
      if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
      kmean = 1.0_real64/(0.5_real64/kup+0.5_real64/klow)
    case (6)
      if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
      kmean = 1.0_real64/(a1/kup+a2/klow)
    case default
      return
    end select
    if (.not. ieee_is_finite(kmean) .or. kmean < 0.0_real64) then
      kmean = 0.0_real64
      return
    end if
    ok = .true.
  end subroutine restricted_hcomean

end module mod_b110_dynamic_top_boundary_provider
