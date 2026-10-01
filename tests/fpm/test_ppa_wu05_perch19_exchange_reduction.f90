program test_ppa_wu05_perch19_exchange_reduction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05_perch19_exchange_reduction, only: perch19_exchange_reduction_state_t, &
       perch19_exchange_reduction_persistence_t,PERCH19_ACTION_REDUCE_TIMESTEP, &
       PERCH19_ACTION_ESCALATE_AND_RESET_TIMESTEP,PERCH19_ACTION_EXHAUSTED
  implicit none

  type(perch19_exchange_reduction_state_t)::state,checkpoint,restored
  type(perch19_exchange_reduction_persistence_t)::persist
  real(real64),parameter::dtmin=1.0e-5_real64,dtmax=2.0e-3_real64
  real(real64)::next_dt,expected_reset
  integer::action,i
  logical::ok,reduced

  expected_reset=sqrt(dtmin*dtmax)

  call state%initialize(dtmax,ok)
  call require(ok .and. state%reduction_level==0,'initialize')
  call require(abs(state%factor()-1.0_real64)<1.0e-15_real64,'level0 factor')

  checkpoint=state
  call state%on_nonconvergence(.false.,dtmax,dtmin,dtmax,action,next_dt,ok)
  call require(ok .and. action==PERCH19_ACTION_REDUCE_TIMESTEP,'pre-dtmin action')
  call require(state%reduction_level==0,'pre-dtmin no level mutation')
  call require(abs(next_dt-dtmax)<1.0e-15_real64,'pre-dtmin dt owned externally')
  state=checkpoint
  call require(state%reduction_level==0,'rollback state copy')

  call state%on_nonconvergence(.true.,dtmin,dtmin,dtmax,action,next_dt,ok)
  call require(ok .and. action==PERCH19_ACTION_ESCALATE_AND_RESET_TIMESTEP,'level1 escalate')
  call require(state%reduction_level==1 .and. state%recovery_accepted_steps==0,'level1 state')
  call require(abs(state%factor()-0.1_real64)<1.0e-15_real64,'level1 factor')
  call require(abs(next_dt-expected_reset)<1.0e-15_real64,'source sqrt reset')

  checkpoint=state
  call state%on_accept(expected_reset,reduced,ok)
  call require(ok .and. reduced,'larger dt immediate recovery')
  call require(state%reduction_level==0 .and. state%recovery_accepted_steps==0,'recovered level0')

  state=checkpoint
  do i=1,9
    call state%on_accept(dtmin,reduced,ok)
    call require(ok .and. .not.reduced,'equal dt recovery wait')
    call require(state%reduction_level==1,'equal dt level held')
  end do
  call require(state%recovery_accepted_steps==9,'nine accepted steps')
  call state%on_accept(dtmin,reduced,ok)
  call require(ok .and. reduced,'tenth accepted step recovery')
  call require(state%reduction_level==0 .and. state%recovery_accepted_steps==0,'ten-step recovered')

  call state%initialize(dtmin,ok)
  call state%on_nonconvergence(.true.,dtmin,dtmin,dtmax,action,next_dt,ok)
  call state%on_nonconvergence(.true.,dtmin,dtmin,dtmax,action,next_dt,ok)
  call require(state%reduction_level==2 .and. abs(state%factor()-0.01_real64)<1.0e-15_real64,'level2 factor')
  call state%on_nonconvergence(.true.,dtmin,dtmin,dtmax,action,next_dt,ok)
  call require(state%reduction_level==3 .and. abs(state%factor()-0.001_real64)<1.0e-15_real64,'level3 factor')
  call state%on_nonconvergence(.true.,dtmin,dtmin,dtmax,action,next_dt,ok)
  call require(ok .and. action==PERCH19_ACTION_EXHAUSTED,'level3 exhausted')
  call require(state%reduction_level==3,'exhaustion no overflow')

  state%recovery_accepted_steps=7
  state%last_dt=3.5e-5_real64
  call state%export_persistence(persist,ok)
  call require(ok,'persistence export')
  call restored%restore_persistence(persist,ok)
  call require(ok,'persistence restore')
  call require(restored%reduction_level==state%reduction_level,'persist level')
  call require(restored%recovery_accepted_steps==state%recovery_accepted_steps,'persist recovery count')
  call require(abs(restored%last_dt-state%last_dt)<1.0e-15_real64,'persist dtold')
  call require(abs(restored%factor()-state%factor())<1.0e-15_real64,'persist factor')

  persist%reduction_level=4
  call restored%restore_persistence(persist,ok)
  call require(.not.ok .and. .not.restored%valid(),'invalid persistence fail closed')

  print '(a)', 'PPA_WU05_PERCH19_FACTOR_LADDER=PASS'
  print '(a)', 'PPA_WU05_PERCH19_DT_ACTIONS=PASS'
  print '(a)', 'PPA_WU05_PERCH19_RECOVERY=PASS'
  print '(a)', 'PPA_WU05_PERCH19_ROLLBACK=PASS'
  print '(a)', 'PPA_WU05_PERCH19_PERSISTENCE=PASS'
  print '(a)', 'PPA_WU05_PERCH19_STATE_MACHINE_GATE=PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH19_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05_perch19_exchange_reduction
