module mod_ppa_irr_tcs1_4_timing
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_TCS1_4_OK = 0
  integer, parameter, public :: IRR_TCS1_4_INVALID_INPUT = 1
  integer, parameter, public :: IRR_TCS1_4_MAX_KNOTS = 7

  public :: evaluate_tcs1_4_timing

contains

  pure subroutine evaluate_tcs1_4_timing(criterion, dvs, dvs_knots, threshold_values, knot_count, &
                                         iptra_day, iqreddry_day, iqredsol_day, awlh, awmh, awah, &
                                         triggered, threshold, stress_ratio, depletion, status)
    integer, intent(in) :: criterion, knot_count
    real(real64), intent(in) :: dvs, dvs_knots(IRR_TCS1_4_MAX_KNOTS)
    real(real64), intent(in) :: threshold_values(IRR_TCS1_4_MAX_KNOTS)
    real(real64), intent(in) :: iptra_day, iqreddry_day, iqredsol_day, awlh, awmh, awah
    logical, intent(out) :: triggered
    real(real64), intent(out) :: threshold, stress_ratio, depletion
    integer, intent(out) :: status
    logical :: ok

    triggered = .false.
    threshold = 0.0_real64
    stress_ratio = 1.0_real64
    depletion = 0.0_real64
    status = IRR_TCS1_4_INVALID_INPUT

    if (criterion < 1 .or. criterion > 4) return
    if (.not. ieee_is_finite(dvs)) return
    if (dvs < 0.0_real64 .or. dvs > 2.0_real64) return
    if (.not. valid_table(dvs_knots, threshold_values, knot_count, criterion)) return
    select case (criterion)
    case (1)
      if (.not. ieee_is_finite(iptra_day) .or. .not. ieee_is_finite(iqreddry_day) .or. &
          .not. ieee_is_finite(iqredsol_day)) return
    case (2:4)
      if (.not. ieee_is_finite(awlh) .or. .not. ieee_is_finite(awah)) return
      if (criterion == 2 .and. .not. ieee_is_finite(awmh)) return
    end select

    call source_afgen(dvs_knots, threshold_values, knot_count, dvs, threshold, ok)
    if (.not. ok) return
    select case (criterion)
    case (1)
      if (iptra_day > 1.0e-10_real64) then
        stress_ratio = 1.0_real64 - (iqreddry_day + iqredsol_day) / iptra_day
      else
        stress_ratio = 1.0_real64
      end if
      triggered = stress_ratio < threshold
    case (2)
      depletion = threshold * (awlh-awmh)
      if (depletion > awlh) depletion = awlh
      triggered = awah < (awlh-depletion)
    case (3)
      depletion = threshold * awlh
      triggered = awah < (awlh-depletion)
    case (4)
      depletion = threshold * 0.1_real64
      triggered = (awlh-awah) > depletion
    end select
    status = IRR_TCS1_4_OK
  end subroutine evaluate_tcs1_4_timing

  pure logical function valid_table(knots, values, knot_count, criterion)
    real(real64), intent(in) :: knots(IRR_TCS1_4_MAX_KNOTS)
    real(real64), intent(in) :: values(IRR_TCS1_4_MAX_KNOTS)
    integer, intent(in) :: knot_count, criterion
    integer :: i
    real(real64) :: maximum

    valid_table = .false.
    if (knot_count < 2 .or. knot_count > IRR_TCS1_4_MAX_KNOTS) return
    maximum = 1.0_real64
    if (criterion == 4) maximum = 500.0_real64
    do i = 1, knot_count
      if (.not. ieee_is_finite(knots(i)) .or. .not. ieee_is_finite(values(i))) return
      if (knots(i) < 0.0_real64 .or. knots(i) > 2.0_real64) return
      if (values(i) < 0.0_real64 .or. values(i) > maximum) return
    end do
    do i = 2, knot_count
      if (knots(i) <= knots(i-1)) return
    end do
    valid_table = .true.
  end function valid_table

  pure subroutine source_afgen(knots, values, knot_count, dvs, interpolated, ok)
    real(real64), intent(in) :: knots(IRR_TCS1_4_MAX_KNOTS)
    real(real64), intent(in) :: values(IRR_TCS1_4_MAX_KNOTS)
    integer, intent(in) :: knot_count
    real(real64), intent(in) :: dvs
    real(real64), intent(out) :: interpolated
    logical, intent(out) :: ok
    real(real64) :: slope
    integer :: i

    interpolated = 0.0_real64
    ok = .false.
    if (dvs <= knots(1)) then
      interpolated = values(1)
      ok = .true.
      return
    end if
    do i = 2, knot_count
      if (dvs <= knots(i)) then
        slope = (values(i)-values(i-1))/(knots(i)-knots(i-1))
        interpolated = values(i-1) + (dvs-knots(i-1))*slope
        ok = ieee_is_finite(interpolated)
        return
      end if
    end do
    interpolated = values(knot_count)
    ok = .true.
  end subroutine source_afgen

end module mod_ppa_irr_tcs1_4_timing
