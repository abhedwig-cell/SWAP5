program test_fpe_timearch07_trace
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_timestep_decision_service, only: b1_10_timestep_trace_t, &
       B110_TS_REASON_GROW_LOW_ITER, B110_TS_REASON_SOLVER_RETRY
  use variables
  use MOD_swap_base
  use plant_interface, only: sw_inter
  use MOD_irrigation, only: dt_irr_event
  implicit none

  interface
    subroutine TimeControl(task, interval, timestep_trace)
      use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
      use mod_b1_10_timestep_decision_service, only: b1_10_timestep_trace_t
      integer, intent(in) :: task
      type(b1_10_interval_seam_t), intent(inout), optional :: interval
      type(b1_10_timestep_trace_t), intent(inout), optional :: timestep_trace
    end subroutine TimeControl
  end interface

  type(b1_10_timestep_trace_t) :: trace_a, trace_b
  integer :: failures

  failures=0
  call seed_common()

  ! Accepted-step growth without event clamp.
  dt=0.01_real64
  tcum=0.20_real64
  t1900=0.20_real64
  t=0.20_real64
  nprintday=1
  numbit=2
  call TimeControl(3,timestep_trace=trace_a)
  call req_logical(trace_a%available,'accepted trace available')
  call req_int(trace_a%sequence,1,'accepted sequence')
  call req_real(trace_a%input_dt,0.01_real64,'accepted input dt')
  call req_real(trace_a%preferred_dt,0.02_real64,'accepted preferred dt')
  call req_real(trace_a%executed_dt,0.02_real64,'accepted executed dt')
  call req_int(trace_a%reason,B110_TS_REASON_GROW_LOW_ITER,'accepted reason')
  call req_false(trace_a%event_clipped,'accepted unclipped')

  ! Same numerical decision, now clipped by print-event cadence.
  dt=0.01_real64
  tcum=0.20_real64
  t1900=0.20_real64
  t=0.20_real64
  nprintday=100
  numbit=2
  call TimeControl(3,timestep_trace=trace_a)
  call req_int(trace_a%sequence,2,'event sequence')
  call req_real(trace_a%input_dt,0.01_real64,'event input dt')
  call req_real(trace_a%preferred_dt,0.02_real64,'event preferred dt')
  call req_real(trace_a%executed_dt,0.01_real64,'event executed dt')
  call req_int(trace_a%reason,B110_TS_REASON_GROW_LOW_ITER,'event reason')
  call req_logical(trace_a%event_clipped,'event clipped')

  ! Solver retry is traced independently from accepted-step proposal.
  dt=0.02_real64
  fldecdt=.true.
  call TimeControl(5,timestep_trace=trace_a)
  call req_int(trace_a%sequence,3,'retry sequence')
  call req_real(trace_a%input_dt,0.02_real64,'retry input dt')
  call req_real(trace_a%preferred_dt,0.01_real64,'retry preferred dt')
  call req_real(trace_a%executed_dt,0.01_real64,'retry executed dt')
  call req_int(trace_a%reason,B110_TS_REASON_SOLVER_RETRY,'retry reason')
  call req_false(trace_a%event_clipped,'retry not event clipped')

  ! Independent carriers do not share sequence or values.
  call req_false(trace_b%available,'second trace initially unavailable')
  call req_int(trace_b%sequence,0,'second trace sequence')
  call req_real(trace_b%preferred_dt,0.0_real64,'second trace value')

  if(failures/=0) then
    write(*,'(A,I0)') 'F_PE_TIMEARCH07_FAILURES=',failures
    error stop 1
  end if
  write(*,'(A)') 'F_PE_TIMEARCH07_TRACE=PASS'

contains

  subroutine seed_common()
    swsolve=1
    swmacro=0
    swmetdetail=0
    swrain=0
    swrunon=0
    sw_inter=0
    dt_irr_event=1.0_real64
    dtmin=0.001_real64
    dtmax=0.02_real64
    numbit_crit=4
    maxit=8
    fact_dt_increase=2.0_real64
    fact_dt_decrease=0.5_real64
    fact_dt_fldect=2.0_real64
    msteps=1000
    isteps=0
    flDayStart=.false.
    flDayEnd=.false.
    flRunEnd=.false.
    flprintshort=.false.
    flprintdt=.false.
    tstart=0.0_real64
    tend=100.0_real64
    timjan1=0.0_real64
    outdatint=0.0_real64
    outdat=0.0_real64
  end subroutine seed_common

  subroutine req_real(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    if(abs(a-b)>1.0e-13_real64*max(1.0_real64,abs(a),abs(b))) then
      failures=failures+1
      write(*,'(A,1X,A,2(1X,ES24.16))') 'F_PE_TIMEARCH07_FAIL_REAL',trim(label),a,b
    end if
  end subroutine req_real

  subroutine req_int(a,b,label)
    integer,intent(in)::a,b
    character(len=*),intent(in)::label
    if(a/=b) then
      failures=failures+1
      write(*,'(A,1X,A,2(1X,I0))') 'F_PE_TIMEARCH07_FAIL_INT',trim(label),a,b
    end if
  end subroutine req_int

  subroutine req_logical(a,label)
    logical,intent(in)::a
    character(len=*),intent(in)::label
    if(.not.a) then
      failures=failures+1
      write(*,'(A,1X,A)') 'F_PE_TIMEARCH07_FAIL_TRUE',trim(label)
    end if
  end subroutine req_logical

  subroutine req_false(a,label)
    logical,intent(in)::a
    character(len=*),intent(in)::label
    if(a) then
      failures=failures+1
      write(*,'(A,1X,A)') 'F_PE_TIMEARCH07_FAIL_FALSE',trim(label)
    end if
  end subroutine req_false
end program test_fpe_timearch07_trace
