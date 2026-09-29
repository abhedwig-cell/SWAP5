program test_ppa_irr_fixed_input_normalization_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_fixed_input_normalization, only: normalize_fixed_irrigation_input
  implicit none

  integer, parameter :: vector_count = 100000
  integer :: i, application_type, ssdi_nodes
  integer(int64) :: random_state
  logical :: has_rate
  real(real64) :: depth_mm, rate_mm_per_hour, target_duration, unit_value
  real(real64) :: actual_depth_cm, actual_rate_cm_day, actual_duration
  real(real64) :: expected_depth_cm, expected_rate_cm_day, expected_duration
  real(real64) :: source_depth_mm, source_rate_mm_per_hour

  random_state = 20260923_int64
  do i = 1, vector_count
    application_type = modulo(i-1, 3)
    ssdi_nodes = 1+modulo(i, 5)
    call random_unit(random_state, unit_value)
    depth_mm = 0.01_real64+29.99_real64*unit_value
    has_rate = modulo(i, 2) == 0
    if (has_rate) then
      call random_unit(random_state, unit_value)
      target_duration = 0.05_real64+0.94_real64*unit_value
      rate_mm_per_hour = depth_mm/(24.0_real64*target_duration)
      if (application_type == 2) rate_mm_per_hour = rate_mm_per_hour/real(ssdi_nodes, real64)
    else
      rate_mm_per_hour = 0.0_real64
    end if

    source_depth_mm = depth_mm
    if (has_rate) then
      source_rate_mm_per_hour = rate_mm_per_hour
    else
      source_rate_mm_per_hour = depth_mm/24.0_real64
    end if
    if (application_type == 2) source_depth_mm = source_depth_mm/real(ssdi_nodes, real64)
    expected_depth_cm = 0.1_real64*source_depth_mm
    expected_rate_cm_day = 0.1_real64*24.0_real64*source_rate_mm_per_hour
    expected_duration = expected_depth_cm/expected_rate_cm_day

    call normalize_fixed_irrigation_input(depth_mm, rate_mm_per_hour, has_rate, application_type, ssdi_nodes, &
                                          actual_depth_cm, actual_rate_cm_day, actual_duration)
    call require(transfer(actual_depth_cm, 0_int64) == transfer(expected_depth_cm, 0_int64), 1)
    call require(transfer(actual_rate_cm_day, 0_int64) == transfer(expected_rate_cm_day, 0_int64), 2)
    call require(transfer(actual_duration, 0_int64) == transfer(expected_duration, 0_int64), 3)
    call require(actual_duration > 0.0_real64 .and. actual_duration <= 1.0_real64, 4)
  end do

  print '(A)', 'PPA_IRR_FIXED_INPUT_NORMALIZATION_100000=PASS'
  print '(A)', 'PPA_IRR_LEGACY_RATE_FALLBACK_BEFORE_SSDI_SPLIT=PASS'
  print '(A)', 'PPA_IRR_SSDI_PER_NODE_DEPTH_AND_CM_PER_DAY_UNITS=PASS'
  print '(A)', 'PPA_IRR_FIXED_INPUT_NORMALIZATION_SOURCE_ORACLE=PASS'

contains

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
      write(*, '(A,I0)') 'PPA_IRR_FIXED_INPUT_NORMALIZATION_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_fixed_input_normalization_source_oracle
