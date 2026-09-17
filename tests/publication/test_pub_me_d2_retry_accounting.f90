module pub_me_d2_observer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_b1_10_reference_policy_candidate_model, only: b1_10_reference_policy_candidate_model_t
  implicit none
  private
  public :: d2_observing_model_t

  type, extends(b1_10_reference_policy_candidate_model_t) :: d2_observing_model_t
    logical :: fault_enabled = .false.
    integer :: advance_calls = 0
    real(real64) :: first_half_in = 0.0_real64
    real(real64) :: first_half_out = 0.0_real64
    real(real64) :: premature_in = 0.0_real64
    real(real64) :: premature_out = 0.0_real64
    real(real64) :: retry_entry_in = 0.0_real64
    real(real64) :: retry_entry_out = 0.0_real64
    logical :: retry_entry_observed = .false.
  contains
    procedure :: advance => d2_observing_advance
  end type d2_observing_model_t

contains

  subroutine d2_observing_advance(self, state, t0, t1, outcome)
    class(d2_observing_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    self%advance_calls = self%advance_calls + 1

    ! FCI14's pre-existing authority establishes that calls 1-3 form the
    ! rejected first attempt and call 4 starts the accepted retry attempt.
    if (self%advance_calls == 4) then
      self%retry_entry_in = self%premature_in
      self%retry_entry_out = self%premature_out
      self%retry_entry_observed = .true.
    end if

    call self%b1_10_reference_policy_candidate_model_t%advance(state, t0, t1, outcome)

    if (.not. outcome%solver_ok) return
    if (.not. self%fault_enabled) return

    select case (self%advance_calls)
    case (2)
      self%first_half_in = outcome%mass_in
      self%first_half_out = outcome%mass_out
    case (3)
      ! Qualification-only D2 fault: publish the first attempt's two-half
      ! exchange as if it were already accepted, before the temporal decision.
      self%premature_in = self%first_half_in + outcome%mass_in
      self%premature_out = self%first_half_out + outcome%mass_out
    end select
  end subroutine d2_observing_advance

end module pub_me_d2_observer

program test_pub_me_d2_retry_accounting
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state
  use mod_b1_10_reference_temporal_policy, only: b1_10_reference_temporal_limits_t
  use fci14_backend_globals, only: seed_backend
  use pub_me_d2_observer, only: d2_observing_model_t
  implicit none

  real(real64), parameter :: mass_tol = 1.0e-12_real64
  type(transaction_result_t) :: clean_result, mutant_result
  real(real64) :: clean_storage, mutant_storage
  real(real64) :: clean_final_in, clean_final_out
  real(real64) :: mutant_final_in, mutant_final_out, mutant_faulty_residual
  real(real64) :: clean_endpoint_metric, mutant_endpoint_metric
  real(real64) :: retry_entry_magnitude
  integer :: clean_calls, mutant_calls
  logical :: mutant_retry_seen, b2_detected, b1_detected_final
  character(len=32) :: classification

  call run_case(.false., clean_result, clean_storage, clean_endpoint_metric, clean_final_in, clean_final_out, &
       clean_calls, mutant_retry_seen, retry_entry_magnitude)
  call require(clean_result%status == TX_STATUS_ACCEPTED, 'clean FCI14 retry authority accepted')
  call require(clean_result%temporal_rejections == 1, 'clean exactly one temporal rejection')
  call require(clean_result%retries == 1 .and. clean_result%rollbacks == 1, 'clean one retry and rollback')
  call require(abs(clean_result%accepted_t1 - 10.5_real64) <= 1.0e-14_real64, 'clean accepted retry endpoint')
  call require(abs(clean_result%accepted_mass_residual) <= mass_tol, 'clean canonical accepted mass closure')

  call run_case(.true., mutant_result, mutant_storage, mutant_endpoint_metric, mutant_final_in, mutant_final_out, &
       mutant_calls, mutant_retry_seen, retry_entry_magnitude)

  if (mutant_result%status /= TX_STATUS_ACCEPTED .or. mutant_result%temporal_rejections /= 1 .or. &
      mutant_result%retries /= 1 .or. mutant_result%rollbacks /= 1) then
    write(*,'(A)') 'PUB_ME_D2_CLASSIFICATION=BLOCKED_REFERENCE_RETRY_AUTHORITY'
    error stop 2
  end if

  call require(clean_calls == 6 .and. mutant_calls == 6, 'FCI14 full/two-half retry call pattern')
  call require(mutant_retry_seen, 'mutant retry entry observed')

  if (retry_entry_magnitude == 0.0_real64) then
    write(*,'(A)') 'PUB_ME_D2_CLASSIFICATION=BLOCKED_ZERO_EXCHANGE_CONTEXT'
    error stop 3
  end if

  ! The fault side ledger must not perturb the actual scientific calculation.
  call require(same_real(clean_result%accepted_storage_start, mutant_result%accepted_storage_start), &
       'clean/mutant accepted storage start identity')
  call require(same_real(clean_result%accepted_storage_end, mutant_result%accepted_storage_end), &
       'clean/mutant accepted storage end identity')
  call require(same_real(clean_result%accepted_total_in, mutant_result%accepted_total_in), &
       'clean/mutant canonical accepted input identity')
  call require(same_real(clean_result%accepted_total_out, mutant_result%accepted_total_out), &
       'clean/mutant canonical accepted output identity')
  call require(same_real(clean_result%accepted_mass_residual, mutant_result%accepted_mass_residual), &
       'clean/mutant canonical mass residual identity')
  call require(same_real(clean_storage, mutant_storage), 'clean/mutant endpoint storage identity')
  call require(same_real(clean_endpoint_metric, mutant_endpoint_metric), 'clean/mutant endpoint state metric identity')

  b2_detected = retry_entry_magnitude > 0.0_real64
  call require(b2_detected, 'B2 sees nonzero accepted ledger at retry entry')

  mutant_faulty_residual = (mutant_result%accepted_storage_end - mutant_result%accepted_storage_start) - &
       (mutant_final_in - mutant_final_out)
  b1_detected_final = abs(mutant_faulty_residual) > mass_tol .or. &
       .not. same_real(mutant_final_in, clean_final_in) .or. .not. same_real(mutant_final_out, clean_final_out)

  if (b1_detected_final) then
    classification = 'EARLIER_DETECTION'
  else
    classification = 'UNIQUE_DETECTION'
  end if

  write(*,'(A,I0)') 'PUB_ME_D2_CLEAN_ADVANCE_CALLS=', clean_calls
  write(*,'(A,I0)') 'PUB_ME_D2_MUTANT_ADVANCE_CALLS=', mutant_calls
  write(*,'(A,I0)') 'PUB_ME_D2_CLEAN_TEMPORAL_REJECTIONS=', clean_result%temporal_rejections
  write(*,'(A,I0)') 'PUB_ME_D2_MUTANT_TEMPORAL_REJECTIONS=', mutant_result%temporal_rejections
  write(*,'(A,ES26.17E3)') 'PUB_ME_D2_CANONICAL_ACCEPTED_IN=', mutant_result%accepted_total_in
  write(*,'(A,ES26.17E3)') 'PUB_ME_D2_CANONICAL_ACCEPTED_OUT=', mutant_result%accepted_total_out
  write(*,'(A,ES26.17E3)') 'PUB_ME_D2_RETRY_ENTRY_LEDGER_MAGNITUDE=', retry_entry_magnitude
  write(*,'(A,ES26.17E3)') 'PUB_ME_D2_FAULTY_FINAL_IN=', mutant_final_in
  write(*,'(A,ES26.17E3)') 'PUB_ME_D2_FAULTY_FINAL_OUT=', mutant_final_out
  write(*,'(A,ES26.17E3)') 'PUB_ME_D2_FAULTY_FINAL_MASS_RESIDUAL=', mutant_faulty_residual
  write(*,'(A,L1)') 'PUB_ME_D2_B2_RETRY_ENTRY_DETECTED=', b2_detected
  write(*,'(A,L1)') 'PUB_ME_D2_B1_FINAL_DETECTED=', b1_detected_final
  write(*,'(A,A)') 'PUB_ME_D2_CLASSIFICATION=', trim(classification)
  write(*,'(A)') 'PUB_ME_D2_RETRY_ACCOUNTING_EXPERIMENT=PASS'

contains

  subroutine run_case(enable_fault, result, final_storage, endpoint_metric, final_in, final_out, calls, retry_seen, retry_mag)
    logical, intent(in) :: enable_fault
    type(transaction_result_t), intent(out) :: result
    real(real64), intent(out) :: final_storage, endpoint_metric, final_in, final_out, retry_mag
    integer, intent(out) :: calls
    logical, intent(out) :: retry_seen

    type(d2_observing_model_t) :: model
    type(a23bu_worker_context_t), target :: worker
    type(b1_10_reference_temporal_limits_t) :: limits
    type(transaction_policy_t) :: policy
    class(transaction_state_t), allocatable :: state

    call seed_backend()
    allocate(b1_10_process_state_t :: state)
    select type(p => state)
    type is (b1_10_process_state_t)
      call capture_b1_10_process_state(p)
    end select

    limits%h_cm = 0.01_real64
    limits%theta = 0.01_real64
    limits%pond_cm = 0.01_real64
    limits%gwl_cm = 0.10_real64
    limits%volact_cm = 0.10_real64
    limits%ldwet_cm = 0.10_real64
    limits%spev_cm = 0.10_real64
    limits%saev_cm = 0.10_real64

    model%fault_enabled = enable_fault
    call model%bind_worker(worker)
    call model%bind_temporal_limits(limits)

    policy%temporal_tolerance = 1.0_real64
    policy%mass_tolerance = mass_tol
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2

    call execute_reference_interval(model, state, 10.0_real64, 11.0_real64, policy, result)

    final_storage = model%storage(state)
    endpoint_metric = endpoint_state_metric(state)
    calls = model%advance_calls
    retry_seen = model%retry_entry_observed
    retry_mag = abs(model%retry_entry_in) + abs(model%retry_entry_out)

    if (enable_fault) then
      final_in = model%premature_in + result%accepted_total_in
      final_out = model%premature_out + result%accepted_total_out
    else
      final_in = result%accepted_total_in
      final_out = result%accepted_total_out
    end if
  end subroutine run_case

  real(real64) function endpoint_state_metric(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = huge(0.0_real64)
    select type(p => state)
    type is (b1_10_process_state_t)
      if (allocated(p%h) .and. allocated(p%theta)) then
        value = sum(p%h) + sum(p%theta)
      end if
    end select
  end function endpoint_state_metric

  pure logical function same_real(a, b) result(same)
    real(real64), intent(in) :: a, b
    integer(kind=8) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    same = ia == ib
  end function same_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D2_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_pub_me_d2_retry_accounting
