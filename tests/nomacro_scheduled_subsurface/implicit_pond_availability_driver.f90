program actual_pond_availability_contract
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use hybrid_implicit_pond_availability,only:close_implicit_pond_evaporation
  implicit none
  real(8)::step,old_pond,new_pond,epd,deficit,cap,other,closure
  logical::changed
  integer::i
  character(100)::arg,mode
  call get_command_argument(1,mode)
  do i=2,6
    call get_command_argument(i,arg)
    select case(i)
    case(2);read(arg,*)step
    case(3);read(arg,*)old_pond
    case(4);read(arg,*)new_pond
    case(5);read(arg,*)epd
    case(6);read(arg,*)deficit
    end select
  end do
  cap=huge(1d0);other=huge(1d0)
  select case(trim(mode))
  case('dry');old_pond=0d0
  case('filled');new_pond=0.1d0
  case('no-deficit');deficit=0d0
  case('no-evaporation');epd=0d0
  case('unavailable');deficit=2d0*step*epd
  case('nan-stop');step=ieee_value(step,ieee_quiet_nan)
  case('zero-stop');step=0d0
  case('negative-stop');old_pond=-1d0
  case('cap-stop');cap=-1d0
  end select
  call close_implicit_pond_evaporation(step,old_pond,new_pond,epd,deficit,cap,changed)
  if(trim(mode)=='valid')then
    if(.not.changed.or.cap<0d0.or.cap>=epd)error stop 'Actual pond availability cap missing'
    closure=deficit+(cap-epd)*step
    if(abs(closure)>1d-10)error stop 'Actual original pond availability does not close conservation'
    call close_implicit_pond_evaporation(step,old_pond,new_pond,epd,deficit,other,changed)
    if(.not.changed.or.other/=cap)error stop 'Crossed private availability inputs'
    call close_implicit_pond_evaporation(step,old_pond,new_pond,cap,closure,other,changed)
    if(changed.or.other/=cap)error stop 'Closed actual availability was changed'
    write(*,'(a,*(1x,es25.17e3))')'REAL_ORIGINAL_POND_AVAILABILITY_PASS',cap,closure
  else
    if(changed.or.cap/=huge(1d0))error stop 'Inactive actual pond availability changed cap'
    write(*,'(a)')'REAL_ORIGINAL_POND_AVAILABILITY_INACTIVE_PASS'
  end if
end program
