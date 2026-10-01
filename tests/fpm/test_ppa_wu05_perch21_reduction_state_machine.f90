program test_ppa_wu05_perch21_reduction_state_machine
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_macropore_reduction_continuation, only: macropore_reduction_continuation_t, &
       initialize_macropore_reduction_continuation, propose_macropore_reduction_escalation, &
       propose_macropore_reduction_acceptance
  implicit none

  type(macropore_reduction_continuation_t) :: committed,candidate,snapshot
  real(real64) :: retry_dt
  logical :: ok,available,recovered
  integer :: i

  call initialize_macropore_reduction_continuation(committed,0.03_real64,ok)
  call require(ok,'initial continuation initialized')
  call require(committed%ready(),'initial continuation ready')
  call require(committed%reduction_level==0,'initial level zero')
  call require(committed%accepted_step_count==0,'initial accepted count zero')
  call require(abs(committed%factor()-1.0_real64)<1.0e-15_real64,'factor level zero')

  snapshot=committed
  call propose_macropore_reduction_escalation(committed,0.001_real64,0.001_real64,0.09_real64, &
       candidate,retry_dt,available)
  call require(available,'level one escalation available')
  call require(candidate%reduction_level==1,'level one')
  call require(abs(candidate%factor()-0.1_real64)<1.0e-15_real64,'factor level one')
  call require(abs(retry_dt-0.009486832980505138_real64)<1.0e-15_real64,'geometric mean retry dt')
  call require(committed%same_values(snapshot),'escalation leaves committed untouched')

  committed=candidate
  call propose_macropore_reduction_escalation(committed,0.001_real64,0.001_real64,0.09_real64, &
       candidate,retry_dt,available)
  call require(available .and. candidate%reduction_level==2,'level two')
  call require(abs(candidate%factor()-0.01_real64)<1.0e-15_real64,'factor level two')
  committed=candidate
  call propose_macropore_reduction_escalation(committed,0.001_real64,0.001_real64,0.09_real64, &
       candidate,retry_dt,available)
  call require(available .and. candidate%reduction_level==3,'level three')
  call require(abs(candidate%factor()-0.001_real64)<1.0e-15_real64,'factor level three')
  committed=candidate
  call propose_macropore_reduction_escalation(committed,0.001_real64,0.001_real64,0.09_real64, &
       candidate,retry_dt,available)
  call require(.not.available,'bounded level three escalation')

  call initialize_macropore_reduction_continuation(committed,0.001_real64,ok)
  call propose_macropore_reduction_escalation(committed,0.001_real64,0.001_real64,0.09_real64, &
       candidate,retry_dt,available)
  call require(available,'recovery fixture escalation')
  committed=candidate

  do i=1,9
    snapshot=committed
    call propose_macropore_reduction_acceptance(committed,0.001_real64,candidate,recovered,ok)
    call require(ok .and. .not.recovered,'no early ten-step recovery')
    call require(candidate%reduction_level==1,'level retained before ten')
    call require(candidate%accepted_step_count==i,'accepted step count increments')
    call require(committed%same_values(snapshot),'acceptance leaves committed input untouched')
    committed=candidate
  end do

  call propose_macropore_reduction_acceptance(committed,0.001_real64,candidate,recovered,ok)
  call require(ok .and. recovered,'ten-step recovery')
  call require(candidate%reduction_level==0,'ten-step level recovery')
  call require(candidate%accepted_step_count==0,'ten-step counter reset')

  call initialize_macropore_reduction_continuation(committed,0.001_real64,ok)
  call propose_macropore_reduction_escalation(committed,0.001_real64,0.001_real64,0.09_real64, &
       candidate,retry_dt,available)
  committed=candidate
  call propose_macropore_reduction_acceptance(committed,0.002_real64,candidate,recovered,ok)
  call require(ok .and. recovered,'larger-dt immediate recovery')
  call require(candidate%reduction_level==0,'larger-dt recovered level')
  call require(candidate%accepted_step_count==0,'larger-dt counter reset')
  call require(abs(candidate%recovery_dt-0.002_real64)<1.0e-15_real64,'larger-dt recovery dt update')

  call initialize_macropore_reduction_continuation(committed,0.03_real64,ok)
  call propose_macropore_reduction_acceptance(committed,0.06_real64,candidate,recovered,ok)
  call require(ok .and. .not.recovered,'level-zero acceptance no recovery')
  call require(candidate%reduction_level==0 .and. candidate%accepted_step_count==0,'level-zero unchanged')

  print '(a)', 'PPA_WU05_PERCH21_PURE_FACTOR_LADDER=PASS'
  print '(a)', 'PPA_WU05_PERCH21_PURE_ESCALATION=PASS'
  print '(a)', 'PPA_WU05_PERCH21_PURE_TEN_STEP_RECOVERY=PASS'
  print '(a)', 'PPA_WU05_PERCH21_PURE_DT_INCREASE_RECOVERY=PASS'
  print '(a)', 'PPA_WU05_PERCH21_PURE_COMMITTED_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH21_PURE_STATE_MACHINE_GATE=PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH21_PURE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05_perch21_reduction_state_machine
