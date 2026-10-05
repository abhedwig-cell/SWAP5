module mod_irrigation_availability_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: IRRIGATION_AVAILABILITY_OK = 0
  integer, parameter, public :: IRRIGATION_AVAILABILITY_INVALID = 1
  public :: select_available_irrigation_event
contains
  pure subroutine select_available_irrigation_event(requested_depth_cm,configured_rate_cm_per_day, &
       allocation_fraction,delivered_depth_cm,effective_rate_cm_per_day,duration_days,status)
    real(real64), intent(in) :: requested_depth_cm,configured_rate_cm_per_day,allocation_fraction
    real(real64), intent(out) :: delivered_depth_cm,effective_rate_cm_per_day,duration_days
    integer, intent(out) :: status
    delivered_depth_cm = 0.0_real64
    effective_rate_cm_per_day = 0.0_real64
    duration_days = 0.0_real64
    status = IRRIGATION_AVAILABILITY_INVALID
    if (.not. all(ieee_is_finite([requested_depth_cm,configured_rate_cm_per_day,allocation_fraction]))) return
    if (requested_depth_cm < 0.0_real64 .or. configured_rate_cm_per_day < 0.0_real64 .or. &
        allocation_fraction < 0.0_real64 .or. allocation_fraction > 1.0_real64) return
    delivered_depth_cm = requested_depth_cm*allocation_fraction
    if (.not. ieee_is_finite(delivered_depth_cm)) then
      delivered_depth_cm = 0.0_real64
      return
    end if
    if (delivered_depth_cm > 0.0_real64) then
      effective_rate_cm_per_day = max(configured_rate_cm_per_day,delivered_depth_cm)
      duration_days = delivered_depth_cm/effective_rate_cm_per_day
    end if
    status = IRRIGATION_AVAILABILITY_OK
  end subroutine
end module
