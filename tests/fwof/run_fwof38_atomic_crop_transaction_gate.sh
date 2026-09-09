#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof38-atomic-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FWO33=b75342a6b9d1249ba7c87b4692acabc97d11ed13
FWO34=85c0f7838d56c63d49f16af8242bdf4cbe4219d9

git show "$FWO33:tests/fwof/test_fwof33_two_phase_crop_window.f90" > "$BUILD/fwof33.f90"
git show "$FWO34:tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90" > "$BUILD/fwof34.f90"

python3 - "$BUILD/fwof33.f90" "$BUILD/fwof34.f90" "$BUILD/fwof38_atomic.f90" <<'PY'
from pathlib import Path
import sys
f33 = Path(sys.argv[1]).read_text(encoding='utf-8')
f34 = Path(sys.argv[2]).read_text(encoding='utf-8')

marker = '\nprogram test_fwof34_accepted_window_runtime_lineage\n'
if marker not in f34:
    raise SystemExit('F-WOF38 missing F-WOF34 module/program boundary')
f34_module = f34.split(marker, 1)[0].rstrip() + '\n\n'

s = f33
s = s.replace('program test_fwof33_two_phase_crop_window',
              'program test_fwof38_atomic_crop_transaction', 1)
s = s.replace('end program test_fwof33_two_phase_crop_window',
              'end program test_fwof38_atomic_crop_transaction', 1)

use_anchor = '  use mod_wofost_two_phase_crop_window\n'
extra_use = '''  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fmr_wofost_accepted_window_lineage
  use mod_fmr_wofost_crop_transaction
  use mod_fwof34_test_model
'''
if s.count(use_anchor) != 1:
    raise SystemExit(f'F-WOF38 use anchor count={s.count(use_anchor)}')
s = s.replace(use_anchor, use_anchor + extra_use, 1)

decl_anchor = '  integer :: status, component_status, count_before\n'
extra_decl = '''  type(kernel_committed_state_t) :: physical_committed
  type(kernel_checkpoint_t) :: physical_checkpoint
  type(kernel_executor_t) :: physical_kernel
  type(fwof34_model_t), target :: physical_model
  type(fwof34_parameters_t) :: physical_parameters
  type(fwof34_forcing_t) :: physical_forcing
  type(canonical_numerical_config_t) :: physical_config
  type(fmr_wofost_accepted_window_t) :: accepted_window
  type(fmr_wofost_trial_contribution_t) :: rejected_physical_trial, accepted_physical_trial
  type(fmr_wofost_accepted_interval_certificate_t) :: accepted_certificate
  type(fmr_wofost_crop_event_token_t) :: event_token
  type(fmr_wofost_crop_event_identity_t) :: event_identity
  logical :: physical_checkpoint_ok, event_available

  type(fmr_wofost_crop_transaction_state_t) :: crop_initial_state
  type(fmr_wofost_crop_transaction_parameters_t) :: crop_parameters
  type(fmr_wofost_crop_event_forcing_t) :: crop_event_forcing, bad_crop_event_forcing
  type(fmr_wofost_crop_transaction_model_t), target :: crop_model, bad_crop_model, policy_crop_model
  type(kernel_committed_state_t) :: crop_committed, bad_crop_committed, policy_crop_committed
  type(kernel_checkpoint_t) :: crop_checkpoint, bad_crop_checkpoint
  type(kernel_executor_t) :: crop_kernel, bad_crop_kernel, policy_crop_kernel
  type(kernel_candidate_state_t) :: crop_kernel_candidate1, crop_kernel_candidate2, &
       crop_duplicate_candidate, bad_crop_candidate, policy_crop_candidate
  type(kernel_result_t) :: crop_result1, crop_result2, crop_duplicate_result, bad_crop_result, policy_crop_result
  type(kernel_diagnostics_t) :: crop_diag1, crop_diag2, crop_duplicate_diag, bad_crop_diag, policy_crop_diag
  type(canonical_numerical_config_t) :: crop_config, bad_policy_config
  class(transaction_state_t), allocatable :: crop_snapshot, candidate_snapshot1, candidate_snapshot2
  type(wofost_crop_owner_state_t) :: crop_snapshot_owner, candidate_snapshot_owner1, candidate_snapshot_owner2
  type(wofost_one_day_forcing_t) :: bad_crop_forcing
  logical :: crop_initialized, crop_checkpoint_ok, snapshot_available, did_commit
  integer :: crop_status, crop_commit_status
  integer(kind=8) :: crop_revision_before
'''
if s.count(decl_anchor) != 1:
    raise SystemExit(f'F-WOF38 declaration anchor count={s.count(decl_anchor)}')
