module mod_irrigation_availability_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_AVAIL_OK = 0
  integer, parameter, public :: IRR_AVAIL_INVALID = 1

  public :: apply_irrigation_availability

contains

  pure subroutine apply_irrigation_availability(enabled, fraction, configured_rate_positive, rate, duration, status)
    logical, intent(in) :: enabled
    real(real64), intent(in) :: fraction
    logical, intent(in) :: configured_rate_positive
    real(real64), intent(inout) :: rate
    real(real64), intent(inout) :: duration
    integer, intent(out) :: status

    status = IRR_AVAIL_INVALID
    if (.not. ieee_is_finite(rate) .or. .not. ieee_is_finite(duration)) return
    if (rate < 0.0_real64 .or. duration < 0.0_real64) return
    if (.not. enabled) then
      status = IRR_AVAIL_OK
      return
    end if
    if (.not. ieee_is_finite(fraction) .or. fraction < 0.0_real64 .or. fraction > 1.0_real64) return

    ! Literal B1.11 postselection TASK=4 semantics:
    !   gird = gird * f_irr_avail
    !   if (irr_rate > 0.0d0) dt_irr_event = dt_irr_event * f_irr_avail
    rate = rate * fraction
    if (configured_rate_positive) duration = duration * fraction
    status = IRR_AVAIL_OK
  end subroutine apply_irrigation_availability

end module mod_irrigation_availability_policy
