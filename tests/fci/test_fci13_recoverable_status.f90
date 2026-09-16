program test_fci13_recoverable_status
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
  use mod_b1_10_trial_status, only: b1_10_trial_status_t, &
       B1_10_TRIAL_REASON_INVALID_INTERVAL, B1_10_TRIAL_REASON_INTERVAL_NOT_PREPARED
  use mod_b1_10_recoverable_interval_executor, only: run_b1_10_recoverable_interval
  use mod_b1_10_recoverable_reference_model, only: b1_10_recoverable_reference_model_t
  use fci13_backend_globals
  implicit none

  type(b1_10_recoverable_reference_model_t) :: model
  type(a23bu_worker_context_t), target :: worker
  class(transaction_state_t), allocatable :: state, before
  type(trial_outcome_t) :: outcome
  type(b1_10_trial_mass_t) :: mass
  type(b1_10_trial_status_t) :: status
  real(real64) :: terr_probe
  character(len=64) :: mode

  call seed_backend()
  allocate(b1_10_process_state_t :: state)
  select type(p=>state)
  type is(b1_10_process_state_t)
    call capture_b1_10_process_state(p)
  end select
  call model%bind_worker(worker)

  if(.not.model%reference_capabilities%recoverable_solver_failure_status) error stop 'FCI13 recoverable status not admitted'
  if(model%reference_capabilities%scalar_temporal_error_policy) error stop 'FCI13 scalar temporal policy must stay blocked'
  if(model%reference_execution_admitted()) error stop 'FCI13 reference execution must remain blocked'

  call model%advance(state,10.25_real64,10.75_real64,outcome)
  if(.not.outcome%solver_ok) error stop 'FCI13 successful trial rejected'
  if(abs(outcome%mass_in-0.625_real64)>1e-14_real64) error stop 'FCI13 successful mass in'
  if(abs(outcome%mass_out-0.125_real64)>1e-14_real64) error stop 'FCI13 successful mass out'

  call state%clone(before)
  failure_mode=1
  call model%advance(state,10.75_real64,11.0_real64,outcome)
  if(outcome%solver_ok) error stop 'FCI13 terminal nonconvergence accepted'
  if(worker%history%iwarn/=1) error stop 'FCI13 terminal marker not observed'
  select type(p=>state)
  type is(b1_10_process_state_t)
    select type(q=>before)
    type is(b1_10_process_state_t)
      if(maxval(abs(p%h-q%h))>0.0_real64.or.abs(p%volact-q%volact)>0.0_real64) error stop 'FCI13 retryable trial mutated state'
      if(maxval(abs(h-q%h))>0.0_real64.or.abs(volact-q%volact)>0.0_real64) error stop 'FCI13 retryable trial leaked backend state'
    class default
      error stop 'FCI13 clone type'
    end select
  class default
    error stop 'FCI13 state type'
  end select

  failure_mode=0
  call run_b1_10_recoverable_interval(2.0_real64,1.0_real64,worker,mass,status)
  if(.not.status%fatal().or.status%reason/=B1_10_TRIAL_REASON_INVALID_INTERVAL) error stop 'FCI13 invalid interval not fatal'

  failure_mode=2
  call run_b1_10_recoverable_interval(11.0_real64,11.5_real64,worker,mass,status)
  if(.not.status%fatal().or.status%reason/=B1_10_TRIAL_REASON_INTERVAL_NOT_PREPARED) error stop 'FCI13 unprepared interval not fatal'
  failure_mode=0

  mode='';call get_command_argument(1,mode)
  if(trim(mode)=='temporal-negative') then
    terr_probe=model%temporal_error(state,before)
    print *,terr_probe
    error stop 'FCI13 temporal negative unexpectedly returned'
  end if

  print *, 'FCI13_RECOVERABLE_STATUS PASS'
end program
