module mod_ppa_irr_tcs6_weekly_timing
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_TCS6_OK = 0
  integer, parameter, public :: IRR_TCS6_INVALID_INPUT = 1

  public :: evaluate_tcs6_weekly_timing

contains

  pure subroutine evaluate_tcs6_weekly_timing(dayfix, deficit_cm, threshold_mm, next_dayfix, triggered, status)
    integer, intent(in) :: dayfix
    real(real64), intent(in) :: deficit_cm, threshold_mm
    integer, intent(out) :: next_dayfix
    logical, intent(out) :: triggered
    integer, intent(out) :: status

    next_dayfix = dayfix
    triggered = .false.
    status = IRR_TCS6_INVALID_INPUT

    if (dayfix < 0 .or. dayfix > 366) return
    if (.not. ieee_is_finite(deficit_cm) .or. .not. ieee_is_finite(threshold_mm)) return
    if (threshold_mm < 0.0_real64 .or. threshold_mm > 20.0_real64) return

    next_dayfix = dayfix + 1
    if (next_dayfix >= 7) then
      next_dayfix = 0
      triggered = 10.0_real64*deficit_cm > threshold_mm
    end if
    status = IRR_TCS6_OK
  end subroutine evaluate_tcs6_weekly_timing

end module mod_ppa_irr_tcs6_weekly_timing
