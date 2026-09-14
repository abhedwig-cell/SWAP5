program test_fvq83_explicit_owner_identity_attack
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, energy_commit_record_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  use mod_fvq83_receipt_model
  implicit none

  integer(int64), parameter :: RECEIPT_LINEAGE = 83083_int64
  integer(int64), parameter :: OWNER_A = 83001_int64
  integer(int64), parameter :: OWNER_B = 83002_int64
  integer(int64), parameter :: OWNER_C = 83003_int64
  integer(int64), parameter :: OWNER_D = 83004_int64
  integer(int64), parameter :: OWNER_E = 83005_int64
  integer(int64), parameter :: OWNER_F = 83006_int64
  integer(int64), parameter :: DUPLICATE_OWNER = 83007_int64

  type(kernel_executor_t) :: kernel
  type(fvq83_model_t), target :: model
  type(fvq83_parameters_t) :: parameters
  type(fvq83_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(fmr_accepted_commit_receipt_t) :: receipt0, receipt1
  type(energy_trial_ledger_t) :: ledger_a, ledger_b, ledger_c, ledger_d, ledger_e, ledger_f, ledger_g, ledger_h, invalid_ledger
  type(prepared_energy_trial_t) :: prepared_a, prepared_b, prepared_c, prepared_d, prepared_e, prepared_f, prepared_g, prepared_h
  type(prepared_energy_trial_t) :: foreign_handle
  type(energy_commit_record_t) :: record
  integer(int64) :: ids(1)
  real(real64) :: initial_energy(1)
  integer :: status
  logical :: different_abort_ok, different_commit_ok, same_abort_ok, same_commit_ok, duplicate_alias_observed

  call setup_config(parameters, forcing, config)
  call kernel%bind_model(model)
  call initialize_committed(committed)

  ids = [1_int64]
  initial_energy = [10.0_real64]
  call invalid_ledger%begin_trial(0_int64, RECEIPT_LINEAGE, 0_int64, 0.0_real64, 1.0_real64, ids, initial_energy, status, 1)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'non-positive owner id rejected')
  call require(.not. invalid_ledger%has_active_trial(), 'invalid owner starts no active trial')
  call require(.not. invalid_ledger%has_prepared_trial(), 'invalid owner creates no prepared trial')
  print '(a)', 'FVQ83_NONPOSITIVE_OWNER_FAIL_CLOSED=PASS'

  call make_receipt(kernel, parameters, forcing, config, committed, 0.0_real64, 1.0_real64, receipt0)
  call require(receipt0%ready(), 'revision-zero accepted receipt ready')

  ! Recheck the F-VQ80/R1 class with distinct explicit owners and different
  ! transaction provenance. The foreign handle must be rejected without
  ! consuming either ledger or either owner handle.
  call stage_prepared(ledger_a, prepared_a, OWNER_A, 93083_int64, 5_int64, 10.0_real64, 11.0_real64, 2.0_real64)
  call stage_prepared(ledger_b, prepared_b, OWNER_B, RECEIPT_LINEAGE, 0_int64, 0.0_real64, 1.0_real64, 3.0_real64)

  foreign_handle = prepared_b
  call ledger_a%abort_prepared(foreign_handle, status)
  different_abort_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (different_abort_ok) different_abort_ok = ledger_a%has_prepared_trial() .and. ledger_b%has_prepared_trial()
  if (different_abort_ok) different_abort_ok = prepared_a%ready() .and. prepared_b%ready() .and. foreign_handle%ready()
  call require(different_abort_ok, 'different-provenance foreign abort fail closed')
  print '(a)', 'FVQ83_DIFFERENT_PROVENANCE_FOREIGN_ABORT=PASS'

  foreign_handle = prepared_b
  call ledger_a%commit_prepared(foreign_handle, receipt0, record, status)
  different_commit_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE .and. .not. record%ready()
  if (different_commit_ok) different_commit_ok = ledger_a%has_prepared_trial() .and. ledger_b%has_prepared_trial()
  if (different_commit_ok) different_commit_ok = prepared_a%ready() .and. prepared_b%ready() .and. foreign_handle%ready()
  call require(different_commit_ok, 'different-provenance foreign commit fail closed')
  print '(a)', 'FVQ83_DIFFERENT_PROVENANCE_FOREIGN_COMMIT_REAL_RECEIPT=PASS'

  call ledger_b%commit_prepared(prepared_b, receipt0, record, status)
  call require(status == ENERGY_LEDGER_OK .and. record%ready(), 'ledger B own commit succeeds')
  call require(.not. ledger_b%has_prepared_trial() .and. .not. prepared_b%ready(), 'ledger B own commit consumes state')
  call ledger_a%abort_prepared(prepared_a, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger A own abort succeeds')
  call require(.not. ledger_a%has_prepared_trial() .and. .not. prepared_a%ready(), 'ledger A own abort consumes state')
  print '(a)', 'FVQ83_OWN_HANDLE_SEMANTICS_AFTER_DIFFERENT_REJECT=PASS'

  call make_receipt(kernel, parameters, forcing, config, committed, 1.0_real64, 2.0_real64, receipt1)
  call require(receipt1%ready(), 'revision-one accepted receipt ready')

  ! Core R2 attack: exact same physical transaction provenance and local
  ! generation on independent ledger objects, but distinct live owner IDs.
  call stage_prepared(ledger_c, prepared_c, OWNER_C, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 4.0_real64)
  call stage_prepared(ledger_d, prepared_d, OWNER_D, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 5.0_real64)
  foreign_handle = prepared_d
  call ledger_c%abort_prepared(foreign_handle, status)
  same_abort_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (same_abort_ok) same_abort_ok = ledger_c%has_prepared_trial() .and. ledger_d%has_prepared_trial()
  if (same_abort_ok) same_abort_ok = prepared_c%ready() .and. prepared_d%ready() .and. foreign_handle%ready()
  call require(same_abort_ok, 'same-provenance distinct-owner foreign abort fail closed')
  print '(a)', 'FVQ83_SAME_PROVENANCE_DISTINCT_OWNER_FOREIGN_ABORT=PASS'

  call stage_prepared(ledger_e, prepared_e, OWNER_E, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 6.0_real64)
  call stage_prepared(ledger_f, prepared_f, OWNER_F, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 7.0_real64)
  foreign_handle = prepared_f
  call ledger_e%commit_prepared(foreign_handle, receipt1, record, status)
  same_commit_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE .and. .not. record%ready()
  if (same_commit_ok) same_commit_ok = ledger_e%has_prepared_trial() .and. ledger_f%has_prepared_trial()
  if (same_commit_ok) same_commit_ok = prepared_e%ready() .and. prepared_f%ready() .and. foreign_handle%ready()
  call require(same_commit_ok, 'same-provenance distinct-owner foreign commit fail closed')
  print '(a)', 'FVQ83_SAME_PROVENANCE_DISTINCT_OWNER_FOREIGN_COMMIT_REAL_RECEIPT=PASS'

  call ledger_e%commit_prepared(prepared_e, receipt1, record, status)
  call require(status == ENERGY_LEDGER_OK .and. record%ready(), 'ledger E own commit succeeds after foreign reject')
  call require(.not. ledger_e%has_prepared_trial() .and. .not. prepared_e%ready(), 'ledger E own commit consumes state')
  call ledger_f%abort_prepared(prepared_f, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger F own abort succeeds after foreign reject')
  call require(.not. ledger_f%has_prepared_trial() .and. .not. prepared_f%ready(), 'ledger F own abort consumes state')
  call ledger_c%abort_prepared(prepared_c, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger C own abort succeeds after foreign reject')
  call ledger_d%abort_prepared(prepared_d, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger D own abort succeeds after foreign reject')
  print '(a)', 'FVQ83_OWN_HANDLE_SEMANTICS_AFTER_SAME_PROVENANCE_REJECT=PASS'

  ! Deliberate caller-contract violation. R2 does not claim automatic object
  ! identity: if two simultaneously live ledgers reuse the same explicit owner
  ! ID and all other provenance is also equal, the handles alias. This must be
  ! visible evidence, not a hidden assumption.
  call stage_prepared(ledger_g, prepared_g, DUPLICATE_OWNER, RECEIPT_LINEAGE, 2_int64, 2.0_real64, 3.0_real64, 8.0_real64)
  call stage_prepared(ledger_h, prepared_h, DUPLICATE_OWNER, RECEIPT_LINEAGE, 2_int64, 2.0_real64, 3.0_real64, 9.0_real64)
  foreign_handle = prepared_h
  call ledger_g%abort_prepared(foreign_handle, status)
  duplicate_alias_observed = status == ENERGY_LEDGER_OK
  if (duplicate_alias_observed) duplicate_alias_observed = .not. ledger_g%has_prepared_trial()
  if (duplicate_alias_observed) duplicate_alias_observed = ledger_h%has_prepared_trial() .and. prepared_h%ready()
  call require(duplicate_alias_observed, 'duplicate owner id limitation remains explicit')
  print '(a)', 'FVQ83_DUPLICATE_OWNER_ID_CALLER_CONTRACT_LIMITATION=CONFIRMED'
  call ledger_h%abort_prepared(prepared_h, status)
  call require(status == ENERGY_LEDGER_OK, 'cleanup duplicate-owner ledger H')

  print '(a)', 'FVQ83_DISTINCT_OWNER_INSTANCE_ISOLATION=PASS'
  print '(a)', 'FVQ83_INDEPENDENT_ORACLE=PASS_WITH_CALLER_UNIQUENESS_CONTRACT'

contains

  subroutine setup_config(p, f, c)
    type(fvq83_parameters_t), intent(out) :: p
    type(fvq83_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%inflow_rate = 0.2_real64
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
    allocate(fvq83_state_t :: physical)
    select type (physical)
    type is (fvq83_state_t)
      physical%water_store = 3.0_real64
    end select
    call state%initialize(RECEIPT_LINEAGE, physical, initialized, 0.0_real64)
    call require(initialized, 'initialize F-VQ83 committed state')
  end subroutine initialize_committed

  subroutine make_receipt(k, p, f, c, state, t0, t1, receipt)
    type(kernel_executor_t), intent(inout) :: k
    type(fvq83_parameters_t), intent(in) :: p
    type(fvq83_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(kernel_checkpoint_t) :: cp
    type(kernel_candidate_state_t) :: cand
    type(kernel_result_t) :: res
    type(kernel_diagnostics_t) :: diag
    logical :: checkpoint_ok, committed_ok
    integer :: rs, cs

    call state%capture_checkpoint(cp, checkpoint_ok)
    call require(checkpoint_ok, 'capture checkpoint for receipt')
    call k%advance_interval(p, state, f, c, t0, t1, res, cand, diag, cp)
    call require(res%completed, 'receipt candidate completed')
    call require(res%mass%complete, 'receipt candidate mass complete')
    call require(abs(res%mass%residual) <= 1.0e-12_real64, 'receipt candidate mass residual')
    call require(cand%ready(), 'receipt candidate ready')
    call fmr_commit_candidate_with_receipt(k, cp, state, cand, diag, committed_ok, receipt, rs, cs)
    call require(committed_ok, 'physical candidate committed')
    call require(rs == FMR_COMMIT_RECEIPT_OK, 'accepted receipt status')
    call require(receipt%ready(), 'accepted receipt ready')
  end subroutine make_receipt

  subroutine stage_prepared(ledger, prepared, owner_id, lineage, revision, t0, t1, amount)
    type(energy_trial_ledger_t), intent(inout) :: ledger
    type(prepared_energy_trial_t), intent(out) :: prepared
    integer(int64), intent(in) :: owner_id, lineage, revision
    real(real64), intent(in) :: t0, t1, amount
    integer(int64) :: component_ids(1)
    real(real64) :: initial_store(1), final_store(1)
    integer :: s

    component_ids = [1_int64]
    initial_store = [10.0_real64]
    final_store = [10.0_real64 + amount]
    call ledger%begin_trial(owner_id, lineage, revision, t0, t1, component_ids, initial_store, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin staged energy trial')
    call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, component_ids(1), amount, s)
    call require(s == ENERGY_LEDGER_OK, 'record staged energy transfer')
    call ledger%set_end_storage(final_store, s)
    call require(s == ENERGY_LEDGER_OK, 'set staged end storage')
    call ledger%prepare_trial(prepared, s)
    call require(s == ENERGY_LEDGER_OK, 'prepare staged energy trial')
    call require(prepared%ready(), 'staged prepared handle ready')
  end subroutine stage_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ83_FIXTURE_FAIL=', trim(label)
      error stop 83
    end if
  end subroutine require

end program test_fvq83_explicit_owner_identity_attack