s = s.replace(decl_anchor, decl_anchor + extra_decl, 1)

old_aggregates = '''  aggregates%actual_root_uptake = 3.0_real64
  aggregates%potential_transpiration = 5.0_real64
'''
new_aggregates = '''  ! Build the accepted physical event through the already-qualified F-KT /
  ! F-WOF34 lineage seam. The discarded trial must contribute nothing.
  call setup_physical_committed(physical_committed, 38001_int64, 100.0_real64)
  call setup_physical_solver(physical_parameters, physical_forcing, physical_config)
  call physical_kernel%bind_model(physical_model)
  call physical_committed%capture_checkpoint(physical_checkpoint, physical_checkpoint_ok)
  call require(physical_checkpoint_ok, 'F-WOF38 physical checkpoint')
  call open_wofost_accepted_window(physical_checkpoint, 101.0_real64, accepted_window, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_window%ready(), 'F-WOF38 accepted window open')

  call begin_wofost_trial_contribution(physical_checkpoint, 101.0_real64, rejected_physical_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'F-WOF38 rejected physical trial begin')
  call accumulate_wofost_trial_process_rate(rejected_physical_trial, 100.0_real64, 101.0_real64, &
       300.0_real64, 500.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. rejected_physical_trial%complete(), &
       'F-WOF38 rejected physical trial fill')
  call discard_wofost_trial_contribution(rejected_physical_trial)
  call require(accepted_window%interval_count() == 0, 'F-WOF38 rejected physical trial zero contribution')

  call begin_wofost_trial_contribution(physical_checkpoint, 101.0_real64, accepted_physical_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'F-WOF38 accepted physical trial begin')
  call accumulate_wofost_trial_process_rate(accepted_physical_trial, 100.0_real64, 101.0_real64, &
       3.0_real64, 5.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_physical_trial%complete(), &
       'F-WOF38 accepted physical trial fill')
  call advance_and_commit_physical(physical_kernel, physical_model, physical_parameters, physical_forcing, &
       physical_config, physical_committed, physical_checkpoint, 100.0_real64, 101.0_real64)
  call certify_fkt_accepted_interval(physical_checkpoint, physical_committed, accepted_certificate, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_certificate%ready(), 'F-WOF38 accepted certificate')
  call admit_wofost_accepted_trial(accepted_window, accepted_certificate, accepted_physical_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_window%complete(), 'F-WOF38 accepted trial admission')
  call prepare_wofost_crop_event_delivery(accepted_window, aggregates, event_token, event_available, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. event_available .and. event_token%ready(), &
       'F-WOF38 frozen event prepare')
  call identify_wofost_crop_event(event_token, event_identity, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. event_identity%ready(), 'F-WOF38 event identity')
  call require(bitwise_equal(aggregates%actual_root_uptake, 3.0_real64), 'F-WOF38 exact accepted IQROT')
  call require(bitwise_equal(aggregates%potential_transpiration, 5.0_real64), 'F-WOF38 exact accepted IPTRA')
  print '(a)', 'FWOF38_REJECTED_PHYSICAL_TRIAL_ZERO_EVENT_CONTRIBUTION=PASS'
  print '(a)', 'FWOF38_ACCEPTED_PHYSICAL_EVENT_EXACT_CARRIER=PASS'
'''
if s.count(old_aggregates) != 1:
    raise SystemExit(f'F-WOF38 aggregate anchor count={s.count(old_aggregates)}')
s = s.replace(old_aggregates, new_aggregates, 1)

