program test_ppa_irr_interception_solute_mass
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  use mod_vonhhbraden_interception
  use mod_ppa_irr_surface_solute_mass
  implicit none

  integer, parameter :: vector_count = 100000
  type(vonhhbraden_source_window_t) :: source
  real(real64) :: aggregate, rain_rate, irrigation_rate, concentration, interval_days
  real(real64) :: interception, net_rain, net_irrigation, expected_net_irrigation
  real(real64) :: source_mass, expected_mass, interval_rate, source_rate, unit_value, tolerance
  real(real64) :: rain_concentration, previous_surface_amount, accumulated_surface_amount
  real(real64) :: expected_surface_amount
  integer(int64) :: random_state
  integer :: i, status

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, unit_value)
    source%gross_rain_cm_per_day = 4.0_real64*unit_value
    rain_rate = source%gross_rain_cm_per_day
    call random_unit(random_state, unit_value)
    source%sprinkling_irrigation_cm_per_day = 4.0_real64*unit_value
    irrigation_rate = source%sprinkling_irrigation_cm_per_day
    source%sprinkling_is_intercepted = modulo(i,2) == 0
    source_rate = rain_rate
    if (source%sprinkling_is_intercepted) source_rate = source_rate+irrigation_rate
    call random_unit(random_state, unit_value)
    aggregate = 0.25_real64*source_rate*unit_value
    call random_unit(random_state, unit_value)
    concentration = 100.0_real64*unit_value
    call random_unit(random_state, unit_value)
    interval_days = unit_value
    call random_unit(random_state, unit_value)
    rain_concentration = 100.0_real64*unit_value
    call random_unit(random_state, unit_value)
    previous_surface_amount = 10.0_real64*unit_value

    call apportion_vonhhbraden_interception(source, aggregate, rain_rate, irrigation_rate, &
      interception, net_rain, net_irrigation, status)
    call require(status == VONHHBRADEN_AVAILABLE, 1)
    interval_rate = rain_rate
    if (source%sprinkling_is_intercepted) interval_rate = interval_rate+irrigation_rate
    expected_net_irrigation = irrigation_rate
    if (interception >= 1.0e-5_real64 .and. source%sprinkling_is_intercepted .and. &
        interval_rate > 1.0e-5_real64 .and. source_rate > 0.0_real64) then
      expected_net_irrigation = irrigation_rate-interception*irrigation_rate/interval_rate
    end if
    tolerance = 64.0_real64*epsilon(expected_net_irrigation)*max(1.0_real64,abs(expected_net_irrigation))
    call require(abs(net_irrigation-expected_net_irrigation) <= tolerance, 2)

    expected_mass = expected_net_irrigation*concentration*interval_days
    call calculate_surface_irrigation_solute_mass(net_irrigation, concentration, interval_days, &
      source_mass, status)
    call require(status == IRR_SURFACE_SOLUTE_OK, 3)
    tolerance = 64.0_real64*epsilon(expected_mass)*max(1.0_real64,abs(expected_mass))
    call require(abs(source_mass-expected_mass) <= tolerance, 4)

    expected_surface_amount = previous_surface_amount + &
         (net_irrigation*concentration+net_rain*rain_concentration)*interval_days
    call accumulate_surface_solute_amount(net_irrigation,concentration,net_rain,rain_concentration, &
         interval_days,previous_surface_amount,accumulated_surface_amount,status)
    call require(status==IRR_SURFACE_SOLUTE_OK,5)
    tolerance = 64.0_real64*epsilon(expected_surface_amount)*max(1.0_real64,abs(expected_surface_amount))
    call require(abs(accumulated_surface_amount-expected_surface_amount)<=tolerance,6)
  end do

  call check_invalid(-1.0_real64, 1.0_real64, 1.0_real64, 10)
  call check_invalid(1.0_real64, 100.000001_real64, 1.0_real64, 11)
  call check_invalid(1.0_real64, 1.0_real64, -1.0_real64, 12)
  call check_invalid(huge(1.0_real64), 100.0_real64, 1.0_real64, 13)
  call check_invalid(huge(1.0_real64), 1.0_real64, huge(1.0_real64), 14)
  call check_invalid(1.0_real64, ieee_value(0.0_real64,ieee_quiet_nan), 1.0_real64, 15)
  call check_invalid(1.0_real64, 1.0_real64, ieee_value(0.0_real64,ieee_positive_inf), 16)
  call accumulate_surface_solute_amount(huge(1.0_real64),100.0_real64,0.0_real64,0.0_real64, &
       1.0_real64,0.0_real64,accumulated_surface_amount,status)
  call require(status==IRR_SURFACE_SOLUTE_INVALID_INPUT,17)
  call accumulate_surface_solute_amount(1.0_real64,1.0_real64,1.0_real64,1.0_real64, &
       huge(1.0_real64),huge(1.0_real64),accumulated_surface_amount,status)
  call require(status==IRR_SURFACE_SOLUTE_INVALID_INPUT,18)
  print '(A)', 'PPA_IRR_INTERCEPTION_TO_SURFACE_SOLUTE_MASS_100000=PASS'
  print '(A)', 'PPA_IRR_SURFACE_SOLUTE_AMOUNT_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_IRR_SURFACE_RAIN_AND_IRRIGATION_STORAGE_100000=PASS'
  print '(A)', 'PPA_IRR_SURFACE_SOLUTE_INVALID_INPUT_FAIL_CLOSED=PASS'

contains

  subroutine random_unit(state, result)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: result
    state = modulo(state*48271_int64, 2147483647_int64)
    result = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine check_invalid(rate, concentration_value, duration, code)
    real(real64), intent(in) :: rate, concentration_value, duration
    integer, intent(in) :: code
    call calculate_surface_irrigation_solute_mass(rate, concentration_value, duration, source_mass, status)
    call require(status == IRR_SURFACE_SOLUTE_INVALID_INPUT .and. &
      source_mass <= 0.0_real64, code)
  end subroutine check_invalid

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'PPA_IRR_INTERCEPTION_SOLUTE_MASS_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_interception_solute_mass
