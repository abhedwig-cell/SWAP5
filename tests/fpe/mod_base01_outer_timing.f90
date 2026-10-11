module mod_base01_outer_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: iso_c_binding, only: c_int, c_double
  implicit none
  private
  integer, parameter, public :: BASE01_OUTER_KERNEL_CORE=1
  integer, parameter, public :: BASE01_OUTER_KERNEL_CLONE=2
  integer, parameter, public :: BASE01_OUTER_CANONICAL_TOTAL=3
  integer, parameter, public :: BASE01_OUTER_CANONICAL_PREP=4
  integer, parameter, public :: BASE01_OUTER_TX_TOTAL=5
  integer, parameter, public :: BASE01_OUTER_TX_CLONE=6
  integer, parameter, public :: BASE01_OUTER_MODEL_ADVANCE=7
  integer, parameter, public :: BASE01_OUTER_TX_CONTEXT=8
  integer, parameter, public :: BASE01_OUTER_TEMPORAL=9
  integer, parameter, public :: BASE01_OUTER_KERNEL_POST=10
  integer, parameter :: NCAT=10
  integer(int64), save :: ticks(NCAT)=0_int64, starts(NCAT)=0_int64, calls(NCAT)=0_int64
  public :: base01_outer_tic, base01_outer_toc
  public :: base01_outer_timing_reset_c, base01_outer_timing_get_c
contains
  subroutine base01_outer_tic(cat)
    integer,intent(in)::cat
    if(cat<1 .or. cat>NCAT)return
    call system_clock(starts(cat))
  end subroutine
  subroutine base01_outer_toc(cat)
    integer,intent(in)::cat
    integer(int64)::now
    if(cat<1 .or. cat>NCAT)return
    call system_clock(now)
    ticks(cat)=ticks(cat)+max(0_int64,now-starts(cat))
    calls(cat)=calls(cat)+1_int64
  end subroutine
  integer(c_int) function base01_outer_timing_reset_c() bind(C,name="base01_outer_timing_reset_c")
    ticks=0_int64; starts=0_int64; calls=0_int64
    base01_outer_timing_reset_c=0_c_int
  end function
  integer(c_int) function base01_outer_timing_get_c(seconds_out,calls_out) bind(C,name="base01_outer_timing_get_c")
    real(c_double),intent(out)::seconds_out(NCAT)
    integer(c_int),intent(out)::calls_out(NCAT)
    integer(int64)::rate
    integer::i
    call system_clock(count_rate=rate)
    seconds_out=0.0_c_double; calls_out=0_c_int
    if(rate<=0_int64)then
      base01_outer_timing_get_c=1_c_int
      return
    end if
    do i=1,NCAT
      seconds_out(i)=real(ticks(i),real64)/real(rate,real64)
      calls_out(i)=int(calls(i),c_int)
    end do
    base01_outer_timing_get_c=0_c_int
  end function
end module mod_base01_outer_timing
