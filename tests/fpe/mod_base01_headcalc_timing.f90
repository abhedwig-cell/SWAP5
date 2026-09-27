module mod_base01_headcalc_timing
  use, intrinsic :: iso_c_binding, only: c_int, c_double
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: BASE01_CAT_HEADCALC=1
  integer, parameter, public :: BASE01_CAT_CONSTITUTIVE=2
  integer, parameter, public :: BASE01_CAT_VECTOR=3
  integer, parameter, public :: BASE01_CAT_JACOBIAN=4
  integer, parameter, public :: BASE01_CAT_LINEAR=5
  integer, parameter, public :: BASE01_CAT_BACKTRACK=6
  integer, parameter :: NCAT=6

  integer(int64), save :: ticks(NCAT)=0_int64
  integer(int64), save :: starts(NCAT)=0_int64
  integer(int64), save :: calls(NCAT)=0_int64

  public :: base01_tic, base01_toc
  public :: base01_timing_reset_c, base01_timing_get_c

contains

  subroutine base01_tic(category)
    integer, intent(in) :: category
    if(category<1 .or. category>NCAT) return
    call system_clock(starts(category))
  end subroutine base01_tic

  subroutine base01_toc(category)
    integer, intent(in) :: category
    integer(int64) :: now
    if(category<1 .or. category>NCAT) return
    call system_clock(now)
    ticks(category)=ticks(category)+max(0_int64,now-starts(category))
    calls(category)=calls(category)+1_int64
  end subroutine base01_toc

  integer(c_int) function base01_timing_reset_c() bind(C,name="base01_timing_reset_c")
    ticks=0_int64
    starts=0_int64
    calls=0_int64
    base01_timing_reset_c=0_c_int
  end function base01_timing_reset_c

  integer(c_int) function base01_timing_get_c(seconds_out,calls_out) bind(C,name="base01_timing_get_c")
    real(c_double), intent(out) :: seconds_out(NCAT)
    integer(c_int), intent(out) :: calls_out(NCAT)
    integer(int64) :: rate
    integer :: i
    call system_clock(count_rate=rate)
    seconds_out=0.0_c_double
    calls_out=0_c_int
    if(rate>0_int64) then
      do i=1,NCAT
        seconds_out(i)=real(ticks(i),c_double)/real(rate,c_double)
        calls_out(i)=int(calls(i),c_int)
      end do
    end if
    base01_timing_get_c=0_c_int
  end function base01_timing_get_c
end module mod_base01_headcalc_timing
