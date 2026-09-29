! Proposed typed numerical history for B1.11 HeadCalc exchange reduction.
! Pure proposals only: caller owns acceptance, retries and persisted history.
module mod_ppa_wu05a4_reduction_policy
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  type,public::exchange_reduction_history
    integer::decades=0,steps=0
    real(real64)::previous_dt=0
    logical::reduced_retry=.false.
  end type
  public::propose_exchange_retry,propose_exchange_recovery
contains
  pure logical function valid(history,dt)
    type(exchange_reduction_history),intent(in)::history
    real(real64),intent(in)::dt
    valid=.false.
    if(.not.ieee_is_finite(dt).or..not.ieee_is_finite(history%previous_dt))return
    if(dt<=0.or.history%previous_dt<0)return
    if(history%decades<0.or.history%decades>3.or.history%steps<0.or.history%steps>10)return
    valid=.true.
  end function

  ! Only call after the owner chooses exchange reduction over timestep reduction.
  pure subroutine propose_exchange_retry(history,dt,proposal,ok)
    type(exchange_reduction_history),intent(in)::history
    real(real64),intent(in)::dt
    type(exchange_reduction_history),intent(out)::proposal
    logical,intent(out)::ok
    ok=.false.
    if(.not.valid(history,dt))return
    if(history%decades>=3)return
    proposal=history
    proposal%decades=history%decades+1
    proposal%reduced_retry=.true.
    proposal%previous_dt=dt
    ok=.true.
  end subroutine

  ! Source recovery after convergence. Does not itself assert physical acceptance.
  pure subroutine propose_exchange_recovery(history,dt,proposal,ok)
    type(exchange_reduction_history),intent(in)::history
    real(real64),intent(in)::dt
    type(exchange_reduction_history),intent(out)::proposal
    logical,intent(out)::ok
    ok=.false.
    if(.not.valid(history,dt))return
    proposal=history
    proposal%reduced_retry=.false.
    if(proposal%decades>0)then
      if(proposal%steps<10)proposal%steps=proposal%steps+1
      if(dt>proposal%previous_dt.or.proposal%steps>=10)then
        proposal%previous_dt=dt
        proposal%steps=0
        proposal%decades=proposal%decades-1
      end if
    end if
    ok=.true.
  end subroutine
end module
