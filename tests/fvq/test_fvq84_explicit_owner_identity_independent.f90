program test_fvq84_explicit_owner_identity_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, energy_commit_record_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  use mod_fvq84_receipt_model
  implicit none

  integer(int64), parameter :: LINEAGE = 84084_int64
  integer(int64), parameter :: OWNER_A = 8408401_int64
  integer(int64), parameter :: OWNER_B = 8408402_int64
  integer(int64), parameter :: OWNER_DUP = 8408499_int64
  type(kernel_executor_t) :: kernel
  type(fvq84_model_t), target :: model
  type(fvq84_parameters_t) :: parameters
  type(fvq84_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(fmr_accepted_commit_receipt_t) :: receipt
  type(energy_trial_ledger_t) :: ledger_a, ledger_b, ledger_c, ledger_d, invalid_ledger
  type(prepared_energy_trial_t) :: prepared_a, prepared_b, prepared_c, prepared_d, foreign_handle
  type(energy_commit_record_t) :: record
  integer :: status
  logical :: distinct_abort_ok, distinct_commit_ok, duplicate_alias_observed

  call setup_config(parameters, forcing, config)
  call kernel%bind_model(model)
  call initialize_committed(committed)
  call make_receipt(kernel, parameters, forcing, config, committed, receipt)
  call require(receipt%ready(), 'real accepted receipt ready')

  call begin_invalid_owner(invalid_ledger, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'zero owner rejected')
  call require(.not. invalid_ledger%has_active_trial(), 'zero owner leaves no active trial')
  print '(a)', 'FVQ84_INVALID_OWNER_ID_FAIL_CLOSED=PASS'

  ! Same transaction tuple and same local generation. Only owner identity differs.
  call stage_prepared(ledger_a, prepared_a, OWNER_A, 2.0_real64)
  call stage_prepared(ledger_b, prepared_b, OWNER_B, 3.0_real64)

  foreign_handle = prepared_b
  call ledger_a%abort_prepared(foreign_handle, status)
  distinct_abort_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (distinct_abort_ok) distinct_abort_ok = ledger_a%has_prepared_trial()
  if (distinct_abort_ok) distinct_abort_ok = ledger_b%has_prepared_trial()
  if (distinct_abort_ok) distinct_abort_ok = prepared_a%ready()
  if (distinct_abort_ok) distinct_abort_ok = prepared_b%ready()
  if (distinct_abort_ok) distinct_abort_ok = foreign_handle%ready()
  call require(distinct_abort_ok, 'distinct-owner foreign abort fail closed')
  print '(a)', 'FVQ84_DISTINCT_OWNER_FOREIGN_ABORT_FAIL_CLOSED=PASS'

  foreign_handle = prepared_b
  call ledger_a%commit_prepared(foreign_handle, receipt, record, status)
  distinct_commit_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (distinct_commit_ok) distinct_commit_ok = .not. record%ready()
  if (distinct_commit_ok) distinct_commit_ok = ledger_a%has_prepared_trial()
  if (distinct_commit_ok) distinct_commit_ok = ledger_b%has_prepared_trial()
  if (distinct_commit_ok) distinct_commit_ok = prepared_a%ready()
  if (distinct_commit_ok) distinct_commit_ok = prepared_b%ready()
  if (distinct_commit_ok) distinct_commit_ok = foreign_handle%ready()
  call require(distinct_commit_ok, 'distinct-owner foreign commit fail closed')
  print '(a)', 'FVQ84_DISTINCT_OWNER_FOREIGN_COMMIT_FAIL_CLOSED=PASS'

  call ledger_b%commit_prepared(prepared_b, receipt, record, status)
  call require(status == ENERGY_LEDGER_OK, 'owner B valid commit succeeds')
  call require(record%ready(), 'owner B valid commit publishes')
  call require(.not. ledger_b%has_prepared_trial(), 'owner B valid commit consumes prepared state')
  call require(.not. prepared_b%ready(), 'owner B valid commit consumes handle')
  call require(ledger_a%has_prepared_trial(), 'owner A remains prepared after B commit')
  call require(prepared_a%ready(), 'owner A handle remains ready after B commit')
  print '(a)', 'FVQ84_VALID_OWNER_COMMIT_EXACTLY_OWN_LEDGER=PASS'

  call ledger_a%abort_prepared(prepared_a, status)
  call require(status == ENERGY_LEDGER_OK, 'owner A valid abort succeeds')
  call require(.not. ledger_a%has_prepared_trial(), 'owner A valid abort consumes prepared state')
  call require(.not. prepared_a%ready(), 'owner A valid abort consumes handle')
  print '(a)', 'FVQ84_VALID_OWNER_ABORT_EXACTLY_OWN_LEDGER=PASS'

  ! Deliberate caller-contract violation: duplicate live owner id plus identical
  ! transaction tuple. The ledger cannot distinguish these instances because
  ! uniqueness is an external runtime obligation. Observe, do not normalize.
  call stage_prepared(ledger_c, prepared_c, OWNER_DUP, 4.0_real64)
  call stage_prepared(ledger_d, prepared_d, OWNER_DUP, 5.0_real64)
  foreign_handle = prepared_d
  call ledger_c%abort_prepared(foreign_handle, status)
  duplicate_alias_observed = status == ENERGY_LEDGER_OK
  if (duplicate_alias_observed) duplicate_alias_observed = .not. ledger_c%has_prepared_trial()
  if (duplicate_alias_observed) duplicate_alias_observed = ledger_d%has_prepared_trial()
  if (duplicate_alias_observed) duplicate_alias_observed = prepared_c%ready()
  if (duplicate_alias_observed) duplicate_alias_observed = prepared_d%ready()
  if (duplicate_alias_observed) duplicate_alias_observed = .not. foreign_handle%ready()
  call require(duplicate_alias_observed, 'duplicate owner id exposes caller-contract alias')
  print '(a)', 'FVQ84_DUPLICATE_OWNER_ID_ALIAS_OBSERVED=EXPECTED_CALLER_CONTRACT_VIOLATION'

  call ledger_d%abort_prepared(prepared_d, status)
  call require(status == ENERGY_LEDGER_OK, 'duplicate fixture source ledger remains independently abortable')
  print '(a)', 'FVQ84_LEDGER_MODULE_CONTRACT=PASS_WITH_RUNTIME_UNIQUENESS_OBLIGATION'
  print '(a)', 'FVQ84_INDEPENDENT_ORACLE=PASS'

contains

  subroutine setup_config(p, f, c)
    type(fvq84_parameters_t), intent(out) :: p
    type(fvq84_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%inflow_rate = 0.125_real64
    f%multiplier = 1.0_real64
    c%transaction%temporal_tolerance = 1.0e-12_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 1
    c%max_committed_substeps = 4
    c%progress_tolerance = 0.0_real64
  end subroutine setup_config

  subroutine initialize_committed(state)
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized
    allocate(fvq84_state_t :: physical)
    select type (physical)
    type is (fvq84_state_t)
      physical%water_store = 4.0_real64
    end select
    call state%initialize(LINEAGE, physical, initialized, 0.0_real64)
    call require(initialized, 'initialize committed state')
  end subroutine initialize_committed

  subroutine make_receipt(k, p, f, c, state, accepted_receipt)
    type(kernel_executor_t), intent(inout) :: k
    type(fvq84_parameters_t), intent(in) :: p
    type(fvq84_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(fmr_accepted_commit_receipt_t), intent(out) :: accepted_receipt
    type(kernel_checkpoint_t) :: cp
    type(kernel_candidate_state_t) :: cand
    type(kernel_result_t) :: res
    type(kernel_diagnostics_t) :: diag
    logical :: checkpoint_ok, committed_ok
    integer :: receipt_status, commit_status

    call state%capture_checkpoint(cp, checkpoint_ok)
    call require(checkpoint_ok, 'capture checkpoint')
    call k%advance_interval(p, state, f, c, 0.0_real64, 1.0_real64, res, cand, diag, cp)
    call require(res%completed, 'candidate completed')
    call require(res%mass%complete, 'candidate mass complete')
    call require(abs(res%mass%residual) <= 1.0e-12_real64, 'candidate mass residual')
    call require(cand%ready(), 'candidate ready')
    call fmr_commit_candidate_with_receipt(k, cp, state, cand, diag, committed_ok, accepted_receipt, receipt_status, commit_status)
    call require(committed_ok, 'candidate committed')
    call require(receipt_status == FMR_COMMIT_RECEIPT_OK, 'receipt status')
    call require(accepted_receipt%ready(), 'receipt ready')
  end subroutine make_receipt

  subroutine begin_invalid_owner(ledger, s)
    type(energy_trial_ledger_t), intent(inout) :: ledger
    integer, intent(out) :: s
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1)
    ids = [1_int64]
    initial_energy = [10.0_real64]
    call ledger%begin_trial(0_int64, LINEAGE, 0_int64, 0.0_real64, 1.0_real64, ids, initial_energy, s, 1)
  end subroutine begin_invalid_owner

  subroutine stage_prepared(ledger, prepared, owner_id, amount)
    type(energy_trial_ledger_t), intent(inout) :: ledger
    type(prepared_energy_trial_t), intent(out) :: prepared
    integer(int64), intent(in) :: owner_id
    real(real64), intent(in) :: amount
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    integer :: s

    ids = [1_int64]
    initial_energy = [10.0_real64]
    final_energy = [10.0_real64 + amount]
    call ledger%begin_trial(owner_id, LINEAGE, 0_int64, 0.0_real64, 1.0_real64, ids, initial_energy, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin energy trial')
    call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), amount, s)
    call require(s == ENERGY_LEDGER_OK, 'record energy transfer')
    call ledger%set_end_storage(final_energy, s)
    call require(s == ENERGY_LEDGER_OK, 'set end storage')
    call ledger%prepare_trial(prepared, s)
    call require(s == ENERGY_LEDGER_OK, 'prepare energy trial')
    call require(prepared%ready(), 'prepared handle ready')
  end subroutine stage_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ84_FAIL=', trim(label)
      error stop 84
    end if
  end subroutine require

end program test_fvq84_explicit_owner_identity_independent
