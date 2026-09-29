program test_ppa_irr_dcs1_depth_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_dcs1_depth
  implicit none

  integer, parameter :: vector_count = 100000
  real(real64) :: knots(IRR_DCS1_MAX_KNOTS), corrections(IRR_DCS1_MAX_KNOTS)
  real(real64) :: table(14), dvs, cdef, rain, rain_threshold, min_mm, max_mm
  real(real64) :: concentration, concentration_threshold, over_percent, depth, correction, expected_depth
  real(real64) :: expected_correction
  integer :: i, status
  integer(int64) :: random_state
  logical :: limit_enabled, solute_enabled

  knots = [0.0_real64, 0.5_real64, 1.0_real64, 1.5_real64, 1.75_real64, 1.9_real64, 2.0_real64]
  corrections = [0.0_real64, 10.0_real64, 20.0_real64, -10.0_real64, 5.0_real64, 0.0_real64, -5.0_real64]

  ! Rain suppression is strict: equality leaves the base depth unchanged.
  call run_case(0.5_real64, 1.0_real64, 1.0_real64, .false., 0.0_real64, 1000.0_real64, &
                .false., 0.0_real64, 0.0_real64, 0.0_real64, 2.0_real64, 1)
  call run_case(0.5_real64, 0.0_real64, nearest(1.0_real64, 1.0_real64), .false., 0.0_real64, 1000.0_real64, &
                .false., 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 2)

  ! Source order: DCS1 nonnegative amount, optional min/max, then solute bump.
  call run_case(0.5_real64, 0.0_real64, 2.0_real64, .true., 5.0_real64, 8.0_real64, &
                .false., 0.0_real64, 0.0_real64, 0.0_real64, 0.5_real64, 3)
  call run_case(0.5_real64, 1.0_real64, 0.0_real64, .true., 5.0_real64, 8.0_real64, &
                .true., nearest(20.0_real64, -1.0_real64), 20.0_real64, 100.0_real64, 0.8_real64, 4)
  call run_case(0.5_real64, 1.0_real64, 0.0_real64, .true., 5.0_real64, 8.0_real64, &
                .true., nearest(20.0_real64, 1.0_real64), 20.0_real64, 100.0_real64, 1.6_real64, 5)

  random_state = 20260923_int64
  do i = 1, vector_count
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    dvs = 2.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    cdef = 10.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    rain = 10.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    rain_threshold = 10.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    corrections = -100.0_real64 + 200.0_real64* &
                  real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    min_mm = 100.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    max_mm = min_mm + 100.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    concentration = 100.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    concentration_threshold = 100.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    over_percent = 100.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    limit_enabled = modulo(i, 2) == 0
    solute_enabled = modulo(i, 3) == 0

  call make_source_table(knots, corrections, 5, table)
    expected_correction = source_afgen(table, 14, dvs)
    expected_depth = source_dcs1(cdef, expected_correction, rain, rain_threshold, limit_enabled, &
                                 min_mm, max_mm, solute_enabled, concentration, &
                                 concentration_threshold, over_percent)
    call evaluate_dcs1_depth(dvs, knots, corrections, 5, cdef, rain, rain_threshold, limit_enabled, &
                             min_mm, max_mm, solute_enabled, concentration, concentration_threshold, &
                             over_percent, depth, correction, status)
    call require(status == IRR_DCS1_OK, 10)
    call require(transfer(correction, 0_int64) == transfer(expected_correction, 0_int64), 11)
    call require(transfer(depth, 0_int64) == transfer(expected_depth, 0_int64), 12)
  end do

  print '(A)', 'PPA_IRR_DCS1_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_DCS1_RAIN_THRESHOLD_ZERO_FLOOR_AND_LIMIT_ORDER=PASS'
  print '(A)', 'PPA_IRR_DCS1_SOLUTE_THRESHOLD_STRICTNESS=PASS'
  print '(A)', 'PPA_IRR_DCS1_DEPTH_SOURCE_ORACLE=PASS'

contains

  subroutine run_case(stage, deficit, rainfall_value, apply_limit, minimum_mm, maximum_mm, &
                      apply_solute, concentration_value, threshold, percentage, expected, code)
    real(real64), intent(in) :: stage, deficit, rainfall_value, minimum_mm, maximum_mm
    real(real64), intent(in) :: concentration_value, threshold, percentage, expected
    logical, intent(in) :: apply_limit, apply_solute
    integer, intent(in) :: code
    real(real64) :: actual, corr
    integer :: result_status

    call evaluate_dcs1_depth(stage, knots, corrections, 7, deficit, rainfall_value, 1.0_real64, &
                             apply_limit, minimum_mm, maximum_mm, apply_solute, concentration_value, &
                             threshold, percentage, actual, corr, result_status)
    call require(result_status == IRR_DCS1_OK, 20+code)
    call require(abs(actual-expected) <= 8.0_real64*epsilon(expected)*max(1.0_real64,abs(expected)), 30+code)
  end subroutine run_case

  subroutine make_source_table(source_knots, source_values, count, source_table)
    real(real64), intent(in) :: source_knots(IRR_DCS1_MAX_KNOTS)
    real(real64), intent(in) :: source_values(IRR_DCS1_MAX_KNOTS)
    integer, intent(in) :: count
    real(real64), intent(out) :: source_table(14)
    integer :: j

    source_table = 0.0_real64
    do j = 1, count
      source_table(2*j-1) = source_knots(j)
      source_table(2*j) = source_values(j)
    end do
    if (count < IRR_DCS1_MAX_KNOTS) then
      source_table(2*count+1) = source_knots(count) - 1.0_real64
      source_table(2*count+2) = source_values(count)
    end if
  end subroutine make_source_table

  real(real64) function source_afgen(source_table, table_length, x) result(y)
    integer, intent(in) :: table_length
    real(real64), intent(in) :: source_table(table_length), x
    real(real64) :: slope
    integer :: j

    if (source_table(1) >= x) then
      y = source_table(2)
      return
    end if
    do j = 3, table_length-1, 2
      if (source_table(j) >= x) then
        slope = (source_table(j+1)-source_table(j-1))/(source_table(j)-source_table(j-2))
        y = source_table(j-1) + (x-source_table(j-2))*slope
        return
      end if
      if (source_table(j) < source_table(j-2)) then
        y = source_table(j-1)
        return
      end if
    end do
    y = source_table(table_length)
  end function source_afgen

  real(real64) function source_dcs1(deficit, correction_value, rainfall_value, rainfall_gate, &
                                    apply_limit, minimum_mm, maximum_mm, apply_solute, &
                                    concentration_value, concentration_limit, percentage) result(value)
    real(real64), intent(in) :: deficit, correction_value, rainfall_value, rainfall_gate
    real(real64), intent(in) :: minimum_mm, maximum_mm, concentration_value, concentration_limit, percentage
    logical, intent(in) :: apply_limit, apply_solute
    real(real64) :: rainfall_reduction

    rainfall_reduction = 0.0_real64
    if (rainfall_value > rainfall_gate) rainfall_reduction = rainfall_value
    value = max(0.0_real64, deficit + correction_value*0.1_real64 - rainfall_reduction)
    if (apply_limit) then
      value = max(value, minimum_mm*0.1_real64)
      value = min(value, maximum_mm*0.1_real64)
    end if
    if (apply_solute) then
      if (concentration_value > concentration_limit) value = value + 0.01_real64*percentage*value
    end if
  end function source_dcs1

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_DCS1_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_dcs1_depth_source_oracle
