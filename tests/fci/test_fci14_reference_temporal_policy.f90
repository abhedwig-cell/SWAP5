program test_fci14_reference_temporal_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_ROUTE_TWO_HALF
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state
  use mod_b1_10_temporal_characterization, only: b1_10_temporal_characterization_t, characterize_b1_10_temporal_difference
  use mod_b1_10_reference_temporal_policy, only: b1_10_reference_temporal_limits_t, &
       b1_10_reference_temporal_assessment_t, evaluate_b1_10_reference_temporal, B1_10_TEMP_METRIC_H
  use mod_b1_10_reference_policy_candidate_model, only: b1_10_reference_policy_candidate_model_t
  use fci14_backend_globals, only: seed_backend
  implicit none

  type(b1_10_reference_policy_candidate_model_t) :: model
  type(a23bu_worker_context_t), target :: worker
  type(b1_10_reference_temporal_limits_t) :: limits, zero_limits
  type(b1_10_reference_temporal_assessment_t) :: assessment
  type(b1_10_temporal_characterization_t) :: delta
  type(transaction_policy_t) :: tx_policy
  type(transaction_result_t) :: result
  class(transaction_state_t), allocatable :: state, full, half
  real(real64) :: terr

  if (limits%valid()) error stop 'FCI14 default temporal limits must be invalid'

  limits%h_cm=0.01_real64
  limits%theta=0.01_real64
  limits%pond_cm=0.01_real64
  limits%gwl_cm=0.10_real64
  limits%volact_cm=0.10_real64
  limits%ldwet_cm=0.10_real64
  limits%spev_cm=0.10_real64
  limits%saev_cm=0.10_real64
  if (.not. limits%valid()) error stop 'FCI14 explicit limits invalid'

  call seed_backend()
  allocate(b1_10_process_state_t :: state)
  select type(p=>state)
  type is(b1_10_process_state_t)
    call capture_b1_10_process_state(p)
  end select
  call model%bind_worker(worker)
  call model%bind_temporal_limits(limits)
  if (model%reference_execution_admitted()) error stop 'FCI14 numeric profile must remain unqualified'

  call state%clone(full)
  call state%clone(half)
  select type(q=>half)
  type is(b1_10_process_state_t)
    q%h(1)=q%h(1)+0.005_real64
    q%hm1=q%hm1+999.0_real64
    q%thetm1=q%thetm1+0.5_real64
    q%pondm1=q%pondm1+100.0_real64
    q%gwlm1=q%gwlm1+100.0_real64
  end select
  select type(p=>full)
  type is(b1_10_process_state_t)
    select type(q=>half)
    type is(b1_10_process_state_t)
      call characterize_b1_10_temporal_difference(p,q,delta)
    end select
  end select
  call evaluate_b1_10_reference_temporal(delta, limits, assessment)
  if (.not.assessment%complete .or. .not.assessment%accepted) error stop 'FCI14 lagged diagnostics incorrectly rejected endpoint'
  if (abs(assessment%normalized_error-0.5_real64)>1e-12_real64) error stop 'FCI14 normalized endpoint ratio'
  if (.not.assessment%lagged_continuation_diagnostic_only) error stop 'FCI14 lagged diagnostic marker'

  select type(q=>half)
  type is(b1_10_process_state_t)
    q%h(1)=q%h(1)+0.010_real64
  end select
  select type(p=>full)
  type is(b1_10_process_state_t)
    select type(q=>half)
    type is(b1_10_process_state_t)
      call characterize_b1_10_temporal_difference(p,q,delta)
    end select
  end select
  call evaluate_b1_10_reference_temporal(delta, limits, assessment)
  if (.not.assessment%complete .or. assessment%accepted) error stop 'FCI14 exceedance not rejected'
  if (abs(assessment%normalized_error-1.5_real64)>1e-12_real64) error stop 'FCI14 exceedance ratio'
  if (assessment%limiting_metric/=B1_10_TEMP_METRIC_H) error stop 'FCI14 limiting metric'

  zero_limits=limits
  zero_limits%h_cm=0.0_real64
  call evaluate_b1_10_reference_temporal(delta, zero_limits, assessment)
  if (assessment%accepted) error stop 'FCI14 zero tolerance must require exact equality'

  select type(q=>half)
  type is(b1_10_process_state_t)
    allocate(q%crop)
  end select
  select type(p=>full)
  type is(b1_10_process_state_t)
    select type(q=>half)
    type is(b1_10_process_state_t)
      call characterize_b1_10_temporal_difference(p,q,delta)
    end select
  end select
  call evaluate_b1_10_reference_temporal(delta, limits, assessment)
  if (assessment%complete) error stop 'FCI14 optional process scope must fail closed'
  deallocate(full,half)

  call seed_backend()
  select type(p=>state)
  type is(b1_10_process_state_t)
    call capture_b1_10_process_state(p)
  end select

  tx_policy%temporal_tolerance=1.0_real64
  tx_policy%mass_tolerance=1.0e-12_real64
  tx_policy%retry_scale=0.5_real64
  tx_policy%max_retries=2
  call execute_reference_interval(model,state,10.0_real64,11.0_real64,tx_policy,result)
  if (result%status/=TX_STATUS_ACCEPTED) error stop 'FCI14 candidate transaction did not accept'
  if (result%accepted_route/=TX_ROUTE_TWO_HALF) error stop 'FCI14 candidate accepted route'
  if (result%temporal_rejections/=1 .or. result%retries/=1 .or. result%rollbacks/=1) &
    error stop 'FCI14 temporal retry accounting'
  if (abs(result%accepted_t1-10.5_real64)>1e-14_real64) error stop 'FCI14 accepted retry endpoint'
  if (result%temporal_error>1.0_real64) error stop 'FCI14 accepted normalized error'
  if (abs(result%full_mass_residual)>1e-12_real64 .or. abs(result%half_mass_residual)>1e-12_real64) &
    error stop 'FCI14 hard mass contract regression'

  call state%clone(full)
  call state%clone(half)
  terr=model%temporal_error(full,half)
  if (abs(terr)>0.0_real64) error stop 'FCI14 identical state temporal error'

  print *, 'FCI14_REFERENCE_TEMPORAL_POLICY PASS'
end program test_fci14_reference_temporal_policy
