module mod_fmr_crop_rotation_calendar_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_ROTATION_OK = 0
  integer, parameter, public :: CROP_ROTATION_INVALID = 1
  public :: select_crop_rotation_event
contains
  pure subroutine select_crop_rotation_event(start_day,end_day,current_day,active_crop,next_crop,status)
    real(real64), intent(in) :: start_day(:),end_day(:),current_day
    integer, intent(out) :: active_crop,next_crop,status
    integer :: i,n
    active_crop = 0
    next_crop = 0
    status = CROP_ROTATION_INVALID
    n = size(start_day)
    if (n < 1 .or. size(end_day) /= n .or. .not. ieee_is_finite(current_day)) return
    if (any(.not. ieee_is_finite(start_day)) .or. any(.not. ieee_is_finite(end_day))) return
    if (any(start_day < 1.0_real64) .or. any(end_day < start_day)) return
    do i=2,n
      if (start_day(i) <= end_day(i-1)) return
    end do
    do i=1,n
      if (current_day >= start_day(i) .and. current_day <= end_day(i)) then
        active_crop = i
        if (i < n) next_crop = i+1
        exit
      end if
      if (current_day < start_day(i)) then
        next_crop = i
        exit
      end if
    end do
    status = CROP_ROTATION_OK
  end subroutine
end module
