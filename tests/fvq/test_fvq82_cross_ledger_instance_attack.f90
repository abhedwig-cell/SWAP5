program test_fvq82_cross_ledger_instance_attack
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, energy_commit_record_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  use mod_fvq82_receipt_model
  implicit none

  integer(int64), parameter :: RECEIPT_LINEAGE = 82082_int64
  type(kernel_executor_t) :: kernel
  type(fvq82_model_t), target :: model
  type(fvq82_parameters_t) :: parameters
  type(fvq82_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_accepted_commit_receipt_t) :: receipt0, receipt1
  type(energy_trial_ledger_t) :: ledger_a, ledger_b, ledger_c, ledger_d, ledger_e, ledger_f
  type(prepared_energy_trial_t) :: prepared_a, prepared_b, prepared_c, prepared_d, prepared_e, prepared_f, foreign_handle
  type(energy_commit_record_t) :: record
  integer :: status, receipt_status, commit_status
  logical :: ok, did_commit
  logical :: different_abort_ok, different_commit_ok, same_abort_ok, same_commit_ok

  call setup_config(parameters, forcing, config)
  call kernel%bind_model(model)
  call initialize_committed(committed)

  call make_receipt(kernel, parameters, forcing, config, committed, 0.0_real64, 1.0_real64, receipt0)
  call require(receipt0%ready(), 'revision-zero accepted receipt ready')

  ! Attack 1: the original F-VQ80 shape. Both ledgers have generation 1,
  ! but deliberately different lineage/revision/interval provenance.
  call stage_prepared(ledger_a, prepared_a, 92082_int64, 5_int64, 10.0_real64, 11.0_real64, 2.0_real64)
  call stage_prepared(ledger_b, prepared_b, RECEIPT_LINEAGE, 0_int64, 0.0_real64, 1.0_real64, 3.0_real64)

  foreign_handle = prepared_b
  call ledger_a%abort_prepared(foreign_handle, status)
  different_abort_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (different_abort_ok) different_abort_ok = ledger_a%has_prepared_trial()
  if (different_abort_ok) different_abort_ok = ledger_b%has_prepared_trial()
  if (different_abort_ok) different_abort_ok = prepared_a%ready()
  if (different_abort_ok) different_abort_ok = prepared_b%ready()
  if (different_abort_ok) different_abort_ok = foreign_handle%ready()
  call require(different_abort_ok, 'different-provenance foreign abort fail closed')
  print '(a)', 'FVQ82_DIFFERENT_PROVENANCE_FOREIGN_ABORT=PASS'

  foreign_handle = prepared_b
  call ledger_a%commit_prepared(foreign_handle, receipt0, record, status)
  different_commit_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (different_commit_ok) different_commit_ok = .not. record%ready()
  if (different_commit_ok) different_commit_ok = ledger_a%has_prepared_trial()
  if (different_commit_ok) different_commit_ok = ledger_b%has_prepared_trial()
  if (different_commit_ok) different_commit_ok = prepared_a%ready()
  if (different_commit_ok) different_commit_ok = prepared_b%ready()
  if (different_commit_ok) different_commit_ok = foreign_handle%ready()
  call require(different_commit_ok, 'different-provenance foreign commit fail closed')
  print '(a)', 'FVQ82_DIFFERENT_PROVENANCE_FOREIGN_COMMIT=PASS'

  call ledger_b%commit_prepared(prepared_b, receipt0, record, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger B own commit succeeds')
  call require(record%ready(), 'ledger B own commit publishes')
  call require(.not. ledger_b%has_prepared_trial(), 'ledger B own commit consumes ledger state')
  call require(.not. prepared_b%ready(), 'ledger B own commit consumes handle')
  call ledger_a%abort_prepared(prepared_a, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger A own abort succeeds')
  call require(.not. ledger_a%has_prepared_trial(), 'ledger A own abort consumes ledger state')
  print '(a)', 'FVQ82_OWN_HANDLE_SEMANTICS_AFTER_REJECT=PASS'

  call make_receipt(kernel, parameters, forcing, config, committed, 1.0_real64, 2.0_real64, receipt1)
  call require(receipt1%ready(), 'revision-one accepted receipt ready')

  ! Attack 2: two independent ledger instances intentionally carry exactly
  ! the same transaction provenance and the same local generation. If a
  ! prepared handle is truly ledger-instance-bound, this must still fail.
  call stage_prepared(ledger_c, prepared_c, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 4.0_real64)
  call stage_prepared(ledger_d, prepared_d, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 5.0_real64)
  foreign_handle = prepared_d
  call ledger_c%abort_prepared(foreign_handle, status)
  same_abort_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (same_abort_ok) same_abort_ok = ledger_c%has_prepared_trial()
  if (same_abort_ok) same_abort_ok = ledger_d%has_prepared_trial()
  if (same_abort_ok) same_abort_ok = prepared_c%ready()
  if (same_abort_ok) same_abort_ok = prepared_d%ready()
  if (same_abort_ok) same_abort_ok = foreign_handle%ready()

  write(*,'(a,i0)') 'FVQ82_SAME_PROVENANCE_FOREIGN_ABORT_STATUS=', status
  write(*,'(a,l1)') 'FVQ82_SAME_PROVENANCE_LEDGER_C_PRESERVED=', ledger_c%has_prepared_trial()
  write(*,'(a,l1)') 'FVQ82_SAME_PROVENANCE_LEDGER_D_PRESERVED=', ledger_d%has_prepared_trial()

  call stage_prepared(ledger_e, prepared_e, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 6.0_real64)
  call stage_prepared(ledger_f, prepared_f, RECEIPT_LINEAGE, 1_int64, 1.0_real64, 2.0_real64, 7.0_real64)
  foreign_handle = prepared_f
  call ledger_e%commit_prepared(foreign_handle, receipt1, record, status)
  same_commit_ok = status == ENERGY_LEDGER_INVALID_PROVENANCE
  if (same_commit_ok) same_commit_ok = .not. record%ready()
  if (same_commit_ok) same_commit_ok = ledger_e%has_prepared_trial()
  if (same_commit_ok) same_commit_ok = ledger_f%has_prepared_trial()
  if (same_commit_ok) same_commit_ok = prepared_e%ready()
  if (same_commit_ok) same_commit_ok = prepared_f%ready()
  if (same_commit_ok) same_commit_ok = foreign_handle%ready()

  write(*,'(a,i0)') 'FVQ82_SAME_PROVENANCE_FOREIGN_COMMIT_STATUS=', status
  write(*,'(a,l1)') 'FVQ82_SAME_PROVENANCE_FOREIGN_COMMIT_RECORD_READY=', record%ready()
  write(*,'(a,l1)') 'FVQ82_SAME_PROVENANCE_LEDGER_E_PRESERVED=', ledger_e%has_prepared_trial()
  write(*,'(a,l1)') 'FVQ82_SAME_PROVENANCE_LEDGER_F_PRESERVED=', ledger_f%has_prepared_trial()

  if (same_abort_ok .and. same_commit_ok) then
    print '(a)', 'FVQ82_CROSS_LEDGER_INSTANCE_ISOLATION=PASS'
    print '(a)', 'FVQ82_INDEPENDENT_ORACLE=PASS'
  else
    print '(a)', 'FVQ82_CROSS_LEDGER_INSTANCE_ISOLATION=BLOCKER_SAME_PROVENANCE_ALIAS'
    print '(a)', 'FVQ82_INDEPENDENT_ORACLE=NOT_QUALIFIED'
  end if

contains

  subroutine setup_config(p, f, c)
    type(fvq82_parameters_t), intent(out) :: p
    type(fvq82_forcing_t), intent(out) :: f
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
    allocate(fvq82_state_t :: physical)
    select type (physical)
    type is (fvq82_state_t)
      physical%water_store = 3.0_real64
    end select
    call state%initialize(RECEIPT_LINEAGE, physical, initialized, 0.0_real64)
    call require(initialized, 'initialize F-VQ82 committed state')
  end subroutine initialize_committed

  subroutine make_receipt(k, p, f, c, state, t0, t1, receipt)
    type(kernel_executor_t), intent(inout) :: k
    type(fvq82_parameters_t), intent(in) :: p
    type(fvq82_forcing_t), intent(in) :: f
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

  subroutine stage_prepared(ledger, prepared, lineage, revision, t0, t1, amount)
    type(energy_trial_ledger_t), intent(inout) :: ledger
    type(prepared_energy_trial_t), intent(out) :: prepared
    integer(int64), intent(in) :: lineage, revision
    real(real64), intent(in) :: t0, t1, amount
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    integer :: s

    ids = [1_int64]
    initial_energy = [10.0_real64]
    final_energy = [10.0_real64 + amount]
    call ledger%begin_trial(lineage, revision, t0, t1, ids, initial_energy, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin staged energy trial')
    call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), amount, s)
    call require(s == ENERGY_LEDGER_OK, 'record staged energy transfer')
    call ledger%set_end_storage(final_energy, s)
    call require(s == ENERGY_LEDGER_OK, 'set staged end storage')
    call ledger%prepare_trial(prepared, s)
    call require(s == ENERGY_LEDGER_OK, 'prepare staged energy trial')
    call require(prepared%ready(), 'staged prepared handle ready')
  end subroutine stage_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ82_FIXTURE_FAIL=', trim(label)
      error stop 82
    end if
  end subroutine require

end program test_fvq82_cross_ledger_instance_attack
