module mod_ppa_irr_dcs1_depth
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_DCS1_OK = 0
  integer, parameter, public :: IRR_DCS1_INVALID_INPUT = 1
  integer, parameter, public :: IRR_DCS1_MAX_KNOTS = 7

  public :: evaluate_dcs1_depth

contains

  pure subroutine evaluate_dcs1_depth(dvs, dvs_knots, correction_mm, knot_count, deficit, rainfall, &
                                      rain_threshold, limit_enabled, min_depth_mm, max_depth_mm, &
                                      solute_threshold_enabled, concentration, concentration_threshold, &
                                      overirrigation_percent, depth_cm, correction_at_dvs_mm, status)
    real(real64), intent(in) :: dvs
    real(real64), intent(in) :: dvs_knots(IRR_DCS1_MAX_KNOTS)
    real(real64), intent(in) :: correction_mm(IRR_DCS1_MAX_KNOTS)
    integer, intent(in) :: knot_count
    real(real64), intent(in) :: deficit, rainfall, rain_threshold
    logical, intent(in) :: limit_enabled, solute_threshold_enabled
    real(real64), intent(in) :: min_depth_mm, max_depth_mm
    real(real64), intent(in) :: concentration, concentration_threshold, overirrigation_percent
    real(real64), intent(out) :: depth_cm, correction_at_dvs_mm
    integer, intent(out) :: status
    real(real64) :: rainfall_reduction
    logical :: ok

    depth_cm = 0.0_real64
    correction_at_dvs_mm = 0.0_real64
    status = IRR_DCS1_INVALID_INPUT

    if (.not. ieee_is_finite(dvs) .or. .not. ieee_is_finite(deficit) .or. &
        .not. ieee_is_finite(rainfall) .or. .not. ieee_is_finite(rain_threshold)) return
    if (dvs < 0.0_real64 .or. dvs > 2.0_real64) return
    if (rainfall < 0.0_real64 .or. rain_threshold < 0.0_real64 .or. rain_threshold > 1000.0_real64) return
    if (.not. valid_table(dvs_knots, correction_mm, knot_count)) return
    if (limit_enabled) then
      if (.not. ieee_is_finite(min_depth_mm) .or. .not. ieee_is_finite(max_depth_mm)) return
      if (min_depth_mm < 0.0_real64 .or. max_depth_mm < min_depth_mm .or. max_depth_mm > 1.0e7_real64) return
    end if
    if (solute_threshold_enabled) then
      if (.not. ieee_is_finite(concentration) .or. .not. ieee_is_finite(concentration_threshold) .or. &
          .not. ieee_is_finite(overirrigation_percent)) return
      if (concentration_threshold < 0.0_real64 .or. concentration_threshold > 100.0_real64) return
      if (overirrigation_percent < 0.0_real64 .or. overirrigation_percent > 100.0_real64) return
    end if

    call source_afgen(dvs_knots, correction_mm, knot_count, dvs, correction_at_dvs_mm, ok)
    if (.not. ok) return
    rainfall_reduction = 0.0_real64
    if (rainfall > rain_threshold) rainfall_reduction = rainfall
    depth_cm = max(0.0_real64, deficit + correction_at_dvs_mm*0.1_real64 - rainfall_reduction)
    if (limit_enabled) then
      depth_cm = max(depth_cm, min_depth_mm*0.1_real64)
      depth_cm = min(depth_cm, max_depth_mm*0.1_real64)
    end if
    if (solute_threshold_enabled) then
      if (concentration > concentration_threshold) &
        depth_cm = depth_cm + 0.01_real64*overirrigation_percent*depth_cm
    end if
    status = IRR_DCS1_OK
  end subroutine evaluate_dcs1_depth

  pure logical function valid_table(knots, values, knot_count)
    real(real64), intent(in) :: knots(IRR_DCS1_MAX_KNOTS)
    real(real64), intent(in) :: values(IRR_DCS1_MAX_KNOTS)
    integer, intent(in) :: knot_count
    integer :: i

    valid_table = .false.
    if (knot_count < 2 .or. knot_count > IRR_DCS1_MAX_KNOTS) return
    do i = 1, knot_count
      if (.not. ieee_is_finite(knots(i)) .or. .not. ieee_is_finite(values(i))) return
      if (knots(i) < 0.0_real64 .or. knots(i) > 2.0_real64) return
      if (values(i) < -100.0_real64 .or. values(i) > 100.0_real64) return
    end do
    do i = 2, knot_count
      if (knots(i) <= knots(i-1)) return
    end do
    valid_table = .true.
  end function valid_table

  pure subroutine source_afgen(knots, values, knot_count, dvs, interpolated, ok)
    real(real64), intent(in) :: knots(IRR_DCS1_MAX_KNOTS)
    real(real64), intent(in) :: values(IRR_DCS1_MAX_KNOTS)
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

end module mod_ppa_irr_dcs1_depth
