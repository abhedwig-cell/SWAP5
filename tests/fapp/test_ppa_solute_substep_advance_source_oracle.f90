program test_ppa_solute_substep_advance_source_oracle
  use,intrinsic::iso_fortran_env,only:real64,int64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_ppa_solute_substep_advance
  implicit none
  integer,parameter::vector_count=100000
  integer(int64)::state
  integer::i,status,source_count,actual_count
  real(real64)::interval,dtmin,candidate,source_elapsed,actual_elapsed,elapsed_input,source_step,actual_step
  real(real64)::nan_value
  logical::source_continue,actual_continue

  state=20260923_int64
  do i=1,vector_count
    interval=0.01_real64+1.99_real64*next_unit(state)
    dtmin=1.0e-7_real64+1.0e-3_real64*next_unit(state)
    candidate=1.0e-7_real64+0.35_real64*next_unit(state)
    source_elapsed=0.0_real64
    actual_elapsed=0.0_real64
    source_count=0
    actual_count=0
    do while((interval-source_elapsed)>1.0e-15_real64)
      source_step=min(candidate,(interval-source_elapsed))
      source_step=max(source_step,dtmin)
      source_elapsed=source_elapsed+source_step
      source_count=source_count+1
      elapsed_input=actual_elapsed
      call ppa_solute_substep_advance(interval,dtmin,candidate,elapsed_input,actual_step, &
           actual_elapsed,actual_continue,status)
      call require(status==PPA_SOLUTE_SUBSTEP_OK,1)
      call compare_real(source_step,actual_step,2)
      call compare_real(source_elapsed,actual_elapsed,3)
      source_continue=(interval-source_elapsed)>1.0e-15_real64
      call require(source_continue.eqv.actual_continue,4)
      actual_count=actual_count+1
    end do
    call require(source_count==actual_count,5)
  end do
  print '(A)','PPA_SOLUTE_SUBSTEP_ADVANCE_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_SOLUTE_SUBSTEP_LOOP_ORDER_AND_STRICT_REMAINDER_GATE=PASS'
  print '(A)','PPA_SOLUTE_SUBSTEP_MINIMUM_STEP_FINAL_OVERSHOOT=PASS'

  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call ppa_solute_substep_advance(1.0_real64,1.0e-6_real64,nan_value,0.0_real64, &
       actual_step,actual_elapsed,actual_continue,status)
  call require(status==PPA_SOLUTE_SUBSTEP_INVALID_INPUT,6)
  call ppa_solute_substep_advance(1.0_real64,1.0e-300_real64,1.0e-300_real64,0.5_real64, &
       actual_step,actual_elapsed,actual_continue,status)
  call require(status==PPA_SOLUTE_SUBSTEP_NO_PROGRESS,7)
  call compare_real(actual_step,0.0_real64,8)
  call compare_real(actual_elapsed,0.5_real64,9)
  call require(.not.actual_continue,10)
  call ppa_solute_substep_advance(huge(1.0_real64),huge(1.0_real64),huge(1.0_real64), &
       0.75_real64*huge(1.0_real64),actual_step,actual_elapsed,actual_continue,status)
  call require(status==PPA_SOLUTE_SUBSTEP_INVALID_INPUT,11)
  call compare_real(actual_step,0.0_real64,12)
  print '(A)','PPA_SOLUTE_SUBSTEP_INVALID_NO_PROGRESS_AND_OVERFLOW_FAIL_CLOSED=PASS'
contains
  real(real64) function next_unit(random_state)result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit
  subroutine compare_real(a,b,code)
    real(real64),intent(in)::a,b
    integer,intent(in)::code
    integer(int64)::ab,bb
    ab=transfer(a,ab);bb=transfer(b,bb)
    call require(ab==bb,code)
  end subroutine compare_real
  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_SOLUTE_SUBSTEP_ADVANCE_FAIL=',code
    error stop 1
  end subroutine require
end program test_ppa_solute_substep_advance_source_oracle
