program test_fvq52_surface_evaporation_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf, ieee_negative_inf
  use mod_restricted_surface_evaporation, only: &
       surface_evaporation_demand_t, surface_evaporation_hydraulic_input_t, surface_evaporation_result_t, &
       SURFACE_EVAP_AVAILABLE, SURFACE_EVAP_INVALID_INPUT, evaluate_restricted_surface_evaporation
  implicit none

  real(real64), parameter :: peva_values(8) = [ &
       0.0_real64, 1.0e-12_real64, 1.0e-8_real64, 1.0e-5_real64, &
       1.0e-3_real64, 5.0e-2_real64, 1.0_real64, 100.0_real64 ]
  real(real64), parameter :: epond_values(7) = [ &
       0.0_real64, 1.0e-12_real64, 1.0e-7_real64, 1.0e-4_real64, &
       1.0e-2_real64, 1.0_real64, 100.0_real64 ]
  real(real64), parameter :: capacity_values(9) = [ &
       -100.0_real64, -1.0e-6_real64, -0.0_real64, 0.0_real64, &
       1.0e-12_real64, 1.0e-5_real64, 2.0e-2_real64, 1.0_real64, 1000.0_real64 ]

  type(surface_evaporation_demand_t) :: demand, demand_a, demand_b
  type(surface_evaporation_hydraulic_input_t) :: hydraulic, hydraulic_a, hydraulic_b
  type(surface_evaporation_result_t) :: result, a1, b, a2
  real(real64) :: expected_reva, expected_epd
  real(real64) :: nanv, pinf, ninf
  integer :: i, j, k, ipond, active_cases

  active_cases = 0

  do ipond = 0, 1
    do i = 1, size(peva_values)
      do j = 1, size(epond_values)
        do k = 1, size(capacity_values)
          demand%bare_soil_demand = peva_values(i)
          demand%ponded_water_demand = epond_values(j)
          hydraulic%surface_is_ponded = (ipond == 1)
          hydraulic%evaporation_capacity = capacity_values(k)

          call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
          call require(result%status == SURFACE_EVAP_AVAILABLE)

          if (hydraulic%surface_is_ponded) then
            expected_reva = 0.0_real64
            expected_epd = demand%ponded_water_demand
            call require(result%route == 'ponded')
          else
            if (hydraulic%evaporation_capacity > 0.0_real64) then
              expected_reva = min(demand%bare_soil_demand, hydraulic%evaporation_capacity)
            else
              expected_reva = 0.0_real64
            end if
            expected_epd = 0.0_real64
            call require(result%route == 'dry')
          end if

          call require_same_real(result%bare_soil_evaporation, expected_reva)
          call require_same_real(result%ponded_water_evaporation, expected_epd)
          call require(result%bare_soil_evaporation >= 0.0_real64)
          call require(result%ponded_water_evaporation >= 0.0_real64)
          if (hydraulic%surface_is_ponded) then
            call require_same_real(result%bare_soil_evaporation, 0.0_real64)
          else
            call require_same_real(result%ponded_water_evaporation, 0.0_real64)
          end if

          active_cases = active_cases + 1
        end do
      end do
    end do
  end do

  call require(active_cases == 1008)

  ! Negative atmospheric demands are invalid; a negative finite hydraulic capacity is not.
  demand = surface_evaporation_demand_t(0.1_real64, 0.2_real64)
  hydraulic = surface_evaporation_hydraulic_input_t(.false., -5.0_real64)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require(result%status == SURFACE_EVAP_AVAILABLE)
  call require_same_real(result%bare_soil_evaporation, 0.0_real64)

  demand = surface_evaporation_demand_t(-1.0_real64, 0.2_real64)
  hydraulic = surface_evaporation_hydraulic_input_t(.false., 1.0_real64)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  demand = surface_evaporation_demand_t(0.1_real64, -0.2_real64)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)
  pinf = ieee_value(0.0_real64, ieee_positive_inf)
  ninf = ieee_value(0.0_real64, ieee_negative_inf)

  demand = surface_evaporation_demand_t(nanv, 0.2_real64)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  demand = surface_evaporation_demand_t(0.1_real64, nanv)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  demand = surface_evaporation_demand_t(pinf, 0.2_real64)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  demand = surface_evaporation_demand_t(0.1_real64, pinf)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  demand = surface_evaporation_demand_t(0.1_real64, 0.2_real64)
  hydraulic = surface_evaporation_hydraulic_input_t(.false., nanv)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  hydraulic = surface_evaporation_hydraulic_input_t(.false., pinf)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  hydraulic = surface_evaporation_hydraulic_input_t(.true., ninf)
  call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
  call require_invalid_zero(result)

  ! Stateless A-B-A replay across different regimes and demands.
  demand_a = surface_evaporation_demand_t(0.37_real64, 0.91_real64)
  hydraulic_a = surface_evaporation_hydraulic_input_t(.false., 0.12_real64)
  demand_b = surface_evaporation_demand_t(0.04_real64, 1.7_real64)
  hydraulic_b = surface_evaporation_hydraulic_input_t(.true., -3.0_real64)

  call evaluate_restricted_surface_evaporation(demand_a, hydraulic_a, a1)
  call evaluate_restricted_surface_evaporation(demand_b, hydraulic_b, b)
  call evaluate_restricted_surface_evaporation(demand_a, hydraulic_a, a2)

  call require(a1%status == SURFACE_EVAP_AVAILABLE)
  call require(b%status == SURFACE_EVAP_AVAILABLE)
  call require(a2%status == a1%status)
  call require(a2%route == a1%route)
  call require_same_real(a2%bare_soil_evaporation, a1%bare_soil_evaporation)
  call require_same_real(a2%ponded_water_evaporation, a1%ponded_water_evaporation)

  write(*,'(A,I0)') 'FVQ52_ACTIVE_CASES=', active_cases
  write(*,'(A)') 'FVQ52_B110_DRY_ORACLE=PASS'
  write(*,'(A)') 'FVQ52_B110_PONDED_ORACLE=PASS'
  write(*,'(A)') 'FVQ52_NEGATIVE_CAPACITY_CLAMP=PASS'
  write(*,'(A)') 'FVQ52_FAIL_CLOSED_INVALID_INPUT=PASS'
  write(*,'(A)') 'FVQ52_STATELESS_ABA=PASS'
  write(*,'(A)') 'FVQ52_INDEPENDENT_ORACLE=PASS'

contains

  subroutine require(condition)
    logical, intent(in) :: condition
    if (.not. condition) error stop 52
  end subroutine require

  subroutine require_same_real(actual, expected)
    real(real64), intent(in) :: actual, expected
    if (abs(actual - expected) > 0.0_real64) error stop 52
  end subroutine require_same_real

  subroutine require_invalid_zero(value)
    type(surface_evaporation_result_t), intent(in) :: value
    call require(value%status == SURFACE_EVAP_INVALID_INPUT)
    call require(value%route == 'invalid-input')
    call require_same_real(value%bare_soil_evaporation, 0.0_real64)
    call require_same_real(value%ponded_water_evaporation, 0.0_real64)
  end subroutine require_invalid_zero

end program test_fvq52_surface_evaporation_independent
