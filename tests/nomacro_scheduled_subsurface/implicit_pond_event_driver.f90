program real_implicit_pond_event_contract
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use hybrid_implicit_pond_event_state
  implicit none
  character(64)::mode,arg
  real(8)::v(7),step,original_step
  logical::requested,taken
  integer::i
  call get_command_argument(1,mode)
  do i=1,7
    call get_command_argument(i+1,arg);read(arg,*)v(i)
  end do
  original_step=v(2)
  select case(trim(mode))
  case('dry')
    v(3)=0d0
  case('filled')
    v(4)=v(3)
  case('no-deficit')
    v(7)=0d0
  case('nan-stop')
    v(2)=ieee_value(1d0,ieee_quiet_nan)
  case('negative-stop')
    v(3)=-1d0
  case('clock-stop')
    v(3)=2d-10;v(5)=-1d6;v(6)=0d0
  end select
  call assert_no_implicit_pond_event()
  call request_implicit_pond_event(v(1),v(2),v(3),v(4),v(5),v(6),v(7),requested)
  if(trim(mode)=='pending-stop')then
    call assert_no_implicit_pond_event()
    error stop 'Pending accepted-state event not refused'
  end if
  step=v(2)
  if(trim(mode)=='foreign-clock')v(1)=v(1)+1d0
  call take_implicit_pond_event(v(1),step,taken)
  if(trim(mode)=='valid')then
    if(.not.requested.or..not.taken.or.step<=0d0.or.step>=original_step.or.v(1)+step<=v(1)) &
      error stop 'Invalid actual depletion-event ownership or advancing cap'
    if(abs(v(3)+(v(5)+v(6))*step)>1d-10)error stop 'Actual original pond event does not close boundary inventory'
    call assert_no_implicit_pond_event()
    call take_implicit_pond_event(v(1),step,taken)
    if(taken)error stop 'Original pond event replayed after consumption'
    write(*,'(a,1x,es25.17e3)')'REAL_IMPLICIT_POND_EVENT_PASS',step
  else if(trim(mode)=='dry'.or.trim(mode)=='filled'.or.trim(mode)=='no-deficit')then
    if(requested.or.taken.or.step/=original_step)error stop 'Inactive event changed original step'
    call assert_no_implicit_pond_event()
    write(*,'(a)')'REAL_IMPLICIT_POND_INACTIVE_PASS'
  else
    error stop 'Invalid event refusal missing'
  end if
end program
