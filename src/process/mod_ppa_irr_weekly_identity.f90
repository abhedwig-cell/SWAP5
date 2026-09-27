! Detached management metadata/proposals, not an independent state owner.
module mod_ppa_irr_weekly_identity
  use, intrinsic :: iso_fortran_env, only: int64
  implicit none
  private
  type,public :: ppa_weekly_identity_t
    logical :: enabled=.false.,day_bound=.false.
    integer :: dayfix=366
    integer(int64) :: last_day=0_int64
  end type
  public :: valid_weekly_identity,prepare_weekly_day
contains
  pure logical function valid_weekly_identity(state) result(ok)
    type(ppa_weekly_identity_t),intent(in)::state
    ok=.false.
    if(state%dayfix<0.or.state%dayfix>366) return
    if(.not.state%enabled) then
      if(state%day_bound.or.state%dayfix/=366.or.state%last_day/=0_int64) return
    else if(.not.state%day_bound) then
      if(state%dayfix/=366.or.state%last_day/=0_int64) return
    else
      if(state%last_day<0_int64) return
    end if
    ok=.true.
  end function

  pure subroutine prepare_weekly_day(base,daily,ordinal,proposed,evaluate_daily,ok)
    type(ppa_weekly_identity_t),intent(in)::base
    logical,intent(in)::daily
    integer(int64),intent(in)::ordinal
    type(ppa_weekly_identity_t),intent(out)::proposed
    logical,intent(out)::evaluate_daily,ok
    proposed=base; evaluate_daily=.false.; ok=.false.
    if(.not.valid_weekly_identity(base)) return
    if(.not.base%enabled) return
    if(.not.daily) then
      ok=.true.
      return
    end if
    if(ordinal<0_int64) return
    if(base%day_bound) then
      if(ordinal<base%last_day) return
      if(ordinal==base%last_day) then
        ok=.true.
        return
      end if
      ! Subtract only ordered nonnegative values to avoid signed overflow.
      if(ordinal-base%last_day/=1_int64) return
    end if
    proposed%last_day=ordinal; proposed%day_bound=.true.
    evaluate_daily=.true.; ok=.true.
  end subroutine
end module
