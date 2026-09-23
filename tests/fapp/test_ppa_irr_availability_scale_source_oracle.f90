program test_ppa_irr_availability_scale_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_availability_scale, only: scale_surface_irrigation_availability
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: rate, duration, irrigation_rate, availability, scaled_rate, scaled_duration
  real(real64) :: expected_rate, expected_duration, unit_value
  integer(int64) :: random_state
  integer :: i

  call check_case(2.0_real64, 0.25_real64, nearest(0.0_real64, 1.0_real64), 0.5_real64, 1)
  call check_case(2.0_real64, 0.25_real64, 0.0_real64, 0.5_real64, 2)
  call check_case(2.0_real64, 0.25_real64, nearest(0.0_real64, -1.0_real64), 0.5_real64, 3)

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, unit_value)
    rate = 10.0_real64*unit_value
    call random_unit(random_state, unit_value)
    duration = unit_value
    select case (modulo(i, 3))
    case (0)
      irrigation_rate = 0.0_real64
    case (1)
      irrigation_rate = 10.0_real64*unit_value
    case (2)
      irrigation_rate = -10.0_real64*unit_value
    end select
    call random_unit(random_state, availability)
    call check_case(rate, duration, irrigation_rate, availability, 10)
  end do

  print '(A)', 'PPA_IRR_AVAILABILITY_SCALING_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_AVAILABILITY_POSITIVE_RATE_BRANCH=PASS'
  print '(A)', 'PPA_IRR_AVAILABILITY_NONPOSITIVE_RATE_DURATION_IDENTITY=PASS'
  print '(A)', 'PPA_IRR_AVAILABILITY_SCALE_SOURCE_ORACLE=PASS'

contains

  subroutine check_case(input_rate, input_duration, selected_irrigation_rate, fraction, code)
    real(real64), intent(in) :: input_rate, input_duration, selected_irrigation_rate, fraction
    integer, intent(in) :: code

    expected_rate = input_rate*fraction
    expected_duration = input_duration
    if (selected_irrigation_rate > 0.0_real64) expected_duration = expected_duration*fraction
    call scale_surface_irrigation_availability(input_rate, input_duration, selected_irrigation_rate, fraction, &
                                               scaled_rate, scaled_duration)
    call require(transfer(scaled_rate, 0_int64) == transfer(expected_rate, 0_int64), code)
    call require(transfer(scaled_duration, 0_int64) == transfer(expected_duration, 0_int64), code+100)
  end subroutine check_case

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_AVAILABILITY_SCALE_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_availability_scale_source_oracle
