program test_ppa_wu05_perch19_frreduq_controller
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05_perch19_frreduq_controller
  implicit none

  type(perch19_frreduq_state_t)::committed,candidate,discarded,restarted
  integer::action,i
  real(real64)::retry_dt
  logical::ok

  call require(committed%valid(),'initial state valid')
  call require(abs(committed%factor()-1.0_real64)<1.0e-15_real64,'initial factor one')

  ! Source ordering: above DTMIN, temporal policy owns retry and reduction level is unchanged.
  call perch19_failure_transition(committed,0.002_real64,1.0e-5_real64,0.002_real64, &
       candidate,action,retry_dt,ok)
  call require(ok .and. action==PERCH19_ACTION_REDUCE_TIMESTEP,'temporal retry precedes exchange reduction')
  call require(candidate%same_values(committed),'temporal retry leaves controller state unchanged')

  ! At DTMIN, exact bounded FrReduQ ladder 1 -> 0.1 -> 0.01 -> 0.001.
  call perch19_failure_transition(committed,1.0e-5_real64,1.0e-5_real64,0.002_real64, &
       candidate,action,retry_dt,ok)
  call require(ok .and. action==PERCH19_ACTION_RETRY_REDUCED_EXCHANGE,'level one retry')
  call require(candidate%reduction_level==1 .and. abs(candidate%factor()-0.1_real64)<1.0e-15_real64,'factor 0.1')
  call require(abs(retry_dt-sqrt(2.0e-8_real64))<1.0e-15_real64,'source retry dt sqrt min max')

  committed=candidate
  call perch19_failure_transition(committed,1.0e-5_real64,1.0e-5_real64,0.002_real64, &
       candidate,action,retry_dt,ok)
  call require(ok .and. candidate%reduction_level==2 .and. &
       abs(candidate%factor()-0.01_real64)<1.0e-15_real64,'factor 0.01')

  committed=candidate
  call perch19_failure_transition(committed,1.0e-5_real64,1.0e-5_real64,0.002_real64, &
       candidate,action,retry_dt,ok)
  call require(ok .and. candidate%reduction_level==3 .and. &
       abs(candidate%factor()-0.001_real64)<1.0e-15_real64,'factor 0.001')

  committed=candidate
  call perch19_failure_transition(committed,1.0e-5_real64,1.0e-5_real64,0.002_real64, &
       candidate,action,retry_dt,ok)
  call require(ok .and. action==PERCH19_ACTION_TERMINAL_FAILURE,'terminal after level three')
  call require(candidate%same_values(committed),'terminal failure no hidden mutation')

  ! Rejected trial isolation: candidate transition is disposable until commit.
  committed=perch19_frreduq_state_t()
  call perch19_failure_transition(committed,1.0e-5_real64,1.0e-5_real64,0.002_real64, &
       candidate,action,retry_dt,ok)
  discarded=candidate
  call require(committed%reduction_level==0,'rejected candidate cannot mutate committed controller')
  candidate=committed
  call require(candidate%reduction_level==0,'discard restores accepted controller authority')
  restarted=discarded
  call require(restarted%same_values(discarded),'controller payload restart roundtrip')

  ! Source recovery: ten accepted steps at unchanged dt lower the level by one.
  committed=perch19_frreduq_state_t(reduction_level=2,successful_steps=0,previous_reduction_dt=1.0e-5_real64)
  do i=1,9
    call perch19_success_transition(committed,1.0e-5_real64,candidate,ok)
    call require(ok,'success transition valid')
    committed=candidate
    call require(committed%reduction_level==2,'no early ten-step recovery')
  end do
  call perch19_success_transition(committed,1.0e-5_real64,candidate,ok)
  call require(ok .and. candidate%reduction_level==1 .and. candidate%successful_steps==0,'ten-step recovery')

  ! Source recovery: a successful larger dt immediately lowers one level.
  committed=perch19_frreduq_state_t(reduction_level=2,successful_steps=3,previous_reduction_dt=1.0e-5_real64)
  call perch19_success_transition(committed,2.0e-5_real64,candidate,ok)
  call require(ok .and. candidate%reduction_level==1 .and. candidate%successful_steps==0,'larger-dt recovery')
  call require(abs(candidate%previous_reduction_dt-2.0e-5_real64)<1.0e-15_real64,'recovery dt memory')

  print '(a)', 'PPA_WU05_PERCH19_TEMPORAL_ORDERING=PASS'
  print '(a)', 'PPA_WU05_PERCH19_REDUCTION_LADDER=PASS'
  print '(a)', 'PPA_WU05_PERCH19_REJECT_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH19_RESTART_PAYLOAD=PASS'
  print '(a)', 'PPA_WU05_PERCH19_RECOVERY_RULE=PASS'
  print '(a)', 'PPA_WU05_PERCH19_CONTROLLER_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)')'PPA_WU05_PERCH19_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu05_perch19_frreduq_controller
