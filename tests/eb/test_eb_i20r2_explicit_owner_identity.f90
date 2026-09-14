program test_eb_i20r2_explicit_owner_identity
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_energy_conservation_types, only: ENERGY_EXTERNAL_COMPONENT
  use mod_energy_conservation_ledger, only: energy_trial_ledger_t, prepared_energy_trial_t, &
       ENERGY_LEDGER_OK, ENERGY_LEDGER_INVALID_PROVENANCE
  implicit none

  integer(int64), parameter :: OWNER_A = 8202001_int64
  integer(int64), parameter :: OWNER_B = 8202002_int64
  integer(int64), parameter :: LINEAGE = 82020_int64
  type(energy_trial_ledger_t) :: ledger_a, ledger_b, invalid_ledger
  type(prepared_energy_trial_t) :: prepared_a, prepared_b, foreign_handle
  integer :: status

  call begin_invalid_owner(invalid_ledger, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'non-positive owner id rejected')
  call require(.not. invalid_ledger%has_active_trial(), 'invalid owner leaves no active trial')
  print '(a)', 'EBI20R2_INVALID_OWNER_ID_FAIL_CLOSED=PASS'

  ! Exact same transaction provenance and local generation on two independent
  ! ledgers.  Only the explicit owner token distinguishes them.
  call stage_prepared(ledger_a, prepared_a, OWNER_A, 2.0_real64)
  call stage_prepared(ledger_b, prepared_b, OWNER_B, 3.0_real64)

  foreign_handle = prepared_b
  call ledger_a%abort_prepared(foreign_handle, status)
  call require(status == ENERGY_LEDGER_INVALID_PROVENANCE, 'foreign owner abort rejected')
  call require(ledger_a%has_prepared_trial(), 'target ledger preserved after foreign abort')
  call require(ledger_b%has_prepared_trial(), 'source ledger preserved after foreign abort')
  call require(prepared_a%ready(), 'target own handle preserved after foreign abort')
  call require(prepared_b%ready(), 'source own handle preserved after foreign abort')
  call require(foreign_handle%ready(), 'foreign copy preserved after rejection')
  print '(a)', 'EBI20R2_SAME_TRANSACTION_FOREIGN_OWNER_ABORT_FAIL_CLOSED=PASS'

  call ledger_a%abort_prepared(prepared_a, status)
  call require(status == ENERGY_LEDGER_OK, 'owner A own abort succeeds')
  call require(.not. ledger_a%has_prepared_trial(), 'owner A prepared state consumed')
  call require(.not. prepared_a%ready(), 'owner A handle consumed')

  call ledger_b%abort_prepared(prepared_b, status)
  call require(status == ENERGY_LEDGER_OK, 'owner B own abort succeeds')
  call require(.not. ledger_b%has_prepared_trial(), 'owner B prepared state consumed')
  call require(.not. prepared_b%ready(), 'owner B handle consumed')
  print '(a)', 'EBI20R2_OWN_HANDLE_ABORT_SEMANTICS=PASS'

  print '(a)', 'EBI20R2_EXPLICIT_OWNER_IDENTITY_TEST PASS'

contains

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
    call ledger%begin_trial(owner_id, LINEAGE, 1_int64, 4.0_real64, 5.0_real64, ids, initial_energy, s, 1)
    call require(s == ENERGY_LEDGER_OK, 'begin prepared owner fixture')
    call ledger%record_transfer(ENERGY_EXTERNAL_COMPONENT, ids(1), amount, s)
    call require(s == ENERGY_LEDGER_OK, 'record prepared owner transfer')
    call ledger%set_end_storage(final_energy, s)
    call require(s == ENERGY_LEDGER_OK, 'set prepared owner end storage')
    call ledger%prepare_trial(prepared, s)
    call require(s == ENERGY_LEDGER_OK, 'prepare owner fixture')
    call require(prepared%ready(), 'prepared owner handle ready')
  end subroutine stage_prepared

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'EBI20R2_FAIL=', trim(label)
      error stop 202
    end if
  end subroutine require

end program test_eb_i20r2_explicit_owner_identity
