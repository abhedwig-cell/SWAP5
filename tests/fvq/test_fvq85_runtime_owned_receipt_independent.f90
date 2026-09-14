program test_fvq85_runtime_owned_receipt_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, &
       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH
  use mod_fmr_owned_commit_receipt, only: fmr_owned_commit_receipt_t, fmr_commit_candidate_with_owned_receipt
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, energy_commit_record_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  use mod_fvq84_receipt_model
  implicit none

  integer(int64), parameter :: LINEAGE = 85085_int64
  integer(int64), parameter :: COLUMN_A = 8508501_int64
  integer(int64), parameter :: COLUMN_B = 8508502_int64
  type(kernel_executor_t) :: kernel_a, kernel_b, kernel_invalid
  type(fvq84_model_t), target :: model_a, model_b, model_invalid
  type(fvq84_parameters_t) :: params_a, params_b, params_invalid
  type(fvq84_forcing_t) :: forcing_a, forcing_b, forcing_invalid
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_a, committed_b, committed_invalid
  type(fmr_owned_commit_receipt_t) :: owned_a, owned_b, invalid_owned
  type(fmr_accepted_commit_receipt_t) :: exported_a
  type(energy_trial_ledger_t) :: ledger_a
  type(prepared_energy_trial_t) :: prepared_a
  type(energy_commit_record_t) :: record
  integer :: status
  logical :: available

  call setup_config(config)
  params_a%inflow_rate = 0.125_real64
  params_b%inflow_rate = 0.375_real64
  params_invalid%inflow_rate = 0.25_real64
  forcing_a%multiplier = 1.0_real64
  forcing_b%multiplier = 1.0_real64
  forcing_invalid%multiplier = 1.0_real64
  call kernel_a%bind_model(model_a)
  call kernel_b%bind_model(model_b)
  call kernel_invalid%bind_model(model_invalid)

  ! Independent precommit fail-closed check: an invalid owner must be rejected
  ! before the physical candidate is committed. The candidate stays available
  ! and the committed revision remains unchanged.
  call initialize_committed(committed_invalid, 6.0_real64)
  call attempt_invalid_owner(kernel_invalid, params_invalid, forcing_invalid, config, committed_invalid, invalid_owned)
  call require(.not. invalid_owned%ready(), 'invalid owner yields no owned receipt')
  call require(committed_invalid%current_revision() == 0_int64, 'invalid owner leaves committed revision unchanged')
  print '(a)', 'FVQ85_INVALID_OWNER_PRECOMMIT_FAIL_CLOSED=PASS'

  ! Produce two real physical commits with deliberately aliased generic scalar
  ! receipt provenance but different logical runtime owners.
  call initialize_committed(committed_a, 4.0_real64)
  call initialize_committed(committed_b, 9.0_real64)
  call make_owned_receipt(COLUMN_A, kernel_a, params_a, forcing_a, config, committed_a, owned_a)
  call make_owned_receipt(COLUMN_B, kernel_b, params_b, forcing_b, config, committed_b, owned_b)
  call require(owned_a%ready() .and. owned_b%ready(), 'both owned receipts ready')
  call require(owned_a%owner_instance_id() == COLUMN_A, 'A owner identity')
  call require(owned_b%owner_instance_id() == COLUMN_B, 'B owner identity')
  call require(owned_a%current_lineage_id() == owned_b%current_lineage_id(), 'same scalar lineage')
  call require(owned_a%origin_revision() == owned_b%origin_revision(), 'same scalar origin revision')
  call require(owned_a%committed_revision() == owned_b%committed_revision(), 'same scalar committed revision')
  print '(a)', 'FVQ85_REAL_COLUMNS_SCALAR_RECEIPT_ALIAS_REPRODUCED=PASS'

  call owned_a%export_accepted_receipt(exported_a, available)
  call require(available .and. exported_a%ready(), 'generic receipt export available')
  call require(exported_a%current_lineage_id() == owned_a%current_lineage_id(), 'exported lineage preserved')
  call require(exported_a%origin_revision() == owned_a%origin_revision(), 'exported origin revision preserved')
  call require(exported_a%committed_revision() == owned_a%committed_revision(), 'exported committed revision preserved')
  print '(a)', 'FVQ85_GENERIC_RECEIPT_EXPORT_COMPATIBILITY=PASS'

  call stage_energy_trial(ledger_a, prepared_a, COLUMN_A)
  call require(.not. ledger_a%prepared_ready_for_receipt(prepared_a, owned_b), 'foreign owned receipt not ready')
  call ledger_a%commit_prepared(prepared_a, owned_b, record, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'foreign receipt commit rejected')
  call require(.not. record%ready(), 'foreign receipt publishes no record')
  call require(ledger_a%has_prepared_trial(), 'foreign rejection keeps rightful ledger prepared')
  call require(prepared_a%ready(), 'foreign rejection keeps rightful handle ready')
  print '(a)', 'FVQ85_FOREIGN_COLUMN_RECEIPT_FAIL_CLOSED=PASS'

  call require(ledger_a%prepared_ready_for_receipt(prepared_a, owned_a), 'rightful owned receipt ready')
  call ledger_a%commit_prepared(prepared_a, owned_a, record, status)
  call require(status == ENERGY_LEDGER_OK .and. record%ready(), 'rightful receipt commits')
  call require(.not. ledger_a%has_prepared_trial(), 'rightful commit consumes prepared ledger')
  call require(.not. prepared_a%ready(), 'rightful commit consumes prepared handle')
  call require(record%origin_revision() == 0_int64 .and. record%committed_revision() == 1_int64, &
       'rightful record revisions')
  print '(a)', 'FVQ85_RIGHTFUL_OWNER_COMMIT_EXACTLY_ONCE=PASS'
  print '(a)', 'FVQ85_RUNTIME_OWNED_RECEIPT_INDEPENDENT_ORACLE=PASS'

