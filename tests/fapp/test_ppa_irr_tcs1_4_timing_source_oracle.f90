program test_ppa_irr_tcs1_4_timing_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_tcs1_4_timing
  implicit none

  integer, parameter :: vector_count = 100000
  integer, parameter :: active_knots = 5
  real(real64) :: knots(IRR_TCS1_4_MAX_KNOTS), values(IRR_TCS1_4_MAX_KNOTS), table(14)
  real(real64) :: dvs, iptra, dry_reduction, saline_reduction, awlh, awmh, awah
  real(real64) :: actual_threshold, stress_ratio, depletion, expected_threshold, expected_stress, expected_depletion
  integer(int64) :: random_state
  integer :: i, j, criterion, status
  logical :: triggered, expected_trigger

  knots = [0.0_real64, 0.5_real64, 1.0_real64, 1.5_real64, 1.75_real64, 1.9_real64, 2.0_real64]
  values = 0.0_real64

  ! TCS1 strict equality and no-potential-transpiration fallback.
  values(1:active_knots) = 0.5_real64
  call run_case(1, 0.5_real64, 1.0_real64, 0.5_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 1)
  call run_case(1, 0.5_real64, 1.0_real64, nearest(0.5_real64, 1.0_real64), 0.0_real64, &
                0.0_real64, 0.0_real64, 0.0_real64, 2)
  values(1:active_knots) = 1.0_real64
  call run_case(1, 0.5_real64, 1.0e-10_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
                0.0_real64, 0.0_real64, 3)

  ! TCS2 cap path and strict trigger equality; TCS3 and TCS4 strict boundaries.
  values(1:active_knots) = 1.0_real64
  call run_case(2, 0.5_real64, 0.0_real64, 0.0_real64, 1.0_real64, -10.0_real64, -0.1_real64, 0.0_real64, 4)
  values(1:active_knots) = 0.5_real64
  call run_case(2, 0.5_real64, 0.0_real64, 0.0_real64, 10.0_real64, 2.0_real64, 6.0_real64, 0.0_real64, 5)
  call run_case(2, 0.5_real64, 0.0_real64, 0.0_real64, 10.0_real64, 2.0_real64, &
                nearest(6.0_real64, -1.0_real64), 0.0_real64, 6)
  call run_case(3, 0.5_real64, 0.0_real64, 0.0_real64, 10.0_real64, 0.0_real64, 5.0_real64, 0.0_real64, 7)
  call run_case(3, 0.5_real64, 0.0_real64, 0.0_real64, 10.0_real64, 0.0_real64, &
                nearest(5.0_real64, -1.0_real64), 0.0_real64, 8)
  values(1:active_knots) = 20.0_real64
  call run_case(4, 0.5_real64, 0.0_real64, 0.0_real64, 10.0_real64, 0.0_real64, 8.0_real64, 0.0_real64, 9)
  call run_case(4, 0.5_real64, 0.0_real64, 0.0_real64, 10.0_real64, 0.0_real64, &
                nearest(8.0_real64, -1.0_real64), 0.0_real64, 10)

  random_state = 20260923_int64
  do criterion = 1, 4
    do i = 1, vector_count
      call random_unit(random_state, dvs)
      dvs = 2.0_real64*dvs
      do j = 1, active_knots
        call random_unit(random_state, values(j))
        if (criterion == 4) then
          values(j) = 500.0_real64*values(j)
        end if
      end do
      call make_source_table(knots, values, active_knots, table)
      expected_threshold = source_afgen(table, 14, dvs)

      iptra = 0.0_real64
      dry_reduction = 0.0_real64
      saline_reduction = 0.0_real64
      awlh = 0.0_real64
      awmh = 0.0_real64
      awah = 0.0_real64
      if (criterion == 4) then
        call random_unit(random_state, awlh)
        awlh = -10.0_real64 + 20.0_real64*awlh
        call random_unit(random_state, awah)
        awah = -10.0_real64 + 20.0_real64*awah
      else if (criterion == 1) then
        call random_unit(random_state, iptra)
        iptra = 10.0_real64*iptra
        call random_unit(random_state, dry_reduction)
        dry_reduction = 5.0_real64*dry_reduction
        call random_unit(random_state, saline_reduction)
        saline_reduction = 5.0_real64*saline_reduction
      else
        call random_unit(random_state, awlh)
        awlh = 10.0_real64*awlh
        call random_unit(random_state, awah)
        awah = -1.0_real64 + 12.0_real64*awah
        if (criterion == 2) then
          call random_unit(random_state, awmh)
          awmh = -2.0_real64 + 12.0_real64*awmh
        end if
      end if

      call source_selector(criterion, expected_threshold, iptra, dry_reduction, saline_reduction, &
                           awlh, awmh, awah, expected_trigger, expected_stress, expected_depletion)
      call evaluate_tcs1_4_timing(criterion, dvs, knots, values, active_knots, iptra, dry_reduction, &
                                  saline_reduction, awlh, awmh, awah, triggered, actual_threshold, &
                                  stress_ratio, depletion, status)
      call require(status == IRR_TCS1_4_OK, 20+criterion)
      call require(transfer(actual_threshold, 0_int64) == transfer(expected_threshold, 0_int64), 30+criterion)
      call require(triggered .eqv. expected_trigger, 40+criterion)
      call require(transfer(stress_ratio, 0_int64) == transfer(expected_stress, 0_int64), 50+criterion)
      call require(transfer(depletion, 0_int64) == transfer(expected_depletion, 0_int64), 60+criterion)
    end do
  end do

  print '(A)', 'PPA_IRR_TCS1_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_TCS2_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_TCS3_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_TCS4_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_TCS1_4_STRICT_THRESHOLDS_AND_SOURCE_ORACLE=PASS'

