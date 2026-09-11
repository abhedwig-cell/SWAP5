program test_fsi29_dynamic_top_boundary_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_result_t, &
       SURFACE_EVAP_CAPACITY_AVAILABLE
  use mod_b110_surface_evaporation_capacity_provider, only: b110_surface_evaporation_capacity_provider_t, &
       bind_b110_surface_evaporation_capacity_provider
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_UNSUPPORTED, &
       B110_DYN_TOP_REGIME_FLUX, B110_DYN_TOP_REGIME_HEAD
  implicit none

  integer, parameter :: nnode = 2
  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: hydraulics
  type(b110_surface_evaporation_capacity_provider_t) :: capacity_provider
  type(soil_water_physical_state_t) :: state
  type(surface_evaporation_capacity_result_t) :: capacity
  type(b110_dynamic_top_boundary_request_t) :: req, req_before
  type(b110_dynamic_top_boundary_result_t) :: r, r2, a1, b, a2
  real(real64) :: raw(24,nnode)
  real(real64) :: supplies(8), pond_demands(6), mass_residual, worst_mass
  logical :: ok, found_flux, found_ponded, found_atmospheric, found_runoff
  integer :: method, i, cases

  supplies = [0.0_real64, 0.01_real64, 0.1_real64, 0.5_real64, &
              1.0_real64, 5.0_real64, 20.0_real64, 100.0_real64]
  pond_demands = [0.01_real64, 0.1_real64, 0.5_real64, 1.0_real64, 5.0_real64, 20.0_real64]
  worst_mass = 0.0_real64
  cases = 0

  call configure_family(raw, geometry)
  call initialize_b110_default_mvg_parameters(hydraulics, raw)

  state%active_nodes = nnode
  allocate(state%pressure_head(nnode), state%water_content(nnode))
  state%pressure_head = [-100.0_real64, -250.0_real64]
  state%water_content = [0.20_real64, 0.24_real64]
  state%ponding_depth = 0.0_real64
  state%groundwater_level = -180.0_real64

  do method = 1, 6
    call initialize_request(req, method)

    ! The dynamic evaluator must reuse the already-qualified F-PM06E Emax physics exactly.
    call bind_b110_surface_evaporation_capacity_provider(capacity_provider, geometry, hydraulics, &
         method, .false., .false., ok)
    call require(ok, 2901)
    call capacity_provider%evaluate(state, capacity)
    call require(capacity%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 2902)
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, r)
    call require(r%status == B110_DYN_TOP_AVAILABLE, 2903)
    call require_close(r%evaporation_capacity_cm_per_day, capacity%evaporation_capacity, 2904)

    found_flux = .false.
    found_ponded = .false.
    do i = 1, size(supplies)
      call initialize_request(req, method)
      req%precipitation_rate_cm_per_day = supplies(i)
      req%ponding_max_cm = 1000.0_real64
      req_before = req
      call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, r)
      call require(same_request(req, req_before), 2905)
      call require(r%status == B110_DYN_TOP_AVAILABLE, 2906)
      cases = cases + 1
      if (r%regime == B110_DYN_TOP_REGIME_FLUX) then
        found_flux = .true.
        mass_residual = surface_mass_residual(req, r)
        worst_mass = max(worst_mass, abs(mass_residual))
        call require(abs(mass_residual) <= 1.0e-12_real64, 2907)
      else if (r%regime == B110_DYN_TOP_REGIME_HEAD .and. r%surface_head_cm >= 0.0_real64) then
        found_ponded = .true.
        mass_residual = surface_mass_residual(req, r)
        worst_mass = max(worst_mass, abs(mass_residual))
        call require(abs(mass_residual) <= 1.0e-12_real64, 2908)
      end if
    end do
    call require(found_flux, 2909)
    call require(found_ponded, 2910)

    ! Atmospheric-head switching is a distinct head regime and must not be collapsed to fixed qtop.
    found_atmospheric = .false.
    do i = 1, size(pond_demands)
      call initialize_request(req, method)
      req%previous_ponding_depth_cm = 1.0e-8_real64
      req%potential_pond_evaporation_cm_per_day = pond_demands(i)
      req%potential_bare_soil_evaporation_cm_per_day = 0.0_real64
      req%ponding_max_cm = 1000.0_real64
      call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, r)
      call require(r%status == B110_DYN_TOP_AVAILABLE, 2911)
      cases = cases + 1
      if (r%regime == B110_DYN_TOP_REGIME_HEAD .and. r%surface_head_cm < 0.0_real64) then
        found_atmospheric = .true.
        exit
      end if
    end do
    call require(found_atmospheric, 2912)

    ! Active linear runoff needs the same trial-local pond carry used by legacy pondrunoff.
    found_runoff = .false.
    do i = 4, size(supplies)
      call initialize_request(req, method)
      req%precipitation_rate_cm_per_day = supplies(i)
      req%ponding_max_cm = 0.01_real64
      req%runoff_resistance_day = 0.5_real64
      req%runoff_exponent = 1.0_real64
      call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, r)
      if (r%status /= B110_DYN_TOP_AVAILABLE) cycle
      if (r%regime /= B110_DYN_TOP_REGIME_HEAD .or. r%surface_head_cm < 0.0_real64) cycle
      req%candidate_ponding_depth_cm = r%candidate_ponding_depth_cm
      call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, r2)
      call require(r2%status == B110_DYN_TOP_AVAILABLE, 2913)
      if (r2%runoff_depth_cm > 0.0_real64) then
        found_runoff = .true.
        mass_residual = surface_mass_residual(req, r2)
        worst_mass = max(worst_mass, abs(mass_residual))
        call require(abs(mass_residual) <= 1.0e-12_real64, 2914)
        exit
      end if
    end do
    call require(found_runoff, 2915)

    ! Nonlinear active runoff is deliberately outside the first restricted profile.
    req%candidate_ponding_depth_cm = max(req%ponding_max_cm + 0.1_real64, r2%candidate_ponding_depth_cm)
    req%runoff_exponent = 2.0_real64
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, r)
    call require(r%status == B110_DYN_TOP_UNSUPPORTED, 2916)

    ! A-B-A replay: no hidden provider state may evolve across calls.
    call initialize_request(req, method)
    req%precipitation_rate_cm_per_day = 0.5_real64
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, a1)
    req%precipitation_rate_cm_per_day = 20.0_real64
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, b)
    req%precipitation_rate_cm_per_day = 0.5_real64
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, req, a2)
    call require(same_result(a1, a2), 2917)
    call require(b%status == B110_DYN_TOP_AVAILABLE, 2918)
  end do

  write(*,'(A,I0)') 'FSI29_CASES=', cases
  write(*,'(A,ES24.16)') 'FSI29_WORST_SURFACE_MASS_RESIDUAL_CM=', worst_mass
  write(*,'(A)') 'FSI29_FPM06E_EMAX_REUSE=PASS'
  write(*,'(A)') 'FSI29_FLUX_AND_HEAD_REGIMES=PASS'
  write(*,'(A)') 'FSI29_ATMOSPHERIC_HEAD_SWITCH=PASS'
  write(*,'(A)') 'FSI29_PONDING_LINEAR_RUNOFF=PASS'
  write(*,'(A)') 'FSI29_UNSUPPORTED_RUNOFF_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FSI29_INPUT_NONMUTATION_AND_ABA=PASS'
  write(*,'(A)') 'FSI29_COMPONENT_GATE=PASS'

contains

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

  logical function same_result(a, b) result(same)
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
  end function same_result

  subroutine require_close(actual, expected, code)
    real(real64), intent(in) :: actual, expected
    integer, intent(in) :: code
    real(real64) :: scale
    scale = max(1.0_real64, abs(actual), abs(expected))
    if (abs(actual-expected) > 4096.0_real64*epsilon(1.0_real64)*scale) then
      write(*,'(A,I0)') 'FSI29_TEST_FAIL_CODE=', code
      error stop 1
    end if
  end subroutine require_close

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'FSI29_TEST_FAIL_CODE=', code
      error stop 1
    end if
  end subroutine require

end program test_fsi29_dynamic_top_boundary_provider
