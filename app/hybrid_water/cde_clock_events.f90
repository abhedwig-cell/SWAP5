module hybrid_cde_clock_events
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  integer,parameter,public::CDE_CLOCK_EVENT_OK=0,CDE_CLOCK_EVENT_INVALID=1
  public::close_cde_clock_event
contains
  pure subroutine close_cde_clock_event(tcum,irrigation_end,dtcrit,dt,event_limit,changed,status)
    real(8),intent(in)::tcum,irrigation_end,dtcrit
    real(8),intent(inout)::dt,event_limit
    logical,intent(out)::changed
    integer,intent(out)::status
    real(8)::target,remaining,new_dt,new_limit
    changed=.false.;status=CDE_CLOCK_EVENT_INVALID
    if(.not.all(ieee_is_finite([tcum,irrigation_end,dtcrit,dt,event_limit])))return
    ! This is the original TimeControl coincidence constant, not a mass guard.
    if(dtcrit/=1d-8)return
    if(tcum<0d0.or.tcum>1d0+dtcrit.or.irrigation_end<0d0.or.irrigation_end>1d0)return
    if(dt<=0d0.or.event_limit<=0d0)return
    status=CDE_CLOCK_EVENT_OK
    target=1d0
    if(irrigation_end>tcum.and.irrigation_end<target)target=irrigation_end
    remaining=target-tcum
    if(remaining<=0d0)return
    new_dt=dt;new_limit=event_limit
    ! Absolute epoch subtraction can put a print boundary just before a local
    ! irrigation/end-day boundary. Original dtCrit then retires the remaining
    ! event before its water/source was delivered. Close the coincident local
    ! event before the original reset; preserve genuinely earlier event caps.
    if(abs(event_limit-remaining)<=dtcrit)then
      new_limit=remaining
      if(abs(dt-remaining)<=dtcrit)new_dt=remaining
    end if
    changed=new_dt/=dt.or.new_limit/=event_limit
    dt=new_dt;event_limit=new_limit
  end subroutine
end module
