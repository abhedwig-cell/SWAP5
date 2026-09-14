program test_eb_i20r1_cross_ledger_prepared_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  implicit none

  type(energy_trial_ledger_t) :: ledger_a, ledger_b
  type(prepared_energy_trial_t) :: prepared_a, prepared_b, foreign_handle
  integer :: status

  call stage_prepared(ledger_a, prepared_a, 101_int64, 0_int64, 0.0_real64, 1.0_real64)
  call stage_prepared(ledger_b, prepared_b, 202_int64, 7_int64, 10.0_real64, 11.0_real64)

  foreign_handle = prepared_b
  call ledger_a%abort_prepared(foreign_handle, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'foreign abort rejected')
  call require(ledger_a%has_prepared_trial() .and. prepared_a%ready(), 'ledger A preserved')
  call require(ledger_b%has_prepared_trial() .and. prepared_b%ready(), 'ledger B preserved')
  call require(foreign_handle%ready(), 'foreign handle remains untouched after rejection')
  print '(a)', 'EBI20R1_CROSS_LEDGER_ABORT_FAIL_CLOSED=PASS'

  call ledger_a%abort_prepared(prepared_a, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger A own abort succeeds')
  call require(.not. ledger_a%has_prepared_trial() .and. .not. prepared_a%ready(), 'ledger A own handle consumed')

  call ledger_b%abort_prepared(prepared_b, status)
  call require(status == ENERGY_LEDGER_OK, 'ledger B own abort succeeds')
  call require(.not. ledger_b%has_prepared_trial() .and. .not. prepared_b%ready(), 'ledger B own handle consumed')

  print '(a)', 'EBI20R1_CROSS_LEDGER_PREPARED_PROVENANCE_TEST PASS'

contains

  subroutine stage_prepared(ledger, prepared, lineage, revision, t0, t1)
    type(energy_trial_ledger_t), intent(inout) :: ledger
    type(prepared_energy_trial_t), intent(out) :: prepared
    integer(int64), intent(in) :: lineage, revision
    real(real64), intent(in) :: t0, t1
    integer(int64) :: ids(1)
    real(real64) :: initial_energy(1), final_energy(1)
    integer :: s

    ids = [1_int64]
    initial_energy = [10.0_real64]
    final_energy = [12.0_real64]
    call ledger%begin_trial(lineage, revision, t0, t1, ids, initial_energy, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin trial')
    call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), 2.0_real64, s)
    call require(s == ENERGY_LEDGER_OK, 'record transfer')
    call ledger%set_end_storage(final_energy, s)
    call require(s == ENERGY_LEDGER_OK, 'set end storage')
    call ledger%prepare_trial(prepared, s)
    call require(s == ENERGY_LEDGER_OK .and. prepared%ready(), 'prepare trial')
  end subroutine stage_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i20r1_cross_ledger_prepared_provenance
