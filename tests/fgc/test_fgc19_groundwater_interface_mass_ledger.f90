program test_fgc19_groundwater_interface_mass_ledger
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK, GW_MASS_LEDGER_TRIAL_ALREADY_ACTIVE, &
       GW_MASS_LEDGER_NO_ACTIVE_TRIAL, GW_MASS_LEDGER_INVALID_EXCHANGE
  implicit none

  type(groundwater_interface_mass_ledger_t) :: ledger
  type(groundwater_interface_mass_snapshot_t) :: snap
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_lineage_t) :: lineage
  integer :: status
  real(real64) :: nan_value

  window%t0 = 4100.125_real64
  window%t1 = 4100.1875_real64
  lineage%coupling_id = 10_int64
  lineage%swap_lineage_id = 20_int64
  lineage%swap_origin_revision = 3_int64
  lineage%groundwater_lineage_id = 30_int64
  lineage%groundwater_origin_revision = 7_int64
  lineage%candidate_revision = 8_int64

  call ledger%stage_exchange(window, lineage, 0.004_real64, status)
  call require(status == GW_MASS_LEDGER_OK .and. ledger%has_active_trial(), 'stage first trial')
  call ledger%stage_exchange(window, lineage, 0.002_real64, status)
  call require(status == GW_MASS_LEDGER_TRIAL_ALREADY_ACTIVE, 'second active trial rejected')
  call ledger%discard_trial(status)
  call require(status == GW_MASS_LEDGER_OK .and. .not. ledger%has_active_trial(), 'discard trial')
  call ledger%snapshot(snap)
  call require(snap%available, 'snapshot after discard')
  call require(snap%committed_exchange_count == 0 .and. snap%discarded_trial_count == 1, 'discard not committed')
  call require(snap%committed_swap_outward_exchange_m == 0.0_real64, 'discard leaves committed exchange unchanged')
  call require(snap%conservation_residual_m == 0.0_real64, 'zero residual after discard')

  call ledger%stage_exchange(window, lineage, 0.004_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'restage accepted trial')
  call ledger%commit_trial(status)
  call require(status == GW_MASS_LEDGER_OK, 'commit trial')
  call ledger%snapshot(snap)
  call require(snap%committed_exchange_count == 1 .and. snap%discarded_trial_count == 1, 'commit counters')
  call require(snap%committed_swap_outward_exchange_m == 0.004_real64, 'canonical swap amount')
  call require(snap%committed_groundwater_outward_exchange_m == -snap%committed_swap_outward_exchange_m, &
       'groundwater amount exact negative')
  call require(snap%conservation_residual_m == 0.0_real64, 'exact interface conservation')

  call ledger%commit_trial(status)
  call require(status == GW_MASS_LEDGER_NO_ACTIVE_TRIAL, 'double commit rejected')
  call ledger%snapshot(snap)
  call require(snap%committed_exchange_count == 1, 'double commit cannot mutate accounting')

  lineage%candidate_revision = 9_int64
  call ledger%stage_exchange(window, lineage, -0.0015_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'negative exchange direction accepted')
  call ledger%commit_trial(status)
  call require(status == GW_MASS_LEDGER_OK, 'second commit')
  call ledger%snapshot(snap)
  call require(abs(snap%committed_swap_outward_exchange_m-0.0025_real64) < 1.0e-16_real64, 'signed accumulation')
  call require(snap%committed_groundwater_outward_exchange_m == -snap%committed_swap_outward_exchange_m, &
       'cumulative exact action reaction')
  call require(snap%conservation_residual_m == 0.0_real64, 'cumulative exact conservation')

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  lineage%candidate_revision = 10_int64
  call ledger%stage_exchange(window, lineage, nan_value, status)
  call require(status == GW_MASS_LEDGER_INVALID_EXCHANGE .and. .not. ledger%has_active_trial(), 'NaN fails closed')

  write(*,'(a)') 'FGC19_INTERFACE_MASS_LEDGER=PASS'
  write(*,'(a)') 'FGC19_REJECTED_TRIAL_NOT_BOOKED=PASS'
  write(*,'(a)') 'FGC19_COMMIT_ONCE=PASS'
  write(*,'(a)') 'FGC19_EXACT_ACTION_REACTION=PASS'
  write(*,'(a)') 'FGC19_NO_INTERFACE_MASS_TOLERANCE=PASS'

contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,a)') 'FGC19_TEST_FAIL: ', trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fgc19_groundwater_interface_mass_ledger
