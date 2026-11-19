module hybrid_implicit_pond_event_state
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  integer,save::trace_count=0
  logical,save::pending=.false.
  real(8),save::event_clock=0d0,event_step=0d0
  public::request_implicit_pond_event,take_implicit_pond_event,assert_no_implicit_pond_event
contains
  subroutine request_implicit_pond_event(clock,step,old_pond,new_pond,net_rate,soil_rate,deficit,requested)
    real(8),intent(in)::clock,step,old_pond,new_pond,net_rate,soil_rate,deficit
    logical,intent(out)::requested
    real(8)::depletion_rate,target
    requested=.false.
    if(.not.all(ieee_is_finite([clock,step,old_pond,new_pond,net_rate,soil_rate,deficit]))) &
      error stop 'Nonfinite original implicit pond event'
    if(step<=0d0.or.old_pond<0d0.or.new_pond<0d0)error stop 'Invalid original implicit pond event'
    if(old_pond<=1d-10.or.new_pond/=0d0.or.deficit<=1d-10)return
    depletion_rate=-(net_rate+soil_rate)
    if(depletion_rate<=0d0)return
    target=old_pond/depletion_rate
    if(.not.ieee_is_finite(target).or.target<=0d0)error stop 'Invalid original implicit pond event duration'
    if(target>=step)return
    if(target<=8d0*spacing(clock).or.clock+target<=clock) &
      error stop 'Original implicit pond event reached clock resolution'
    if(pending.and.event_clock/=clock)error stop 'Foreign pending original implicit pond clock'
    event_clock=clock;event_step=target;pending=.true.;requested=.true.
    if(clock>=37851d0.and.clock<37852d0.and.trace_count<64)then
      trace_count=trace_count+1
      write(*,'(a,*(1x,es25.17e3))')'ACTUAL_POND_REQUEST',clock,step,target,old_pond,new_pond,net_rate,soil_rate,deficit
      flush(6)
    end if
  end subroutine

  subroutine take_implicit_pond_event(clock,step,taken)
    real(8),intent(in)::clock
    real(8),intent(inout)::step
    logical,intent(out)::taken
    taken=pending
    if(.not.pending)return
    if(clock/=event_clock)error stop 'Foreign original implicit pond retry clock'
    if(clock>=37851d0.and.clock<37852d0.and.trace_count<=64)then
      write(*,'(a,*(1x,es25.17e3))')'ACTUAL_POND_TAKE',clock,step,event_step
      flush(6)
    end if
    step=event_step
    pending=.false.;event_clock=0d0;event_step=0d0
  end subroutine

  subroutine assert_no_implicit_pond_event()
    if(pending.or.event_clock/=0d0.or.event_step/=0d0) &
      error stop 'Unconsumed original implicit pond event at accepted boundary'
  end subroutine
end module
