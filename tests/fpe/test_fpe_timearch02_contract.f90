program test_fpe_timearch02_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fpe_timearch02_contract
  implicit none
  type(timestep_decision_t)::d,p
  real(real64),parameter::tol=1.0e-14_real64

  d=legacy_accepted_proposal(0.01_real64,0.001_real64,0.02_real64,2,4,8,2.0_real64,0.5_real64)
  call eq(d%preferred_dt,0.02_real64,1); call ieq(d%proposal_reason,TS_REASON_GROW_LOW_ITER,2)

  d=legacy_accepted_proposal(0.01_real64,0.001_real64,0.02_real64,5,4,8,2.0_real64,0.5_real64)
  call eq(d%preferred_dt,0.01_real64,3); call ieq(d%proposal_reason,TS_REASON_KEEP,4)

  d=legacy_accepted_proposal(0.01_real64,0.001_real64,0.02_real64,8,4,8,2.0_real64,0.5_real64)
  call eq(d%preferred_dt,0.005_real64,5); call ieq(d%proposal_reason,TS_REASON_SHRINK_MAX_ITER,6)

  d=legacy_accepted_proposal(0.018_real64,0.001_real64,0.02_real64,1,4,8,2.0_real64,0.5_real64)
  call eq(d%preferred_dt,0.02_real64,7)

  d=legacy_accepted_proposal(0.002_real64,0.001_real64,0.02_real64,8,4,8,2.0_real64,0.5_real64)
  call eq(d%preferred_dt,0.001_real64,8)

  d=legacy_accepted_proposal(0.01_real64,0.001_real64,0.02_real64,4,8,4,2.0_real64,0.5_real64)
  call eq(d%preferred_dt,0.01_real64,9); call ieq(d%proposal_reason,TS_REASON_GROW_THEN_SHRINK,10)

  d=legacy_solver_retry(0.02_real64,0.001_real64,2.0_real64)
  call eq(d%preferred_dt,0.01_real64,11); call ieq(d%proposal_reason,TS_REASON_SOLVER_RETRY,12)

  d=legacy_solver_retry(0.002_real64,0.001_real64,2.0_real64)
  call eq(d%preferred_dt,0.001_real64,13); call require(d%floor_reached,14)

  d=legacy_daystart_floor(0.001_real64,0.001_real64,0.04_real64)
  call eq(d%preferred_dt,sqrt(0.00004_real64),15); call ieq(d%proposal_reason,TS_REASON_DAYSTART_COMPAT_FLOOR,16)

  d=legacy_daystart_floor(0.01_real64,0.001_real64,0.04_real64)
  call eq(d%preferred_dt,0.01_real64,17); call ieq(d%proposal_reason,TS_REASON_KEEP,18)

  d=compose_executable_dt(0.02_real64,0.007_real64,.false.,1.0_real64)
  call eq(d%executed_dt,0.007_real64,19); call ieq(d%limiting_reason,TS_REASON_HARD_EVENT_CLAMP,20)

  d=compose_executable_dt(0.02_real64,0.018_real64,.true.,0.006_real64)
  call eq(d%executed_dt,0.006_real64,21); call ieq(d%limiting_reason,TS_REASON_EXTERNAL_INTERVAL_CLAMP,22)

  p=legacy_accepted_proposal(0.01_real64,0.001_real64,0.04_real64,2,4,8,2.0_real64,0.5_real64)
  d=compose_executable_dt(p%preferred_dt,0.012_real64,.false.,1.0_real64)
  call eq(p%preferred_dt,0.02_real64,23)
  call eq(d%executed_dt,0.012_real64,24)
  call ieq(p%proposal_reason,TS_REASON_GROW_LOW_ITER,25)
  call ieq(d%limiting_reason,TS_REASON_HARD_EVENT_CLAMP,26)

  p=legacy_accepted_proposal(0.01_real64,0.001_real64,0.02_real64,2,4,8,2.0_real64,0.5_real64)
  d=legacy_solver_retry(0.01_real64,0.001_real64,2.0_real64)
  call eq(p%preferred_dt,0.02_real64,27)
  call eq(d%preferred_dt,0.005_real64,28)

  write(*,'(A)') 'F_PE_TIMEARCH02_CONTRACT=PASS'

contains
  subroutine eq(a,b,n)
    real(real64),intent(in)::a,b
    integer,intent(in)::n
    if(abs(a-b)>tol*max(1.0_real64,abs(a),abs(b))) error stop n
  end subroutine
  subroutine ieq(a,b,n)
    integer,intent(in)::a,b,n
    if(a/=b) error stop n
  end subroutine
  subroutine require(x,n)
    logical,intent(in)::x
    integer,intent(in)::n
    if(.not.x) error stop n
  end subroutine
end program test_fpe_timearch02_contract