update_anchor = '''  update_parameters%development_stage_end = 2.0_real64
  update_parameters%leaf_lifespan = 10.0_real64
'''
setup_crop = update_anchor + '''
  call prepare_fmr_wofost_crop_event_forcing(accepted_window, forcing, crop_event_forcing, crop_status)
  call require(crop_status == FMR_WOF38_OK .and. crop_event_forcing%ready(), 'F-WOF38 event forcing construction')
  call construct_fmr_wofost_crop_transaction_parameters(bundle, update_parameters, 0.005_real64, 0.002_real64, &
       crop_parameters, crop_status)
  call require(crop_status == FMR_WOF38_OK .and. crop_parameters%ready(), 'F-WOF38 crop parameters')
  call initialize_fmr_wofost_crop_transaction_state(seed, crop_initial_state, crop_status)
  call require(crop_status == FMR_WOF38_OK .and. crop_initial_state%ready(), 'F-WOF38 crop transaction state')
  call setup_crop_kernel_committed(crop_initial_state, crop_committed, 3801_int64, 100.0_real64)
  call setup_crop_config(crop_config)
  call crop_kernel%bind_model(crop_model)
  call crop_committed%capture_checkpoint(crop_checkpoint, crop_checkpoint_ok)
  call require(crop_checkpoint_ok, 'F-WOF38 crop checkpoint')

  ! Two independent trials from the same committed checkpoint must produce
  ! replay-equivalent candidate state without touching the committed owner.
  call crop_kernel%advance_interval(crop_parameters, crop_committed, crop_event_forcing, crop_config, &
       100.0_real64, 101.0_real64, crop_result1, crop_kernel_candidate1, crop_diag1, crop_checkpoint)
  call require(crop_result1%status == CANONICAL_STATUS_COMPLETED .and. crop_result1%completed, &
       'F-WOF38 first crop F-KT trial')
  call require(crop_kernel_candidate1%ready(), 'F-WOF38 first crop candidate ready')
  call require(crop_result1%mass%complete .and. crop_result1%mass%residual == 0.0_real64, &
       'F-WOF38 crop transaction zero water ledger residual')
  call require(crop_diag1%temporal_acceptance_source == TX_TEMPORAL_MODEL_CERTIFICATE, &
       'F-WOF38 fixed crop event model certificate')

  call crop_kernel%advance_interval(crop_parameters, crop_committed, crop_event_forcing, crop_config, &
       100.0_real64, 101.0_real64, crop_result2, crop_kernel_candidate2, crop_diag2, crop_checkpoint)
  call require(crop_result2%status == CANONICAL_STATUS_COMPLETED .and. crop_kernel_candidate2%ready(), &
       'F-WOF38 replay crop F-KT trial')

  call crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF38 committed crop snapshot before publication')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, seed), &
         'F-WOF38 committed owner unchanged before publication')
    call require(.not. tx%receipt_ready(), 'F-WOF38 no committed event receipt before publication')
  class default
    call require(.false., 'F-WOF38 committed crop state type before publication')
  end select
  print '(a)', 'FWOF38_PRECOMMIT_OWNER_AND_RECEIPT_UNCHANGED=PASS'
'''
if s.count(update_anchor) != 1:
    raise SystemExit(f'F-WOF38 crop setup anchor count={s.count(update_anchor)}')
s = s.replace(update_anchor, setup_crop, 1)

