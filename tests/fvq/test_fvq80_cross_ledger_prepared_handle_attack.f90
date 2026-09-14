program test_fvq80_cross_ledger_prepared_handle_attack
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  implicit none

  type(energy_trial_ledger_t) :: ledger_a, ledger_b
  type(prepared_energy_trial_t) :: prepared_a, prepared_b, foreign_handle
  integer :: status
  logical :: vulnerability_observed

  call stage_prepared(ledger_a, prepared_a, 101_int64, 0_int64, 0.0_real64, 1.0_real64)
  call stage_prepared(ledger_b, prepared_b, 202_int64, 7_int64, 10.0_real64, 11.0_real64)

  call require(ledger_a%has_prepared_trial(), 'ledger A starts prepared')
  call require(ledger_b%has_prepared_trial(), 'ledger B starts prepared')
  call require(prepared_a%ready() .and. prepared_b%ready(), 'both handles start ready')

  foreign_handle = prepared_b
  call ledger_a%abort_prepared(foreign_handle, status)

  vulnerability_observed = status == ENERGY_LEDGER_OK .and. &
       .not. ledger_a%has_prepared_trial() .and. prepared_a%ready() .and. &
       ledger_b%has_prepared_trial() .and. prepared_b%ready() .and. .not. foreign_handle%ready()

  write(*,'(a,i0)') 'FVQ80_FOREIGN_ABORT_STATUS=', status
  write(*,'(a,l1)') 'FVQ80_LEDGER_A_PREPARED_AFTER_FOREIGN_ABORT=', ledger_a%has_prepared_trial()
  write(*,'(a,l1)') 'FVQ80_ORIGINAL_A_HANDLE_READY_AFTER_FOREIGN_ABORT=', prepared_a%ready()
  write(*,'(a,l1)') 'FVQ80_LEDGER_B_PREPARED_AFTER_FOREIGN_ABORT=', ledger_b%has_prepared_trial()

  if (vulnerability_observed) then
    print '(a)', 'FVQ80_CROSS_LEDGER_PREPARED_HANDLE_PROVENANCE=BLOCKER_REPRODUCED'
  else if (status == ENERGY_LEDGER_INVALID_PROVENANCE .and. ledger_a%has_prepared_trial() .and. prepared_a%ready()) then
    print '(a)', 'FVQ80_CROSS_LEDGER_PREPARED_HANDLE_PROVENANCE=FAIL_CLOSED'
  else
    print '(a)', 'FVQ80_CROSS_LEDGER_PREPARED_HANDLE_PROVENANCE=UNEXPECTED_STATE'
  end if

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
      write(*,'(a,a)') 'FVQ80_TEST_FIXTURE_FAIL=', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq80_cross_ledger_prepared_handle_attack
