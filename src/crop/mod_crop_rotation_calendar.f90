module mod_crop_rotation_calendar
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_CAL_OK=0, CROP_CAL_INVALID=1, CROP_CAL_OVERLAP=2
  integer, parameter, public :: CROP_CAL_OUTSIDE=3
  real(real64), parameter :: SOURCE_DAY_TOL=0.1_real64
  type, public :: crop_calendar_t
    private
    real(real64), allocatable :: starts(:), ends(:)
  contains
    procedure :: ready => calendar_ready
    procedure :: select_at => calendar_select
    procedure :: size => calendar_size
  end type
  public :: initialize_crop_calendar
contains
  subroutine initialize_crop_calendar(starts, ends, calendar, status)
    real(real64), intent(in) :: starts(:), ends(:)
    type(crop_calendar_t), intent(out) :: calendar
    integer, intent(out) :: status
    integer :: n,i
    status=CROP_CAL_INVALID
    n=size(starts)
    if(n<1.or.size(ends)/=n) return
    if(any(.not.ieee_is_finite(starts)).or.any(.not.ieee_is_finite(ends))) return
    if(any(starts<1.0_real64).or.any(ends<starts)) return
    do i=2,n
      if(starts(i)-ends(i-1)<0.5_real64) then
        status=CROP_CAL_OVERLAP
        return
      end if
    end do
    allocate(calendar%starts(n),calendar%ends(n))
    calendar%starts=starts
    calendar%ends=ends
    status=CROP_CAL_OK
  end subroutine
  logical function calendar_ready(self)
    class(crop_calendar_t), intent(in) :: self
    calendar_ready=allocated(self%starts).and.allocated(self%ends)
  end function
  integer function calendar_size(self)
    class(crop_calendar_t), intent(in) :: self
    calendar_size=0
    if(self%ready()) calendar_size=size(self%starts)
  end function
  subroutine calendar_select(self, time, index, active, starts_today, status)
    class(crop_calendar_t), intent(in) :: self
    real(real64), intent(in) :: time
    integer, intent(out) :: index,status
    logical, intent(out) :: active,starts_today
    integer :: i
    index=0
    active=.false.
    starts_today=.false.
    status=CROP_CAL_INVALID
    if(.not.self%ready()) return
    if(.not.ieee_is_finite(time)) return
    status=CROP_CAL_OUTSIDE
    do i=1,size(self%starts)
      if(time<self%starts(i)-SOURCE_DAY_TOL) exit
      if(time-self%ends(i)<SOURCE_DAY_TOL) then
        index=i
        active=.true.
        starts_today=abs(time-self%starts(i))<1.0e-3_real64
        status=CROP_CAL_OK
        return
      end if
    end do
  end subroutine
end module mod_crop_rotation_calendar
