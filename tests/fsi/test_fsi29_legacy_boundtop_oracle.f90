program test_fsi29_legacy_boundtop_oracle
  use, intrinsic :: iso_fortran_env, only: real64, error_unit
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_UNSUPPORTED, &
       B110_DYN_TOP_REGIME_FLUX, B110_DYN_TOP_REGIME_HEAD, &
       B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
  implicit none

  integer, parameter :: nnode = 2
  integer, parameter :: ROUTE_ATMOSPHERIC = 1, ROUTE_FLUX = 2, ROUTE_PONDED = 3, ROUTE_RUNOFF = 4
  real(real64), parameter :: POND_CLASS_CM = 1.0e-10_real64
  real(real64), parameter :: HEAD_SWITCH_CM = 1.0e-6_real64
  real(real64), parameter :: RUNOFF_ZERO_CM = 1.0e-6_real64
  real(real64), parameter :: MIN_RSRO_DAY = 1.0e-3_real64

  type :: oracle_result_t
    integer :: status = 0
    integer :: regime = 0
    integer :: route_class = 0
    real(real64) :: actual_top_flux = 0.0_real64
    real(real64) :: surface_head = 0.0_real64
    real(real64) :: surface_face_k = 0.0_real64
    real(real64) :: pond = 0.0_real64
    real(real64) :: bare_evap = 0.0_real64
    real(real64) :: pond_evap = 0.0_real64
    real(real64) :: runoff = 0.0_real64
    real(real64) :: q0 = 0.0_real64
    real(real64) :: emax = 0.0_real64
    logical :: runoff_potential = .false.
  end type oracle_result_t

  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hydraulics
  type(b110_dynamic_top_boundary_request_t) :: req, req_before
  type(b110_dynamic_top_boundary_result_t) :: got
  type(oracle_result_t) :: expected
  type(b110_dynamic_top_boundary_request_t) :: replay_req(8)
  type(b110_dynamic_top_boundary_result_t) :: replay_ref(8), replay_got
  real(real64) :: raw(24,nnode)
  real(real64), parameter :: hcases(4) = [-1000.0_real64, -100.0_real64, -10.0_real64, -1.0_real64]
  real(real64), parameter :: prevpond(3) = [0.0_real64, 1.0e-8_real64, 0.02_real64]
  real(real64), parameter :: candpond(3) = [0.0_real64, 0.005_real64, 0.05_real64]
  real(real64), parameter :: pondmx_cases(2) = [0.01_real64, 2.0_real64]
  integer :: method, ih, iprev, icand, ipondmx, ievap, isupply, cases, i
  integer :: n_atm, n_flux, n_pond, n_runoff
  real(real64) :: mass_residual, worst_mass
  logical :: ok

  call configure_family(raw, geometry)
  call initialize_b110_default_mvg_parameters(hydraulics, raw)

  cases = 0
  n_atm = 0
  n_flux = 0
  n_pond = 0
  n_runoff = 0
  worst_mass = 0.0_real64

  do method = 1, 6
    do ih = 1, size(hcases)
      do iprev = 1, size(prevpond)
        do icand = 1, size(candpond)
          do ipondmx = 1, size(pondmx_cases)
            do ievap = 1, 3
              do isupply = 1, 7
                call initialize_request(req, method)
                req%pressure_head_top_cm = hcases(ih)
                req%previous_ponding_depth_cm = prevpond(iprev)
                req%candidate_ponding_depth_cm = candpond(icand)
                req%ponding_max_cm = pondmx_cases(ipondmx)
                call set_evaporation_case(req, ievap)
                call set_supply_case(req, isupply)
                req_before = req

                call legacy_restricted_oracle(geometry, hydraulics, req, expected, ok)
                call require(ok, 29201)
                call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, got)
                call require(same_request(req, req_before), 29202)
                call compare_result(got, expected, 29210)
                cases = cases + 1

                select case (expected%route_class)
                case (ROUTE_ATMOSPHERIC)
                  n_atm = n_atm + 1
                case (ROUTE_FLUX)
                  n_flux = n_flux + 1
                case (ROUTE_PONDED)
                  n_pond = n_pond + 1
                case (ROUTE_RUNOFF)
                  n_runoff = n_runoff + 1
                case default
                  call require(.false., 29203)
                end select

                if (expected%status == B110_DYN_TOP_AVAILABLE .and. expected%route_class /= ROUTE_ATMOSPHERIC) then
                  mass_residual = surface_mass_residual(req, got)
                  worst_mass = max(worst_mass, abs(mass_residual))
                  call require(abs(mass_residual) <= 1.0e-12_real64, 29204)
                end if
              end do
            end do
          end do
        end do
      end do
    end do
  end do

  call require(n_atm > 0, 29205)
  call require(n_flux > 0, 29206)
  call require(n_pond > 0, 29207)
  call require(n_runoff > 0, 29208)

  ! Interleaved replay emulates eight independent worker requests without shared mutable provider state.
  do i = 1, 8
    call initialize_request(replay_req(i), 1 + mod(i-1,6))
    replay_req(i)%pressure_head_top_cm = hcases(1 + mod(i-1,size(hcases)))
    replay_req(i)%previous_ponding_depth_cm = prevpond(1 + mod(i-1,size(prevpond)))
    replay_req(i)%candidate_ponding_depth_cm = candpond(1 + mod(2*i-1,size(candpond)))
    replay_req(i)%ponding_max_cm = pondmx_cases(1 + mod(i-1,size(pondmx_cases)))
    call set_evaporation_case(replay_req(i), 1 + mod(i-1,3))
    call set_supply_case(replay_req(i), 1 + mod(i-1,7))
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, replay_req(i), replay_ref(i))
  end do
  do i = 8, 1, -1
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, replay_req(i), replay_got)
    call require(same_candidate_result(replay_got, replay_ref(i)), 29209)
  end do

  write(*,'(A,I0)') 'FSI29_ORACLE_CASES=', cases
  write(*,'(A,I0)') 'FSI29_ORACLE_ATMOSPHERIC_CASES=', n_atm
  write(*,'(A,I0)') 'FSI29_ORACLE_FLUX_CASES=', n_flux
  write(*,'(A,I0)') 'FSI29_ORACLE_PONDED_CASES=', n_pond
  write(*,'(A,I0)') 'FSI29_ORACLE_RUNOFF_CASES=', n_runoff
  write(*,'(A,ES24.16)') 'FSI29_ORACLE_WORST_SURFACE_MASS_RESIDUAL_CM=', worst_mass
  write(*,'(A)') 'FSI29_LEGACY_BOUNDARY_ORACLE=PASS'
  write(*,'(A)') 'FSI29_EIGHT_CONTEXT_INTERLEAVED_REPLAY=PASS'