contains

  subroutine setup_config(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_tolerance = 1.0e-12_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 1
    c%max_committed_substeps = 4
    c%progress_tolerance = 0.0_real64
  end subroutine setup_config

  subroutine initialize_committed(state, store)
    type(kernel_committed_state_t), intent(out) :: state
    real(real64), intent(in) :: store
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fvq84_state_t :: physical)
    select type (physical)
    type is (fvq84_state_t)
      physical%water_store = store
    end select
    call state%initialize(LINEAGE, physical, initialized, 0.0_real64)
    call require(initialized, 'initialize committed state')
  end subroutine initialize_committed

  subroutine attempt_invalid_owner(k, p, f, c, state, owned)
    type(kernel_executor_t), intent(inout) :: k
    type(fvq84_parameters_t), intent(in) :: p
    type(fvq84_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(fmr_owned_commit_receipt_t), intent(out) :: owned
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    logical :: checkpoint_ok, did_commit
    integer :: receipt_status, commit_status

    call state%capture_checkpoint(checkpoint, checkpoint_ok)
    call require(checkpoint_ok, 'invalid-owner checkpoint')
    call k%advance_interval(p, state, f, c, 0.0_real64, 1.0_real64, result, candidate, diagnostics, checkpoint)
    call require(result%completed .and. result%mass%complete, 'invalid-owner candidate complete')
    call require(abs(result%mass%residual) <= 1.0e-12_real64, 'invalid-owner candidate mass')
    call require(candidate%ready(), 'invalid-owner candidate ready')
    call fmr_commit_candidate_with_owned_receipt(0_int64, k, checkpoint, state, candidate, diagnostics, did_commit, &
         owned, receipt_status, commit_status)
    call require(.not. did_commit, 'invalid owner must not commit')
    call require(receipt_status == FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH, 'invalid owner status')
    call require(candidate%ready(), 'invalid owner leaves candidate unconsumed')
  end subroutine attempt_invalid_owner

  subroutine make_owned_receipt(owner_id, k, p, f, c, state, owned)
    integer(int64), intent(in) :: owner_id
    type(kernel_executor_t), intent(inout) :: k
    type(fvq84_parameters_t), intent(in) :: p
    type(fvq84_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(fmr_owned_commit_receipt_t), intent(out) :: owned
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    logical :: checkpoint_ok, did_commit
    integer :: receipt_status, commit_status

    call state%capture_checkpoint(checkpoint, checkpoint_ok)
    call require(checkpoint_ok, 'owned checkpoint')
    call k%advance_interval(p, state, f, c, 0.0_real64, 1.0_real64, result, candidate, diagnostics, checkpoint)
    call require(result%completed .and. result%mass%complete, 'owned candidate complete')
    call require(abs(result%mass%residual) <= 1.0e-12_real64, 'owned candidate mass')
    call require(candidate%ready(), 'owned candidate ready')
    call fmr_commit_candidate_with_owned_receipt(owner_id, k, checkpoint, state, candidate, diagnostics, did_commit, &
         owned, receipt_status, commit_status)
    call require(did_commit, 'owned physical commit')
    call require(receipt_status == FMR_COMMIT_RECEIPT_OK .and. owned%ready(), 'owned receipt ready')
  end subroutine make_owned_receipt

  subroutine stage_energy_trial(ledger, prepared, owner_id)
    type(energy_trial_ledger_t), intent(inout) :: ledger
    type(prepared_energy_trial_t), intent(out) :: prepared
    integer(int64), intent(in) :: owner_id
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    integer :: local_status

    ids = [1_int64]
    initial_energy = [10.0_real64]
    final_energy = [12.0_real64]
    call ledger%begin_trial(owner_id, LINEAGE, 0_int64, 0.0_real64, 1.0_real64, ids, initial_energy, local_status, 1)
    call require(local_status == ENERGY_LEDGER_OK, 'begin energy trial')
    call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), 2.0_real64, local_status)
    call require(local_status == ENERGY_LEDGER_OK, 'record energy transfer')
    call ledger%set_end_storage(final_energy, local_status)
    call require(local_status == ENERGY_LEDGER_OK, 'set final energy')
    call ledger%prepare_trial(prepared, local_status)
    call require(local_status == ENERGY_LEDGER_OK .and. prepared%ready(), 'prepare energy trial')
  end subroutine stage_energy_trial

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ85_FAIL=', trim(label)
      error stop 85
    end if
  end subroutine require

end program test_fvq85_runtime_owned_receipt_independent
