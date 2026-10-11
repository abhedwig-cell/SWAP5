program test_fci12_reference_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state
  use mod_b1_10_reference_model, only: b1_10_reference_model_t
  use mod_b1_10_temporal_characterization, only: b1_10_temporal_characterization_t, characterize_b1_10_temporal_difference
  use fci12_backend_globals
  use MOD_swap_base, only: swsnow
  implicit none
  type(b1_10_reference_model_t) :: model
  type(a23bu_worker_context_t), target :: worker
  class(transaction_state_t), allocatable :: state, before, half
  type(trial_outcome_t) :: outcome
  type(b1_10_temporal_characterization_t) :: delta
  real(real64) :: s0,s1,terr_probe
  character(len=64) :: mode

  call seed_backend()
  allocate(b1_10_process_state_t :: state)
  select type(p=>state)
  type is(b1_10_process_state_t)
    call capture_b1_10_process_state(p)
  end select
  call model%bind_worker(worker)

  if(.not.model%capabilities%generic_interval_advance) error stop 'FCI12 generic advance not enabled'
  if(.not.model%capabilities%trial_mass_flux_contract) error stop 'FCI12 mass flux not enabled'
  if(.not.model%capabilities%mass_storage_contract) error stop 'FCI12 storage not enabled'
  if(model%capabilities%temporal_error_contract) error stop 'FCI12 scalar temporal must stay disabled'
  if(.not.model%reference_capabilities%physical_interval_binding) error stop 'FCI12 interval capability missing'
  if(model%reference_capabilities%recoverable_solver_failure_status) error stop 'FCI12 recoverable solver failure incorrectly admitted'
  if(model%reference_execution_admitted()) error stop 'FCI12 reference execution must remain blocked'

  s0=model%storage(state)
  call model%advance(state,10.25_real64,10.75_real64,outcome)
  if(.not.outcome%solver_ok) error stop 'FCI12 successful advance rejected'
  if(abs(outcome%mass_in-0.625_real64)>1e-14_real64) error stop 'FCI12 mass in'
  if(abs(outcome%mass_out-0.125_real64)>1e-14_real64) error stop 'FCI12 mass out'
  if(outcome%headcalc_calls/=2.or.outcome%nonlinear_iterations/=3) error stop 'FCI12 diagnostics'
  s1=model%storage(state)
  if(abs((s1-s0)-(outcome%mass_in-outcome%mass_out))>1e-14_real64) error stop 'FCI12 mass closure'

  call state%clone(before)
  fail_mode=.true.
  call model%advance(state,10.75_real64,11.0_real64,outcome)
  if(outcome%solver_ok) error stop 'FCI12 failed stub trial accepted'
  select type(p=>state)
  type is(b1_10_process_state_t)
    select type(q=>before)
    type is(b1_10_process_state_t)
      if(maxval(abs(p%h-q%h))>0.0_real64.or.abs(p%volact-q%volact)>0.0_real64) error stop 'FCI12 failed trial mutated state'
      if(maxval(abs(h-q%h))>0.0_real64.or.abs(volact-q%volact)>0.0_real64) error stop 'FCI12 failed trial leaked backend state'
    end select
  end select
  fail_mode=.false.

  call state%clone(half)
  select type(q=>half)
  type is(b1_10_process_state_t)
    q%h(2)=q%h(2)+0.0125_real64
    q%theta(1)=q%theta(1)+0.002_real64
    q%pond=q%pond+0.03_real64
  end select
  select type(p=>state)
  type is(b1_10_process_state_t)
    select type(q=>half)
    type is(b1_10_process_state_t)
      call characterize_b1_10_temporal_difference(p,q,delta)
      if(.not.delta%compatible.or..not.delta%process_scope_complete) error stop 'FCI12 water characterization incomplete'
      if(abs(delta%max_abs_h_cm-0.0125_real64)>1e-14_real64) error stop 'FCI12 head characterization'
      if(abs(delta%max_abs_theta-0.002_real64)>1e-14_real64) error stop 'FCI12 theta characterization'
      if(abs(delta%abs_pond_cm-0.03_real64)>1e-14_real64) error stop 'FCI12 pond characterization'
      allocate(q%crop)
      call characterize_b1_10_temporal_difference(p,q,delta)
      if(delta%compatible) error stop 'FCI12 allocation mismatch should be incompatible'
      if(delta%allocation_mismatches/=1) error stop 'FCI12 allocation mismatch count'
    end select
  end select

  mode='';call get_command_argument(1,mode)
  if(trim(mode)=='temporal-negative') then
    terr_probe=model%temporal_error(state,before)
    print *,terr_probe
    error stop 'FCI12 temporal negative unexpectedly returned'
  end if
  if(trim(mode)=='storage-negative') then
    swsnow=1
    s0=model%storage(state)
    print *,s0
    error stop 'FCI12 storage negative unexpectedly returned'
  end if

  print *, 'FCI12_REFERENCE_MODEL PASS'
end program