contains

  subroutine legacy_restricted_oracle(g, hyd, x, y, success)
    type(soil_water_parameter_set_t), intent(in) :: g
    type(b110_default_mvg_parameters_t), intent(in) :: hyd
    type(b110_dynamic_top_boundary_request_t), intent(in) :: x
    type(oracle_result_t), intent(out) :: y
    logical, intent(out) :: success
    real(real64) :: k_atm, k_top, k_sat, k1_atm, k1_max
    real(real64) :: q1, h0, h0max, p1, p2, current_runoff, top_dz, top_distance
    logical :: local_ok

    y = oracle_result_t()
    success = .false.
    top_dz = g%dz(1)
    top_distance = g%node_distance(1)

    call evaluate_b110_default_mvg_conductivity(hyd, 1, B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, k_atm, local_ok)
    if (.not. local_ok) return
    call evaluate_b110_default_mvg_conductivity(hyd, 1, x%pressure_head_top_cm, k_top, local_ok)
    if (.not. local_ok) return
    call evaluate_b110_default_mvg_conductivity(hyd, 1, 0.0_real64, k_sat, local_ok)
    if (.not. local_ok) return
    call oracle_hcomean(x%conductivity_mean_method, k_atm, k_top, top_dz, top_dz, k1_atm, local_ok)
    if (.not. local_ok) return
    call oracle_hcomean(x%conductivity_mean_method, k_sat, k_top, top_dz, top_dz, k1_max, local_ok)
    if (.not. local_ok) return

    y%emax = -k1_atm * ((B110_DYN_TOP_ATMOSPHERIC_HEAD_CM-x%pressure_head_top_cm)/top_distance + 1.0_real64)
    if (x%previous_ponding_depth_cm > POND_CLASS_CM) then
      y%bare_evap = 0.0_real64
      y%pond_evap = x%potential_pond_evaporation_cm_per_day
    else
      y%bare_evap = min(x%potential_bare_soil_evaporation_cm_per_day, max(0.0_real64, y%emax))
      y%pond_evap = 0.0_real64
    end if

    y%q0 = x%precipitation_rate_cm_per_day + x%irrigation_rate_cm_per_day + &
         x%snowmelt_rate_cm_per_day + x%runon_rate_cm_per_day - y%bare_evap - y%pond_evap
    q1 = -y%q0 - x%previous_ponding_depth_cm/x%step_duration_day

    if (q1 >= 0.0_real64 .and. q1 > y%emax) then
      y%status = B110_DYN_TOP_AVAILABLE
      y%regime = B110_DYN_TOP_REGIME_HEAD
      y%route_class = ROUTE_ATMOSPHERIC
      y%surface_head = B110_DYN_TOP_ATMOSPHERIC_HEAD_CM
      y%surface_face_k = k1_atm
      y%actual_top_flux = -k1_atm*((y%surface_head-x%pressure_head_top_cm)/top_distance + 1.0_real64)
      success = .true.
      return
    end if

    h0 = x%pressure_head_top_cm - top_distance*(q1/k1_max + 1.0_real64)
    if (h0 <= HEAD_SWITCH_CM) then
      y%status = B110_DYN_TOP_AVAILABLE
      y%regime = B110_DYN_TOP_REGIME_FLUX
      y%route_class = ROUTE_FLUX
      y%actual_top_flux = q1
      success = .true.
      return
    end if

    y%regime = B110_DYN_TOP_REGIME_HEAD
    y%surface_face_k = k1_max
    y%runoff_potential = .true.
    p1 = k1_max/top_distance*x%step_duration_day
    p2 = 1.0_real64/(p1+1.0_real64)
    h0max = p2*(x%previous_ponding_depth_cm + y%q0*x%step_duration_day - &
         k1_max*x%step_duration_day + p1*x%pressure_head_top_cm)

    if (h0max <= x%ponding_max_cm) then
      y%pond = h0max
      y%runoff = 0.0_real64
      y%route_class = ROUTE_PONDED
    else
      current_runoff = oracle_runoff_depth(x%candidate_ponding_depth_cm, x)
      if (abs(current_runoff) < RUNOFF_ZERO_CM) then
        y%pond = h0max
        y%runoff = current_runoff
        y%route_class = ROUTE_PONDED
      else
        if (x%runoff_resistance_day < MIN_RSRO_DAY .or. x%runoff_exponent /= 1.0_real64) then
          y%status = B110_DYN_TOP_UNSUPPORTED
          success = .true.
          return
        end if
        p2 = 1.0_real64/(p1 + 1.0_real64 + x%step_duration_day/x%runoff_resistance_day)
        y%pond = p2*(x%previous_ponding_depth_cm + y%q0*x%step_duration_day - &
             k1_max*x%step_duration_day + p1*x%pressure_head_top_cm + &
             x%step_duration_day/x%runoff_resistance_day*x%ponding_max_cm)
        y%runoff = oracle_runoff_depth(y%pond, x)
        y%route_class = ROUTE_RUNOFF
      end if
    end if

    y%surface_head = y%pond
    y%actual_top_flux = -k1_max*((y%surface_head-x%pressure_head_top_cm)/top_distance + 1.0_real64)
    y%status = B110_DYN_TOP_AVAILABLE
    success = .true.
  end subroutine legacy_restricted_oracle

  subroutine oracle_hcomean(method, kup, klow, dzup, dzlow, kmean, success)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow
    real(real64), intent(out) :: kmean
    logical, intent(out) :: success
    real(real64) :: a1, a2, denom
    success = .false.
    kmean = 0.0_real64
    denom = dzup + dzlow
    if (denom <= 0.0_real64) return
    a1 = dzup/denom
    a2 = 1.0_real64-a1
    select case(method)
    case(1)
      kmean = 0.5_real64*(kup+klow)
    case(2)
      kmean = (dzup*kup+dzlow*klow)/denom
    case(3)
      kmean = sqrt(kup*klow)
    case(4)
      kmean = kup**a1*klow**a2
    case(5)
      if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
      kmean = 1.0_real64/(0.5_real64/kup+0.5_real64/klow)
    case(6)
      if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
      kmean = 1.0_real64/(a1/kup+a2/klow)
    case default
      return
    end select
    success = .true.
  end subroutine oracle_hcomean

  real(real64) function oracle_runoff_depth(pond, x) result(runoff)
    real(real64), intent(in) :: pond
    type(b110_dynamic_top_boundary_request_t), intent(in) :: x
    runoff = 0.0_real64
    if (pond <= x%ponding_max_cm) return
    if (x%runoff_resistance_day < MIN_RSRO_DAY) then
      runoff = pond-x%ponding_max_cm
    else
      runoff = x%step_duration_day/x%runoff_resistance_day * &
           (pond-x%ponding_max_cm)**x%runoff_exponent
    end if
  end function oracle_runoff_depth

  subroutine compare_result(a, b, base_code)
    type(b110_dynamic_top_boundary_result_t), intent(in) :: a
    type(oracle_result_t), intent(in) :: b
    integer, intent(in) :: base_code
    call require(a%status == b%status, base_code+0)
    call require(a%regime == b%regime, base_code+1)
    call require_close(a%actual_top_flux_cm_per_day, b%actual_top_flux, base_code+2)
    call require_close(a%surface_head_cm, b%surface_head, base_code+3)
    call require_close(a%surface_face_conductivity_cm_per_day, b%surface_face_k, base_code+4)
    call require_close(a%candidate_ponding_depth_cm, b%pond, base_code+5)
    call require_close(a%bare_soil_evaporation_cm_per_day, b%bare_evap, base_code+6)
    call require_close(a%ponded_water_evaporation_cm_per_day, b%pond_evap, base_code+7)
    call require_close(a%runoff_depth_cm, b%runoff, base_code+8)
    call require_close(a%net_potential_surface_flux_cm_per_day, b%q0, base_code+9)
    call require_close(a%evaporation_capacity_cm_per_day, b%emax, base_code+10)
    call require(a%runoff_potential .eqv. b%runoff_potential, base_code+11)
    select case (b%route_class)
    case (ROUTE_ATMOSPHERIC)
      call require(trim(a%route) == 'atmospheric-head', base_code+12)
    case (ROUTE_FLUX)
      call require(trim(a%route) == 'surface-flux', base_code+13)
    case (ROUTE_PONDED)
      call require(trim(a%route) == 'ponded-head', base_code+14)
    case (ROUTE_RUNOFF)
      call require(trim(a%route) == 'ponded-head-linear-runoff', base_code+15)
    end select
  end subroutine compare_result

  subroutine set_evaporation_case(x, idx)
    type(b110_dynamic_top_boundary_request_t), intent(inout) :: x
    integer, intent(in) :: idx
    select case(idx)
    case(1)
      x%potential_bare_soil_evaporation_cm_per_day = 0.0_real64
      x%potential_pond_evaporation_cm_per_day = 0.0_real64
    case(2)
      x%potential_bare_soil_evaporation_cm_per_day = 0.30_real64
      x%potential_pond_evaporation_cm_per_day = 0.40_real64
    case(3)
      x%potential_bare_soil_evaporation_cm_per_day = 5.0_real64
      x%potential_pond_evaporation_cm_per_day = 5.0_real64
    end select
  end subroutine set_evaporation_case

  subroutine set_supply_case(x, idx)
    type(b110_dynamic_top_boundary_request_t), intent(inout) :: x
    integer, intent(in) :: idx
    x%precipitation_rate_cm_per_day = 0.0_real64
    x%irrigation_rate_cm_per_day = 0.0_real64
    x%snowmelt_rate_cm_per_day = 0.0_real64
    x%runon_rate_cm_per_day = 0.0_real64
    select case(idx)
    case(1)
    case(2)
      x%precipitation_rate_cm_per_day = 0.10_real64
    case(3)
      x%irrigation_rate_cm_per_day = 0.20_real64
    case(4)
      x%snowmelt_rate_cm_per_day = 0.30_real64
    case(5)
      x%runon_rate_cm_per_day = 0.40_real64
    case(6)
      x%precipitation_rate_cm_per_day = 0.10_real64
      x%irrigation_rate_cm_per_day = 0.20_real64
      x%snowmelt_rate_cm_per_day = 0.30_real64
      x%runon_rate_cm_per_day = 0.40_real64
    case(7)
      x%precipitation_rate_cm_per_day = 20.0_real64
    end select
  end subroutine set_supply_case

  subroutine initialize_request(x, method)
    type(b110_dynamic_top_boundary_request_t), intent(out) :: x
    integer, intent(in) :: method
    x = b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method = method
    x%pressure_head_top_cm = -100.0_real64
    x%water_content_top = 0.20_real64
    x%candidate_ponding_depth_cm = 0.0_real64
    x%previous_ponding_depth_cm = 0.0_real64
    x%step_duration_day = 0.10_real64
    x%potential_bare_soil_evaporation_cm_per_day = 0.30_real64
    x%potential_pond_evaporation_cm_per_day = 0.40_real64
    x%ponding_max_cm = 2.0_real64
    x%runoff_resistance_day = 0.5_real64
    x%runoff_exponent = 1.0_real64
  end subroutine initialize_request

  subroutine configure_family(c, p)
    real(real64), intent(out) :: c(24,nnode)
    type(soil_water_parameter_set_t), intent(out) :: p
    integer :: j
    p%active_nodes = nnode
    allocate(p%z(nnode), p%dz(nnode), p%node_distance(nnode))
    p%z = [-2.5_real64, -11.0_real64]
    p%dz = [5.0_real64, 12.0_real64]
    p%node_distance = [2.75_real64, 8.5_real64]
    c = 0.0_real64
    do j = 1, nnode
      c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
      c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=0.0_real64
      c(10,j)=c(3,j); c(11,j)=0.999_real64; c(12,j)=0.99_real64*c(3,j)
      c(13,j)=0.10_real64; c(14,j)=1.50_real64; c(15,j)=0.50_real64
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine configure_family

  real(real64) function surface_mass_residual(x, y) result(residual)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: x
    type(b110_dynamic_top_boundary_result_t), intent(in) :: y
    real(real64) :: supply
    supply = x%precipitation_rate_cm_per_day + x%irrigation_rate_cm_per_day + &
             x%snowmelt_rate_cm_per_day + x%runon_rate_cm_per_day
    residual = y%candidate_ponding_depth_cm - x%previous_ponding_depth_cm + &
         (y%bare_soil_evaporation_cm_per_day + y%ponded_water_evaporation_cm_per_day)*x%step_duration_day - &
         supply*x%step_duration_day + y%runoff_depth_cm - y%actual_top_flux_cm_per_day*x%step_duration_day
  end function surface_mass_residual

  logical function same_request(a, b) result(same)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: a, b
    same = a%conductivity_mean_method == b%conductivity_mean_method .and. &
      a%pressure_head_top_cm == b%pressure_head_top_cm .and. a%water_content_top == b%water_content_top .and. &
      a%candidate_ponding_depth_cm == b%candidate_ponding_depth_cm .and. &
      a%previous_ponding_depth_cm == b%previous_ponding_depth_cm .and. &
      a%step_duration_day == b%step_duration_day .and. &
      a%precipitation_rate_cm_per_day == b%precipitation_rate_cm_per_day .and. &
      a%irrigation_rate_cm_per_day == b%irrigation_rate_cm_per_day .and. &
      a%snowmelt_rate_cm_per_day == b%snowmelt_rate_cm_per_day .and. &
      a%runon_rate_cm_per_day == b%runon_rate_cm_per_day .and. &
      a%potential_bare_soil_evaporation_cm_per_day == b%potential_bare_soil_evaporation_cm_per_day .and. &
      a%potential_pond_evaporation_cm_per_day == b%potential_pond_evaporation_cm_per_day .and. &
      a%ponding_max_cm == b%ponding_max_cm .and. &
      a%runoff_resistance_day == b%runoff_resistance_day .and. a%runoff_exponent == b%runoff_exponent
  end function same_request

  logical function same_candidate_result(a, b) result(same)
    type(b110_dynamic_top_boundary_result_t), intent(in) :: a, b
    same = a%status == b%status .and. a%regime == b%regime .and. &
      a%actual_top_flux_cm_per_day == b%actual_top_flux_cm_per_day .and. &
      a%surface_head_cm == b%surface_head_cm .and. &
      a%surface_face_conductivity_cm_per_day == b%surface_face_conductivity_cm_per_day .and. &
      a%candidate_ponding_depth_cm == b%candidate_ponding_depth_cm .and. &
      a%bare_soil_evaporation_cm_per_day == b%bare_soil_evaporation_cm_per_day .and. &
      a%ponded_water_evaporation_cm_per_day == b%ponded_water_evaporation_cm_per_day .and. &
      a%runoff_depth_cm == b%runoff_depth_cm .and. &
      a%net_potential_surface_flux_cm_per_day == b%net_potential_surface_flux_cm_per_day .and. &
      a%evaporation_capacity_cm_per_day == b%evaporation_capacity_cm_per_day .and. &
      a%runoff_potential .eqv. b%runoff_potential .and. a%route == b%route
  end function same_candidate_result

  subroutine require_close(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    real(real64) :: scale, tolerance
    scale = max(1.0_real64, abs(actual), abs(expected))
    tolerance = 16384.0_real64*epsilon(1.0_real64)*scale
    if (abs(actual-expected) > tolerance) then
      write(error_unit,'(A,I0)') 'FSI29_ORACLE_FAIL_CODE=', code
      write(error_unit,'(A,ES24.16)') 'FSI29_ORACLE_ACTUAL=', actual
      write(error_unit,'(A,ES24.16)') 'FSI29_ORACLE_EXPECTED=', expected
      write(error_unit,'(A,ES24.16)') 'FSI29_ORACLE_TOLERANCE=', tolerance
      error stop 1
    end if
  end subroutine require_close

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(error_unit,'(A,I0)') 'FSI29_ORACLE_FAIL_CODE=', code
      error stop 1
    end if
  end subroutine require

end program test_fsi29_legacy_boundtop_oracle
