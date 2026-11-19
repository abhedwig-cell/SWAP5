program test_cde_clock_events
  use hybrid_cde_clock_events
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
  implicit none
  real(8)::dt,limit,tcum,finish,before_dt,before_limit,nan,inf
  integer::status,i
  logical::changed
  nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
  ! Real production event types: two-hour irrigation and the end of the day.
  do i=1,2
    finish=1d0/12d0
    if(i==2)finish=1d0
    tcum=finish-1d0/1440d0-2d-10
    dt=1d0/1440d0;limit=dt
    call close_cde_clock_event(tcum,finish,1d-8,dt,limit,changed,status)
    if(status/=CDE_CLOCK_EVENT_OK.or..not.changed)error stop 'Coincident event not closed'
    if(dt/=finish-tcum.or.limit/=finish-tcum)error stop 'Local event duration differs'
    if(tcum+dt/=finish)error stop 'Local event endpoint differs'
    before_dt=dt;before_limit=limit
    call close_cde_clock_event(tcum,finish,1d-8,dt,limit,changed,status)
    if(status/=CDE_CLOCK_EVENT_OK.or.changed.or.dt/=before_dt.or.limit/=before_limit)error stop 'Closure not idempotent'
  end do
  dt=0.02d0;limit=0.01d0
  call close_cde_clock_event(0d0,0.03d0,1d-8,dt,limit,changed,status)
  if(status/=CDE_CLOCK_EVENT_OK.or.changed.or.dt/=0.02d0.or.limit/=0.01d0)error stop 'Earlier event changed'
  dt=0.02d0;limit=0.03d0
  call close_cde_clock_event(0d0,0.03d0,1d-8,dt,limit,changed,status)
  if(status/=CDE_CLOCK_EVENT_OK.or.changed.or.dt/=0.02d0.or.limit/=0.03d0)error stop 'Noncoincident proposed step changed'
  do i=1,7
    dt=0.01d0;limit=0.02d0;before_dt=dt;before_limit=limit
    select case(i)
    case(1);call close_cde_clock_event(nan,1d0,1d-8,dt,limit,changed,status)
    case(2);call close_cde_clock_event(0d0,inf,1d-8,dt,limit,changed,status)
    case(3);call close_cde_clock_event(0d0,1d0,1d-7,dt,limit,changed,status)
    case(4);call close_cde_clock_event(-1d0,1d0,1d-8,dt,limit,changed,status)
    case(5);call close_cde_clock_event(2d0,1d0,1d-8,dt,limit,changed,status)
    case(6);dt=-1d0;before_dt=dt;call close_cde_clock_event(0d0,1d0,1d-8,dt,limit,changed,status)
    case(7);limit=0d0;before_limit=limit;call close_cde_clock_event(0d0,1d0,1d-8,dt,limit,changed,status)
    end select
    if(status/=CDE_CLOCK_EVENT_INVALID.or.changed.or.dt/=before_dt.or.limit/=before_limit)error stop 'Invalid event call mutated state'
  end do
  print '(a)','ACTUAL_CDE_CLOCK_LOCAL_EVENT_INTERFACE_PASS'
end program
