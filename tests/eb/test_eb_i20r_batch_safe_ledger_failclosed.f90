program test_eb_i20r_batch_safe_ledger_failclosed
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, &
       energy_commit_record_t, ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  implicit none

  type(energy_trial_ledger_t) :: ledger
  type(prepared_energy_trial_t) :: prepared, stale, current
  type(energy_commit_record_t) :: record
  type(fmr_accepted_commit_receipt_t) :: invalid_receipt
  integer :: status

  call stage_prepared(ledger, prepared, 101_int64, 0_int64, 0.0_real64, 1.0_real64)
  call ledger%commit_prepared(prepared, invalid_receipt, record, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'invalid receipt returns provenance status')
  call require(.not. record%ready(), 'invalid receipt publishes no record')
  call require(ledger%has_prepared_trial() .and. prepared%ready(), 'invalid receipt preserves prepared state')
  print '(a)', 'EBI20R_INVALID_RECEIPT_FAIL_CLOSED_NO_TERMINATION=PASS'

  call ledger%abort_prepared(prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'valid abort succeeds')
  call require(.not. ledger%has_prepared_trial() .and. .not. prepared%ready(), 'valid abort clears prepared state')
  print '(a)', 'EBI20R_VALID_ABORT_CONSUMES_PREPARED=PASS'

  call stage_prepared(ledger, prepared, 101_int64, 0_int64, 1.0_real64, 2.0_real64)
  stale = prepared
  call ledger%abort_prepared(prepared, status)
  call require(status == ENERGY_LEDGER_OK, 'first generation abort succeeds')

  call stage_prepared(ledger, current, 101_int64, 0_int64, 2.0_real64, 3.0_real64)
  call ledger%abort_prepared(stale, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'stale generation rejected')
  call require(ledger%has_prepared_trial() .and. current%ready(), 'stale abort preserves current prepared state')
  print '(a)', 'EBI20R_STALE_GENERATION_FAIL_CLOSED_NO_TERMINATION=PASS'

  call ledger%abort_prepared(current, status)
  call require(status == ENERGY_LEDGER_OK .and. .not. ledger%has_prepared_trial(), 'current generation abort succeeds')

  call ledger%abort_prepared(current, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'empty abort returns provenance status')
  print '(a)', 'EBI20R_EMPTY_ABORT_FAIL_CLOSED_NO_TERMINATION=PASS'

  print '(a)', 'EBI20R_BATCH_SAFE_LEDGER_FAILCLOSED_TEST PASS'

contains

  subroutine stage_prepared(e, p, lineage, revision, t0, t1)
    type(energy_trial_ledger_t), intent(inout) :: e
    type(prepared_energy_trial_t), intent(out) :: p
    integer(int64), intent(in) :: lineage, revision
    real(real64), intent(in) :: t0, t1
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    integer :: s

    ids = [1_int64]
    initial_energy = [10.0_real64]
    final_energy = [12.0_real64]
    call e%begin_trial(lineage, revision, t0, t1, ids, initial_energy, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin prepared fixture')
    call e%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), 2.0_real64, s)
    call require(s == ENERGY_LEDGER_OK, 'record prepared fixture transfer')
    call e%set_end_storage(final_energy, s)
    call require(s == ENERGY_LEDGER_OK, 'set prepared fixture end storage')
    call e%prepare_trial(p, s)
    call require(s == ENERGY_LEDGER_OK .and. p%ready(), 'prepare fixture')
  end subroutine stage_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i20r_batch_safe_ledger_failclosed