first_complete = "  call require(same_owner(seed, seed_before), 'complete cannot mutate committed seed')\n"
post_complete = first_complete + '''
  ! Compare both F-KT trial candidates with the independently qualified F-WOF33
  ! direct candidate before publishing either one.
  call crop_kernel_candidate1%snapshot(candidate_snapshot1, snapshot_available)
  call require(snapshot_available, 'F-WOF38 first candidate snapshot')
  select type (tx => candidate_snapshot1)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(candidate_snapshot_owner1, snapshot_available)
    call require(snapshot_available .and. same_owner(candidate_snapshot_owner1, candidate1), &
         'F-WOF38 first F-KT owner equals direct F-WOF33 candidate')
    call require(tx%receipt_ready() .and. tx%consumed_event(event_identity), &
         'F-WOF38 first candidate contains matching event receipt')
  class default
    call require(.false., 'F-WOF38 first candidate state type')
  end select

  call crop_kernel_candidate2%snapshot(candidate_snapshot2, snapshot_available)
  call require(snapshot_available, 'F-WOF38 second candidate snapshot')
  select type (tx => candidate_snapshot2)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(candidate_snapshot_owner2, snapshot_available)
    call require(snapshot_available .and. same_owner(candidate_snapshot_owner2, candidate1), &
         'F-WOF38 replay F-KT owner equals direct candidate')
    call require(tx%receipt_ready() .and. tx%consumed_event(event_identity), &
         'F-WOF38 replay candidate contains same receipt')
  class default
    call require(.false., 'F-WOF38 replay candidate state type')
  end select
  call require(same_owner(candidate_snapshot_owner1, candidate_snapshot_owner2), &
       'F-WOF38 same checkpoint candidate replay identity')
  print '(a)', 'FWOF38_SAME_CHECKPOINT_OWNER_RECEIPT_CANDIDATE_REPLAY=PASS'

  ! Discard one complete candidate. Only the other candidate may publish.
  call crop_kernel%rollback_candidate(crop_kernel_candidate1, crop_diag1)
  call require(.not. crop_kernel_candidate1%ready(), 'F-WOF38 discarded first crop candidate')
  call crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF38 committed snapshot after rollback')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, seed) .and. .not. tx%receipt_ready(), &
         'F-WOF38 rollback leaves owner and receipt uncommitted')
  class default
    call require(.false., 'F-WOF38 rollback committed state type')
  end select
  print '(a)', 'FWOF38_ROLLBACK_LEAVES_OWNER_AND_RECEIPT_AT_CHECKPOINT=PASS'

  crop_revision_before = crop_committed%current_revision()
  call crop_kernel%commit_candidate(crop_committed, crop_kernel_candidate2, crop_diag2, did_commit, crop_commit_status)
  call require(did_commit .and. crop_commit_status == KERNEL_COMMIT_STATUS_COMMITTED, &
       'F-WOF38 atomic crop candidate commit')
  call require(crop_committed%current_revision() == crop_revision_before + 1, &
       'F-WOF38 exactly one crop revision publication')
  call crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF38 committed snapshot after publication')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, candidate1), &
         'F-WOF38 committed owner equals direct candidate')
    call require(tx%receipt_ready() .and. tx%consumed_event(event_identity), &
         'F-WOF38 matching event receipt committed with owner')
  class default
    call require(.false., 'F-WOF38 committed state type after publication')
  end select
  call require(.not. accepted_window%delivery_committed(), &
       'F-WOF38 legacy delivery bit is not a second publication authority')
  print '(a)', 'FWOF38_OWNER_AND_EVENT_RECEIPT_COMMIT_IN_ONE_FKT_REVISION=PASS'
  print '(a)', 'FWOF38_LEGACY_DELIVERY_BIT_NOT_SECOND_COMMIT_AUTHORITY=PASS'

  ! Replaying the original event against the now-advanced crop timeline cannot
  ! advance owner or receipt a second time.
  crop_revision_before = crop_committed%current_revision()
  call crop_kernel%advance_interval(crop_parameters, crop_committed, crop_event_forcing, crop_config, &
       100.0_real64, 101.0_real64, crop_duplicate_result, crop_duplicate_candidate, crop_duplicate_diag)
  call require(crop_duplicate_result%status == KERNEL_STATUS_TIME_MISMATCH .and. &
       .not. crop_duplicate_candidate%ready(), 'F-WOF38 duplicate original interval rejected')
  call require(crop_committed%current_revision() == crop_revision_before, &
       'F-WOF38 duplicate event leaves revision unchanged')
  call crop_kernel%advance_interval(crop_parameters, crop_committed, crop_event_forcing, crop_config, &
       101.0_real64, 102.0_real64, crop_duplicate_result, crop_duplicate_candidate, crop_duplicate_diag)
  call require(crop_duplicate_result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. &
       .not. crop_duplicate_candidate%ready(), 'F-WOF38 stale event cannot move to next crop interval')
  call require(crop_committed%current_revision() == crop_revision_before, &
       'F-WOF38 stale next-interval replay leaves revision unchanged')
  print '(a)', 'FWOF38_DUPLICATE_EVENT_ZERO_EXTRA_CROP_ADVANCEMENT=PASS'

  ! A crop-physics failure from the same accepted source event must leave a
  ! fresh committed crop owner and receipt completely unchanged.
  bad_crop_forcing = forcing
  bad_crop_forcing%minimum_temperature = nanv
  call prepare_fmr_wofost_crop_event_forcing(accepted_window, bad_crop_forcing, bad_crop_event_forcing, crop_status)
  call require(crop_status == FMR_WOF38_OK .and. bad_crop_event_forcing%ready(), &
       'F-WOF38 bad crop event remains source-provenance valid')
  call setup_crop_kernel_committed(crop_initial_state, bad_crop_committed, 3802_int64, 100.0_real64)
  call bad_crop_kernel%bind_model(bad_crop_model)
  call bad_crop_committed%capture_checkpoint(bad_crop_checkpoint, crop_checkpoint_ok)
  call require(crop_checkpoint_ok, 'F-WOF38 failure crop checkpoint')
  call bad_crop_kernel%advance_interval(crop_parameters, bad_crop_committed, bad_crop_event_forcing, crop_config, &
       100.0_real64, 101.0_real64, bad_crop_result, bad_crop_candidate, bad_crop_diag, bad_crop_checkpoint)
  call require(bad_crop_result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. .not. bad_crop_candidate%ready(), &
       'F-WOF38 crop failure no candidate')
  call require(bad_crop_committed%current_revision() == 0, 'F-WOF38 crop failure no revision')
  call bad_crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF38 failure committed snapshot')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, seed) .and. .not. tx%receipt_ready(), &
         'F-WOF38 crop failure owner receipt unchanged')
  class default
    call require(.false., 'F-WOF38 failure committed state type')
  end select
  print '(a)', 'FWOF38_FAILED_CROP_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS'

  ! A policy that permits dt shrinking is not admitted for this fixed one-day
  ! crop event, preventing silent half-day or shorter WOFOST evolution.
  bad_policy_config = crop_config
  bad_policy_config%transaction%max_retries = 1
  call setup_crop_kernel_committed(crop_initial_state, policy_crop_committed, 3803_int64, 100.0_real64)
  call policy_crop_kernel%bind_model(policy_crop_model)
  call policy_crop_kernel%advance_interval(crop_parameters, policy_crop_committed, crop_event_forcing, bad_policy_config, &
       100.0_real64, 101.0_real64, policy_crop_result, policy_crop_candidate, policy_crop_diag)
  call require(policy_crop_result%status == KERNEL_STATUS_NOT_ADMITTED .and. .not. policy_crop_candidate%ready(), &
       'F-WOF38 retry-shrinking policy rejected')
  call require(policy_crop_committed%current_revision() == 0, 'F-WOF38 invalid policy no crop mutation')
  print '(a)', 'FWOF38_FIXED_ONE_DAY_EVENT_FORBIDS_RETRY_DT_SHRINKING=PASS'
'''
if s.count(first_complete) != 1:
    raise SystemExit(f'F-WOF38 first completion anchor count={s.count(first_complete)}')
