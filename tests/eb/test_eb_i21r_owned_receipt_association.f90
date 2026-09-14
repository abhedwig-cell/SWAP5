program test_eb_i21r_owned_receipt_association
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  use mod_fmr_owned_commit_receipt, only: fmr_owned_commit_receipt_t, fmr_commit_candidate_with_owned_receipt
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, energy_commit_record_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  use mod_fvq84_receipt_model
  implicit none

  integer(int64), parameter :: SHARED_LINEAGE = 922021_int64
  integer(int64), parameter :: COLUMN_A = 22001_int64
  integer(int64), parameter :: COLUMN_B = 22002_int64
  type(kernel_executor_t) :: kernel_a, kernel_b
  type(fvq84_model_t), target :: model_a, model_b
  type(fvq84_parameters_t) :: parameters_a, parameters_b
  type(fvq84_forcing_t) :: forcing_a, forcing_b
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_a, committed_b
  type(fmr_owned_commit_receipt_t) :: owned_a, owned_b
  type(fmr_accepted_commit_receipt_t) :: exported_a
  type(energy_trial_ledger_t) :: ledger_a
  type(prepared_energy_trial_t) :: prepared_a
  type(energy_commit_record_t) :: record
  integer(int64) :: ids(1)
  real(real64) :: initial_energy(1), final_energy(1), rt0, rt1
  integer :: status
  logical :: available

  call setup_config(config)
  parameters_a%inflow_rate = 0.125_real64
  parameters_b%inflow_rate = 0.375_real64
  forcing_a%multiplier = 1.0_real64
  forcing_b%multiplier = 1.0_real64
  call kernel_a%bind_model(model_a)
  call kernel_b%bind_model(model_b)
  call initialize_committed(committed_a, 4.0_real64)
  call initialize_committed(committed_b, 9.0_real64)

  call make_owned_receipt(COLUMN_A, kernel_a, parameters_a, forcing_a, config, committed_a, owned_a)
  call make_owned_receipt(COLUMN_B, kernel_b, parameters_b, forcing_b, config, committed_b, owned_b)
  call require(owned_a%ready() .and. owned_b%ready(), 'owned receipts ready')
  call require(owned_a%owner_instance_id() == COLUMN_A, 'A owner bound')
  call require(owned_b%owner_instance_id() == COLUMN_B, 'B owner bound')
  call require(owned_a%current_lineage_id() == owned_b%current_lineage_id(), 'shared scalar lineage')
  call require(owned_a%origin_revision() == owned_b%origin_revision(), 'shared scalar origin revision')
  call require(owned_a%committed_revision() == owned_b%committed_revision(), 'shared scalar committed revision')
  print '(a)', 'EBI21R_DISTINCT_COLUMNS_SAME_SCALAR_RECEIPT_TUPLE=CONFIRMED'

  call owned_a%export_accepted_receipt(exported_a, available)
  call require(available .and. exported_a%ready(), 'generic receipt export ready')
  call require(exported_a%current_lineage_id() == owned_a%current_lineage_id(), 'generic export lineage preserved')
  call require(exported_a%origin_revision() == owned_a%origin_revision(), 'generic export origin revision preserved')
  call require(exported_a%committed_revision() == owned_a%committed_revision(), 'generic export committed revision preserved')
  print '(a)', 'EBI21R_GENERIC_RECEIPT_EXPORT_PRESERVED=PASS'

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

  call require(.not. ledger_a%prepared_ready_for_receipt(prepared_a, owned_b), &
       'foreign-column owned receipt must not be ready')
  call ledger_a%commit_prepared(prepared_a, owned_b, record, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'foreign-column commit fail closed')
  call require(.not. record%ready(), 'foreign-column commit publishes no record')
  call require(ledger_a%has_prepared_trial(), 'foreign-column rejection preserves rightful prepared state')
  call require(prepared_a%ready(), 'foreign-column rejection preserves rightful handle')
  print '(a)', 'EBI21R_OWN_HANDLE_FOREIGN_COLUMN_RECEIPT_FAIL_CLOSED=PASS'

  call require(ledger_a%prepared_ready_for_receipt(prepared_a, owned_a), 'own receipt must be ready')
  call ledger_a%commit_prepared(prepared_a, owned_a, record, status)
  call require(status == ENERGY_LEDGER_OK .and. record%ready(), 'own receipt commits prepared energy')
  call require(.not. ledger_a%has_prepared_trial(), 'own commit consumes ledger prepared state exactly once')
  call require(.not. prepared_a%ready(), 'own commit consumes prepared handle exactly once')
  call require(record%current_lineage_id() == SHARED_LINEAGE, 'record lineage')
  call require(record%origin_revision() == 0_int64, 'record origin revision')
  call require(record%committed_revision() == 1_int64, 'record committed revision')
  call record%origin_interval(rt0, rt1, available)
  call require(available .and. same_time(rt0, 0.0_real64) .and. same_time(rt1, 1.0_real64), 'record interval')
  print '(a)', 'EBI21R_RIGHTFUL_OWNER_COMMIT_EXACTLY_ONCE=PASS'
  print '(a)', 'EBI21R_CROSS_COLUMN_RECEIPT_ASSOCIATION_REMEDIATION=PASS'

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

  subroutine make_owned_receipt(owner_id, k, p, f, c, state, receipt)
    integer(int64), intent(in) :: owner_id
    type(kernel_executor_t), intent(inout) :: k
    type(fvq84_parameters_t), intent(in) :: p
    type(fvq84_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(fmr_owned_commit_receipt_t), intent(out) :: receipt
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
    call fmr_commit_candidate_with_owned_receipt(owner_id, k, cp, state, cand, diag, committed_ok, receipt, &
         receipt_status, commit_status)
    call require(committed_ok, 'candidate committed')
    call require(receipt_status == 0 .and. receipt%ready(), 'owned accepted receipt')
  end subroutine make_owned_receipt

  logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'EBI21R_FIXTURE_FAIL=', trim(label)
      error stop 211
    end if
  end subroutine require

end program test_eb_i21r_owned_receipt_association
