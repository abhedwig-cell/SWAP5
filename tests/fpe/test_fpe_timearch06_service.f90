program test_fpe_timearch06_service
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_timestep_decision_service
  implicit none
  type(b1_10_timestep_decision_t) :: d
  real(real64), parameter :: tol=1.0e-14_real64
  integer :: failures
  failures=0

  d=b1_10_legacy_accepted_step_decision(0.01_real64,0.001_real64,0.02_real64,2,4,8,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.02_real64,'grow dt')
  call req_int(d%reason,B110_TS_REASON_GROW_LOW_ITER,'grow reason')

  d=b1_10_legacy_accepted_step_decision(0.01_real64,0.001_real64,0.02_real64,5,4,8,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.01_real64,'keep dt')
  call req_int(d%reason,B110_TS_REASON_KEEP,'keep reason')

  d=b1_10_legacy_accepted_step_decision(0.01_real64,0.001_real64,0.02_real64,8,4,8,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.005_real64,'shrink dt')
  call req_int(d%reason,B110_TS_REASON_SHRINK_MAX_ITER,'shrink reason')

  d=b1_10_legacy_accepted_step_decision(0.018_real64,0.001_real64,0.02_real64,1,4,8,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.02_real64,'dtmax ceiling')

  d=b1_10_legacy_accepted_step_decision(0.002_real64,0.001_real64,0.02_real64,8,4,8,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.001_real64,'dtmin floor')

  d=b1_10_legacy_accepted_step_decision(0.01_real64,0.001_real64,0.02_real64,4,8,4,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.01_real64,'grow-shrink order')
  call req_int(d%reason,B110_TS_REASON_GROW_THEN_SHRINK,'grow-shrink reason')

  d=b1_10_legacy_accepted_step_decision(0.0005_real64,0.001_real64,0.02_real64,5,4,8,2.0_real64,0.5_real64)
  call req_real(d%preferred_dt,0.001_real64,'safety floor')
  call req_logical(d%floor_reached,'safety floor flag')

  d=b1_10_legacy_solver_retry_decision(0.02_real64,0.001_real64,2.0_real64)
  call req_real(d%preferred_dt,0.01_real64,'retry reduction')
  call req_int(d%reason,B110_TS_REASON_SOLVER_RETRY,'retry reason')

  d=b1_10_legacy_solver_retry_decision(0.002_real64,0.001_real64,2.0_real64)
  call req_real(d%preferred_dt,0.001_real64,'retry floor')
  call req_int(d%reason,B110_TS_REASON_SOLVER_RETRY_FLOOR,'retry floor reason')
  call req_logical(d%floor_reached,'retry floor flag')

  if(failures/=0) then
    write(*,'(A,I0)') 'F_PE_TIMEARCH06_FAILURES=',failures
    error stop 1
  end if
  write(*,'(A)') 'F_PE_TIMEARCH06_SERVICE=PASS'
contains
  subroutine req_real(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    if(abs(a-b)>tol*max(1.0_real64,abs(a),abs(b))) then
      failures=failures+1
      write(*,'(A,1X,A)') 'F_PE_TIMEARCH06_FAIL_REAL',trim(label)
    end if
  end subroutine
  subroutine req_int(a,b,label)
    integer,intent(in)::a,b
    character(len=*),intent(in)::label
    if(a/=b) then
      failures=failures+1
      write(*,'(A,1X,A)') 'F_PE_TIMEARCH06_FAIL_INT',trim(label)
    end if
  end subroutine
  subroutine req_logical(a,label)
    logical,intent(in)::a
    character(len=*),intent(in)::label
    if(.not.a) then
      failures=failures+1
      write(*,'(A,1X,A)') 'F_PE_TIMEARCH06_FAIL_LOGICAL',trim(label)
    end if
  end subroutine
end program test_fpe_timearch06_service