s = s.replace(first_complete, post_complete, 1)

final_anchor = "  print '(a)', 'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'\n\ncontains\n"
final_extra = '''  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'

contains
'''
if s.count(final_anchor) != 1:
    raise SystemExit(f'F-WOF38 final anchor count={s.count(final_anchor)}')
s = s.replace(final_anchor, "  print '(a)', 'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'\n" + final_extra, 1)

helper_anchor = '  subroutine seed_active_owner(state)\n'
helpers = '''  subroutine setup_physical_committed(state, lineage_id, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(kind=8), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fwof34_state_t :: physical)
    select type (physical)
    type is (fwof34_state_t)
      physical%water = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'F-WOF38 initialize physical committed state')
  end subroutine setup_physical_committed

  subroutine setup_physical_solver(p, f, c)
    type(fwof34_parameters_t), intent(out) :: p
    type(fwof34_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%flux_rate = 0.1_real64
    f%scale = 1.0_real64
    c%transaction%temporal_tolerance = 1.0_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine setup_physical_solver

  subroutine advance_and_commit_physical(k, m, p, f, c, state, checkpoint, t0, t1)
    type(kernel_executor_t), intent(inout) :: k
    type(fwof34_model_t), target, intent(inout) :: m
    type(fwof34_parameters_t), intent(in) :: p
    type(fwof34_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: t0, t1
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: committed_ok
    integer :: commit_status

    if (.not. same_type_as(m, m)) error stop 'F-WOF38 unreachable physical model type'
    call k%advance_interval(p, state, f, c, t0, t1, result, candidate, diagnostics, checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-WOF38 physical trial completes')
    call require(candidate%ready(), 'F-WOF38 physical candidate materialized')
    call k%commit_candidate(state, candidate, diagnostics, committed_ok, commit_status)
    call require(committed_ok .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'F-WOF38 physical candidate commits')
  end subroutine advance_and_commit_physical

  subroutine setup_crop_kernel_committed(initial_state, state, lineage_id, initial_time)
    type(fmr_wofost_crop_transaction_state_t), intent(in) :: initial_state
    type(kernel_committed_state_t), intent(out) :: state
    integer(kind=8), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fmr_wofost_crop_transaction_state_t :: physical)
    select type (typed => physical)
    type is (fmr_wofost_crop_transaction_state_t)
      typed = initial_state
    class default
      error stop 'F-WOF38 crop transaction allocation failure'
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'F-WOF38 initialize crop committed state')
  end subroutine setup_crop_kernel_committed

  subroutine setup_crop_config(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 0.0_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 0
    config%max_committed_substeps = 1
    config%progress_tolerance = 0.0_real64
  end subroutine setup_crop_config

'''
if s.count(helper_anchor) != 1:
    raise SystemExit(f'F-WOF38 helper anchor count={s.count(helper_anchor)}')