contains

  subroutine run_case(selected, dvs_value, selected_iptra, dry, saline, total, middle, actual, code)
    integer, intent(in) :: selected, code
    real(real64), intent(in) :: dvs_value, selected_iptra, dry, saline, total, middle, actual
    real(real64) :: selected_values(IRR_TCS1_4_MAX_KNOTS), selected_threshold
    real(real64) :: actual_threshold, actual_stress, actual_depletion, expected_stress, expected_depletion
    integer :: result_status
    logical :: actual_trigger, reference_trigger

    selected_values = values
    call make_source_table(knots, selected_values, active_knots, table)
    selected_threshold = source_afgen(table, 14, dvs_value)
    call source_selector(selected, selected_threshold, selected_iptra, dry, saline, &
                         total, middle, actual, reference_trigger, expected_stress, expected_depletion)
    call evaluate_tcs1_4_timing(selected, dvs_value, knots, selected_values, active_knots, &
                                selected_iptra, dry, saline, total, middle, actual, actual_trigger, &
                                actual_threshold, actual_stress, actual_depletion, result_status)
    call require(result_status == IRR_TCS1_4_OK .and. (actual_trigger .eqv. reference_trigger), 100+code)
  end subroutine run_case

  subroutine random_unit(state, unit_value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: unit_value
    state = modulo(state*48271_int64, 2147483647_int64)
    unit_value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine make_source_table(source_knots, source_values, count, source_table)
    real(real64), intent(in) :: source_knots(IRR_TCS1_4_MAX_KNOTS)
    real(real64), intent(in) :: source_values(IRR_TCS1_4_MAX_KNOTS)
    integer, intent(in) :: count
    real(real64), intent(out) :: source_table(14)
    integer :: j
    source_table = 0.0_real64
    do j = 1, count
      source_table(2*j-1) = source_knots(j)
      source_table(2*j) = source_values(j)
    end do
    if (count < IRR_TCS1_4_MAX_KNOTS) then
      source_table(2*count+1) = source_knots(count)-1.0_real64
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

  subroutine source_selector(selected, threshold_value, potential, dry, saline, total, middle, actual, &
                             source_trigger, source_stress, source_depletion)
    integer, intent(in) :: selected
    real(real64), intent(in) :: threshold_value, potential, dry, saline, total, middle, actual
    logical, intent(out) :: source_trigger
    real(real64), intent(out) :: source_stress, source_depletion
    source_trigger = .false.
    source_stress = 1.0_real64
    source_depletion = 0.0_real64
    select case (selected)
    case (1)
      if (potential > 1.0e-10_real64) then
        source_stress = 1.0_real64 - (dry+saline)/potential
      else
        source_stress = 1.0_real64
      end if
      source_trigger = source_stress < threshold_value
    case (2)
      source_depletion = threshold_value*(total-middle)
      if (source_depletion > total) source_depletion = total
      source_trigger = actual < (total-source_depletion)
    case (3)
      source_depletion = threshold_value*total
      source_trigger = actual < (total-source_depletion)
    case (4)
      source_depletion = threshold_value*0.1_real64
      source_trigger = (total-actual) > source_depletion
    end select
  end subroutine source_selector

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_TCS1_4_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_tcs1_4_timing_source_oracle
