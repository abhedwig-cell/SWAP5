program test_ppa_wu05_perch20_numerical_continuation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_macropore_reduction_state_t, fmr_macropore_reduction_continuation_t
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_ppa_wu05_perch19_frreduq_controller, only: PERCH19_ACTION_REDUCE_TIMESTEP, &
       PERCH19_ACTION_RETRY_REDUCED_EXCHANGE
  use mod_ppa_wu05_perch20_continuation_binding, only: perch20_failure_transition, perch20_success_transition
  implicit none

  type(fmr_template_t)::template
  type(fmr_b110_macropore_reduction_state_t)::state
  type(fmr_macropore_reduction_continuation_t)::accepted_controller,candidate_controller
  class(transaction_state_t),allocatable::copy
  logical :: template_ok,transition_ok
  integer :: action
  real(real64) :: retry_dt

  state%active_nodes=2
  allocate(state%pressure_head(2),state%water_content(2),state%macropore)
  state%pressure_head=[-1.0_real64,-2.0_real64]
  state%water_content=[0.3_real64,0.31_real64]
  call state%macropore%initialize(1,2,template_ok)
  call require(template_ok,'macro state initialized')
  state%macropore_reduction%reduction_level=2
  state%macropore_reduction%successful_steps=7
  state%macropore_reduction%previous_reduction_dt=0.125_real64

  template%template_id=520001_int64
  template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION

  call require(state%macropore_reduction%valid(),'payload valid')
  call require(abs(state%macropore_reduction%factor()-0.01_real64)<1.0e-15_real64,'factor derived')
  call require(fmr_restart_state_matches_template(state,template),'typed restart matches')

  call state%clone(copy)
  select type(typed=>copy)
  type is(fmr_b110_macropore_reduction_state_t)
    call require(typed%macropore_reduction%reduction_level==2,'clone level')
    call require(typed%macropore_reduction%successful_steps==7,'clone successful steps')
    call require(typed%macropore_reduction%previous_reduction_dt==0.125_real64,'clone dtold')
    call require(allocated(typed%macropore),'clone physical macro allocated')
  class default
    error stop 'PERCH20 clone type'
  end select

  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  call require(.not.fmr_restart_state_matches_template(state,template),'NONE rejects continuation carrier')
  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  call require(.not.fmr_restart_state_matches_template(state,template),'temporal layout rejects continuation carrier')
  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION

  state%macropore_reduction%reduction_level=4
  call require(.not.state%macropore_reduction%valid(),'invalid level rejected')
  call require(.not.fmr_restart_state_matches_template(state,template),'invalid payload restart rejected')

  accepted_controller=fmr_macropore_reduction_continuation_t()
  call perch20_failure_transition(accepted_controller,0.01_real64,0.001_real64,0.1_real64, &
       candidate_controller,action,retry_dt,transition_ok)
  call require(transition_ok .and. action==PERCH19_ACTION_REDUCE_TIMESTEP,'temporal precedence')
  call require(candidate_controller%reduction_level==0,'temporal retry leaves accepted level')

  call perch20_failure_transition(accepted_controller,0.001_real64,0.001_real64,0.1_real64, &
       candidate_controller,action,retry_dt,transition_ok)
  call require(transition_ok .and. action==PERCH19_ACTION_RETRY_REDUCED_EXCHANGE,'reduction transition')
  call require(candidate_controller%reduction_level==1,'candidate reduction level')
  call require(accepted_controller%reduction_level==0,'accepted controller unchanged on candidate retry')
  call require(abs(retry_dt-0.01_real64)<1.0e-15_real64,'source retry dt')

  accepted_controller=candidate_controller
  accepted_controller%successful_steps=9
  call perch20_success_transition(accepted_controller,0.001_real64,candidate_controller,transition_ok)
  call require(transition_ok .and. candidate_controller%reduction_level==0,'ten-step recovery')
  call require(candidate_controller%successful_steps==0,'recovery counter reset')

  print '(a)', 'PPA_WU05_PERCH20_LAYOUT_IDENTITY=PASS'
  print '(a)', 'PPA_WU05_PERCH20_CLONE_PAYLOAD=PASS'
  print '(a)', 'PPA_WU05_PERCH20_RESTART_MATCH=PASS'
  print '(a)', 'PPA_WU05_PERCH20_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU05_PERCH20_CONTROLLER_BINDING=PASS'
  print '(a)', 'PPA_WU05_PERCH20_REJECT_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH20_CARRIER_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH20_FAIL',trim(label)
      error stop 20
    end if
  end subroutine require
end program test_ppa_wu05_perch20_numerical_continuation
