program real_original_implicit_retry_contract
  use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use MOD_swap_base,only:swmacro
  use MOD_grid,only:numnod
  use variables,only:swkimpl,dt,dtmin,t1900,fldecdt,fldtmin,fact_dt_fldect,h,theta,pond
  implicit none
  character(32)::mode
  real(8)::old_dt,stock(5)
  integer::count
  call get_command_argument(1,mode)
  swmacro=0;swkimpl=1;fact_dt_fldect=2d0;dtmin=1d-6;t1900=37256d0
  numnod=2;h(1:2)=[-10d0,-20d0];theta(1:2)=[.2d0,.3d0];pond=.1d0
  stock=[h(1:2),theta(1:2),pond];fldecdt=.true.;fldtmin=.true.;dt=dtmin
  select case(trim(mode))
  case('clock-stop')
    dt=4d0*spacing(t1900)
    call TimeControl(5)
    error stop 'Clock-resolution refusal missing'
  case('nan-stop')
    dt=ieee_value(1d0,ieee_quiet_nan)
    call TimeControl(5)
    error stop 'Nonfinite original trial refusal missing'
  case('zero-stop')
    dt=0d0
    call TimeControl(5)
    error stop 'Nonpositive original trial refusal missing'
  end select
  count=0
  ! Exact original0 minimum behavior remains available.
  swkimpl=0;call TimeControl(5)
  if(dt/=dtmin.or.fldecdt.or..not.fldtmin)error stop 'Original0 retry changed'
  count=count+1
  swkimpl=1;dt=dtmin;fldecdt=.true.
  call TimeControl(5)
  if(dt/=dtmin/fact_dt_fldect.or.fldecdt.or..not.fldtmin)error stop 'Actual minimum retry failed'
  count=count+1
  dt=dtmin/128d0;old_dt=dt;fldecdt=.true.
  call TimeControl(5)
  if(dt/=old_dt/fact_dt_fldect.or.t1900+dt<=t1900.or.fldecdt)error stop 'Advancing below-minimum retry failed'
  count=count+1
  dt=1d-4;old_dt=dt;fldecdt=.true.
  call TimeControl(5)
  if(dt/=old_dt/fact_dt_fldect.or.fldtmin.or.fldecdt)error stop 'Original factor above minimum changed'
  count=count+1
  old_dt=dt;call TimeControl(5)
  if(dt/=old_dt)error stop 'Retry without nonconvergence requested'
  count=count+1
  if(t1900/=37256d0.or.any(stock/=[h(1:2),theta(1:2),pond]))error stop 'Numerical retry changed physical state or clock'
  write(*,'(a,1x,i0)')'REAL_ORIGINAL_IMPLICIT_RETRY_PASS',count
end program
