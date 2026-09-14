program test_eb_i21_cross_column_receipt_attack
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, energy_commit_record_t, &
       ENERGY_LEDGER_OK
  use mod_fvq84_receipt_model
  implicit none

  integer(int64), parameter :: SHARED_LINEAGE = 921921_int64
  integer(int64), parameter :: COLUMN_A = 21001_int64
  integer(int64), parameter :: COLUMN_B = 21002_int64
  type(kernel_executor_t) :: kernel_a, kernel_b
  type(fvq84_model_t), target :: model_a, model_b
  type(fvq84_parameters_t) :: parameters_a, parameters_b
  type(fvq84_forcing_t) :: forcing_a, forcing_b
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_a, committed_b
  type(fmr_accepted_commit_receipt_t) :: receipt_a, receipt_b
  type(energy_trial_ledger_t) :: ledger_a
  type(prepared_energy_trial_t) :: prepared_a
  type(energy_commit_record_t) :: record
  integer(int64) :: ids(1)
  real(real64) :: initial_energy(1), final_energy(1)
  integer :: status
  logical :: foreign_receipt_accepted

  call require(COLUMN_A > 0_int64 .and. COLUMN_B > 0_int64 .and. COLUMN_A /= COLUMN_B, 'distinct positive column ids')
  call setup_config(config)
  parameters_a%inflow_rate = 0.125_real64
  parameters_b%inflow_rate = 0.375_real64
  forcing_a%multiplier = 1.0_real64
  forcing_b%multiplier = 1.0_real64
  call kernel_a%bind_model(model_a)
  call kernel_b%bind_model(model_b)
  call initialize_committed(committed_a, 4.0_real64)
  call initialize_committed(committed_b, 9.0_real64)

  call make_receipt(kernel_a, parameters_a, forcing_a, config, committed_a, receipt_a)
  call make_receipt(kernel_b, parameters_b, forcing_b, config, committed_b, receipt_b)
  call require(receipt_a%ready(), 'column A receipt ready')
  call require(receipt_b%ready(), 'column B receipt ready')
  call require(receipt_a%current_lineage_id() == receipt_b%current_lineage_id(), 'shared receipt lineage')
  call require(receipt_a%origin_revision() == receipt_b%origin_revision(), 'shared receipt origin revision')
  call require(receipt_a%committed_revision() == receipt_b%committed_revision(), 'shared receipt committed revision')
  print '(a)', 'EBI21_DISTINCT_PHYSICAL_COLUMNS_SCALAR_RECEIPT_ALIAS=CONFIRMED'

  ids = [1_int64]
  initial_energy = [10.0_real64]
  final_energy = [12.0_real64]
  call ledger_a%begin_trial(COLUMN_A, SHARED_LINEAGE, 0_int64, 0.0_real64, 1.0_real64, ids, initial_energy, status, 1)
  call require(status == ENERGY_LEDGER_OK, 'begin A energy trial')
  call ledger_a%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), 2.0_real64, status)
  call require(status == ENERGY_LEDGER_OK, 'record A transfer')
  call ledger_a%set_end_storage(final_energy, status)
  call require(status == ENERGY_LEDGER_OK, 'set A end storage')
  call ledger_a%prepare_trial(prepared_a, status)
  call require(status == ENERGY_LEDGER_OK .and. prepared_a%ready(), 'prepare A energy handle')

  ! Deliberate attack: A owns both the ledger and the prepared handle, but the
  ! accepted physical receipt came from distinct column B. Because the receipt
  ! carries no column/owner identity and the transaction tuple is identical,
  ! the current ledger cannot distinguish it from A's own receipt.
  call ledger_a%commit_prepared(prepared_a, receipt_b, record, status)
  foreign_receipt_accepted = status == ENERGY_LEDGER_OK .and. record%ready()
  call require(foreign_receipt_accepted, 'foreign same-tuple receipt aliases current ledger contract')
  print '(a)', 'EBI21_OWN_HANDLE_FOREIGN_COLUMN_RECEIPT_ACCEPTED=BLOCKER_CONFIRMED'
  print '(a)', 'EBI21_RUNTIME_OWNER_ID_ALONE_INSUFFICIENT=CONFIRMED'
  print '(a)', 'EBI21_CROSS_COLUMN_RECEIPT_ATTACK_ORACLE=PASS_NEGATIVE_EVIDENCE'

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
    call state%initialize(SHARED_LINEAGE, physical, initialized, 0.0_real64)
    call require(initialized, 'initialize committed state')
  end subroutine initialize_committed

  subroutine make_receipt(k, p, f, c, state, receipt)
    type(kernel_executor_t), intent(inout) :: k
    type(fvq84_parameters_t), intent(in) :: p
    type(fvq84_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(kernel_checkpoint_t) :: cp
    type(kernel_candidate_state_t) :: cand
    type(kernel_result_t) :: res
    type(kernel_diagnostics_t) :: diag
    logical :: checkpoint_ok, committed_ok
    integer :: receipt_status, commit_status

    call state%capture_checkpoint(cp, checkpoint_ok)
    call require(checkpoint_ok, 'capture checkpoint')
    call k%advance_interval(p, state, f, c, 0.0_real64, 1.0_real64, res, cand, diag, cp)
    call require(res%completed .and. res%mass%complete, 'candidate complete and mass complete')
    call require(abs(res%mass%residual) <= 1.0e-12_real64, 'candidate mass residual')
    call require(cand%ready(), 'candidate ready')
    call fmr_commit_candidate_with_receipt(k, cp, state, cand, diag, committed_ok, receipt, receipt_status, commit_status)
    call require(committed_ok, 'candidate committed')
    call require(receipt_status == FMR_COMMIT_RECEIPT_OK .and. receipt%ready(), 'accepted receipt')
  end subroutine make_receipt

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'EBI21_FIXTURE_FAIL=', trim(label)
      error stop 21
    end if
  end subroutine require

end program test_eb_i21_cross_column_receipt_attack