s = s.replace(helper_anchor, helpers + helper_anchor, 1)

Path(sys.argv[3]).write_text(f34_module + s, encoding='utf-8')
print('FWOF38_ATOMIC_TEST_MATERIALIZED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/crop/mod_wofost_one_day_rate_state_view.f90
  src/crop/mod_wofost_rate_table.f90
  src/crop/mod_wofost_rate_parameters.f90
  src/crop/mod_wofost_prepare_assimilation.f90
  src/crop/mod_wofost_finalize_rates.f90
  src/crop/mod_wofost_two_phase_crop_window.f90
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
  src/runtime/mod_fmr_wofost_crop_transaction.f90
)

for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  pushd "$OUT" >/dev/null
  for src in "${SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$src"
  done
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$BUILD/fwof38_atomic.f90" ./*.o -o test
  ./test > output.txt 2>&1
  popd >/dev/null
  for marker in \
    'FWOF38_REJECTED_PHYSICAL_TRIAL_ZERO_EVENT_CONTRIBUTION=PASS' \
    'FWOF38_ACCEPTED_PHYSICAL_EVENT_EXACT_CARRIER=PASS' \
    'FWOF38_PRECOMMIT_OWNER_AND_RECEIPT_UNCHANGED=PASS' \
    'FWOF38_SAME_CHECKPOINT_OWNER_RECEIPT_CANDIDATE_REPLAY=PASS' \
    'FWOF38_ROLLBACK_LEAVES_OWNER_AND_RECEIPT_AT_CHECKPOINT=PASS' \
    'FWOF38_OWNER_AND_EVENT_RECEIPT_COMMIT_IN_ONE_FKT_REVISION=PASS' \
    'FWOF38_LEGACY_DELIVERY_BIT_NOT_SECOND_COMMIT_AUTHORITY=PASS' \
    'FWOF38_DUPLICATE_EVENT_ZERO_EXTRA_CROP_ADVANCEMENT=PASS' \
    'FWOF38_FAILED_CROP_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS' \
    'FWOF38_FIXED_ONE_DAY_EVENT_FORBIDS_RETRY_DT_SHRINKING=PASS' \
    'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' \
    'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  done
  echo "FWOF38_ATOMIC_CROP_TRANSACTION_O${OPT}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'
