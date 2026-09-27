module mod_ppa_irr_tcsfix_identity
  use, intrinsic :: iso_fortran_env, only: int64
  implicit none
  private
  type,public :: ppa_tcsfix_identity_t
    logical :: enabled=.false.,day_bound=.false.
    integer :: dayfix=366,interval_days=1
    integer(int64) :: last_day=0_int64
  end type
  public :: valid_tcsfix_identity,prepare_tcsfix_day
contains
  pure logical function valid_tcsfix_identity(state) result(ok)
    type(ppa_tcsfix_identity_t),intent(in)::state
    ok=.false.
    if(state%dayfix<0.or.state%dayfix>366.or.state%interval_days<1.or.state%interval_days>366) return
    if(.not.state%enabled) then
      ok=.not.state%day_bound.and.state%dayfix==366.and.state%interval_days==1.and.state%last_day==0_int64
    else if(.not.state%day_bound) then
      ok=state%dayfix==366.and.state%last_day==0_int64
    else
      ok=state%last_day>=0_int64
    end if
  end function
  pure subroutine prepare_tcsfix_day(base,daily,ordinal,proposed,evaluate_daily,ok)
    type(ppa_tcsfix_identity_t),intent(in)::base
    logical,intent(in)::daily
    integer(int64),intent(in)::ordinal
    type(ppa_tcsfix_identity_t),intent(out)::proposed
    logical,intent(out)::evaluate_daily,ok
    proposed=base; evaluate_daily=.false.; ok=.false.
    if(.not.valid_tcsfix_identity(base).or..not.base%enabled) return
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
      if(ordinal-base%last_day/=1_int64) return
    end if
    proposed%last_day=ordinal; proposed%day_bound=.true.
    evaluate_daily=.true.; ok=.true.
  end subroutine
end module
