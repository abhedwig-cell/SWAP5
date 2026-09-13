#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof37-prepared-candidate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FWO33=b75342a6b9d1249ba7c87b4692acabc97d11ed13
FWO34=85c0f7838d56c63d49f16af8242bdf4cbe4219d9

git show "$FWO33:tests/fwof/test_fwof33_two_phase_crop_window.f90" > "$BUILD/fwof33.f90"
git show "$FWO34:tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90" > "$BUILD/fwof34.f90"

python3 - "$BUILD/fwof33.f90" "$BUILD/fwof34.f90" "$BUILD/fwof37_cross_seam.f90" <<'PY'
from pathlib import Path
import sys
f33 = Path(sys.argv[1]).read_text(encoding='utf-8')
f34 = Path(sys.argv[2]).read_text(encoding='utf-8')

# Reuse only the already-qualified F-WOF34 synthetic F-KT model module. The
# cross-seam program itself is the frozen F-WOF33 program with narrowly scoped
# substitutions that source its accepted aggregates from F-WOF34 lineage.
marker = '\nprogram test_fwof34_accepted_window_runtime_lineage\n'
if marker not in f34:
    raise SystemExit('F-WOF37 missing F-WOF34 module/program boundary')
f34_module = f34.split(marker, 1)[0].rstrip() + '\n\n'

s = f33
s = s.replace('program test_fwof33_two_phase_crop_window',
              'program test_fwof37_prepared_crop_candidate', 1)
s = s.replace('end program test_fwof33_two_phase_crop_window',
              'end program test_fwof37_prepared_crop_candidate', 1)

use_anchor = '  use mod_wofost_two_phase_crop_window\n'
extra_use = '''  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fmr_wofost_accepted_window_lineage
  use mod_fwof34_test_model
'''
if s.count(use_anchor) != 1:
    raise SystemExit(f'F-WOF37 use anchor count={s.count(use_anchor)}')
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
  type(fmr_wofost_crop_event_token_t) :: delivery_token, replay_token
  type(wofost_accepted_window_aggregates_t) :: replay_aggregates
  logical :: checkpoint_ok, delivery_available
'''
if s.count(decl_anchor) != 1:
    raise SystemExit(f'F-WOF37 declaration anchor count={s.count(decl_anchor)}')
s = s.replace(decl_anchor, decl_anchor + extra_decl, 1)

old_aggregates = '''  aggregates%actual_root_uptake = 3.0_real64
  aggregates%potential_transpiration = 5.0_real64
'''
new_aggregates = '''  ! Build the exact accepted aggregate carrier through the qualified F-KT /
  ! F-WOF34 lineage seam. A discarded trial is deliberately evaluated first;
  ! only the subsequent committed trial may enter the accepted crop window.
  call setup_physical_committed(physical_committed, 3701_int64, 100.0_real64)
  call setup_physical_solver(physical_parameters, physical_forcing, physical_config)
  call physical_kernel%bind_model(physical_model)
  call physical_committed%capture_checkpoint(physical_checkpoint, checkpoint_ok)
  call require(checkpoint_ok, 'F-WOF37 physical checkpoint')
  call open_wofost_accepted_window(physical_checkpoint, 101.0_real64, accepted_window, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_window%ready(), 'F-WOF37 accepted window open')

  call begin_wofost_trial_contribution(physical_checkpoint, 101.0_real64, rejected_physical_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'F-WOF37 rejected trial begin')
  call accumulate_wofost_trial_process_rate(rejected_physical_trial, 100.0_real64, 101.0_real64, &
       300.0_real64, 500.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. rejected_physical_trial%complete(), 'F-WOF37 rejected trial fill')
  call discard_wofost_trial_contribution(rejected_physical_trial)
  call require(accepted_window%interval_count() == 0, 'F-WOF37 rejected trial zero accepted contribution')

  call begin_wofost_trial_contribution(physical_checkpoint, 101.0_real64, accepted_physical_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'F-WOF37 accepted trial begin')
  call accumulate_wofost_trial_process_rate(accepted_physical_trial, 100.0_real64, 101.0_real64, &
       3.0_real64, 5.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_physical_trial%complete(), 'F-WOF37 accepted trial fill')
  call advance_and_commit_physical(physical_kernel, physical_model, physical_parameters, physical_forcing, &
       physical_config, physical_committed, physical_checkpoint, 100.0_real64, 101.0_real64)
  call certify_fkt_accepted_interval(physical_checkpoint, physical_committed, accepted_certificate, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_certificate%ready(), 'F-WOF37 accepted certificate')
  call admit_wofost_accepted_trial(accepted_window, accepted_certificate, accepted_physical_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. accepted_window%complete(), 'F-WOF37 accepted trial admission')
  call prepare_wofost_crop_event_delivery(accepted_window, aggregates, delivery_token, delivery_available, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. delivery_available .and. delivery_token%ready(), &
       'F-WOF37 frozen aggregate delivery prepare')
  call require(bitwise_equal(aggregates%actual_root_uptake, 3.0_real64), 'F-WOF37 exact accepted IQROT carrier')
  call require(bitwise_equal(aggregates%potential_transpiration, 5.0_real64), 'F-WOF37 exact accepted IPTRA carrier')
  call require(.not. accepted_window%delivery_committed(), 'F-WOF37 delivery remains uncommitted before crop candidate')
  print '(a)', 'FWOF37_REJECTED_PHYSICAL_TRIAL_ZERO_CROSS_SEAM_CONTRIBUTION=PASS'
  print '(a)', 'FWOF37_ACCEPTED_WINDOW_EXACT_FROZEN_AGGREGATE_CARRIER=PASS'
'''
if s.count(old_aggregates) != 1:
    raise SystemExit(f'F-WOF37 aggregate anchor count={s.count(old_aggregates)}')
s = s.replace(old_aggregates, new_aggregates, 1)

# After the first successful completion, the crop candidate exists but neither
# source crop state nor F-WOF34 delivery state may have been committed.
first_complete = "  call require(same_owner(seed, seed_before), 'complete cannot mutate committed seed')\n"
extra_after_complete = '''  call require(.not. accepted_window%delivery_committed(), &
       'prepared crop candidate cannot acknowledge delivery before atomic owner commit')
  call prepare_wofost_crop_event_delivery(accepted_window, replay_aggregates, replay_token, delivery_available, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. delivery_available .and. replay_token%ready(), &
       'delivery prepare remains replayable after crop candidate construction')
  call require(bitwise_equal(aggregates%actual_root_uptake, replay_aggregates%actual_root_uptake) .and. &
       bitwise_equal(aggregates%potential_transpiration, replay_aggregates%potential_transpiration), &
       'frozen carrier remains bitwise stable after crop candidate construction')
  print '(a)', 'FWOF37_CROP_CANDIDATE_READY_WITH_OWNER_AND_DELIVERY_UNCOMMITTED=PASS'
  print '(a)', 'FWOF37_FROZEN_DELIVERY_PREPARE_REPLAY_AFTER_CANDIDATE=PASS'
'''
if s.count(first_complete) != 1:
    raise SystemExit(f'F-WOF37 first completion anchor count={s.count(first_complete)}')
s = s.replace(first_complete, first_complete + extra_after_complete, 1)

# Existing F-WOF33 deliberately exercises failed Phase-B and structural
# completion. Assert additionally that neither failure consumes delivery.
failure_anchor = "  print '(a)', 'FWOF33_WINDOW_CONTEXT_REUSABLE_AFTER_DISCARDED_COMPLETE=PASS'\n"
extra_failure = '''  call require(.not. accepted_window%delivery_committed(), &
       'failed/discarded completion cannot consume delivery token')
  print '(a)', 'FWOF37_FAILED_OR_DISCARDED_CROP_COMPLETION_LEAVES_DELIVERY_UNCOMMITTED=PASS'
'''
if s.count(failure_anchor) != 1:
    raise SystemExit(f'F-WOF37 failure anchor count={s.count(failure_anchor)}')
s = s.replace(failure_anchor, failure_anchor + extra_failure, 1)

final_anchor = "  print '(a)', 'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'\n\ncontains\n"
final_extra = '''  call require(same_owner(seed, seed_before), 'F-WOF37 committed crop owner remains unchanged at transaction frontier')
  call require(.not. accepted_window%delivery_committed(), 'F-WOF37 delivery remains uncommitted at transaction frontier')
  print '(a)', 'FWOF37_ATOMIC_CROP_COMMIT_HELD=PASS'
  print '(a)', 'FWOF37_PREPARED_CROP_CANDIDATE_GATE PASS'

contains
'''
if s.count(final_anchor) != 1:
    raise SystemExit(f'F-WOF37 final anchor count={s.count(final_anchor)}')
s = s.replace(final_anchor, "  print '(a)', 'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'\n" + final_extra, 1)

helper_anchor = '  subroutine seed_active_owner(state)\n'
helpers = '''  subroutine setup_physical_committed(state, lineage_id, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fwof34_state_t :: physical)
    select type (physical)
    type is (fwof34_state_t)
      physical%water = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'F-WOF37 initialize physical committed state')
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
    logical :: did_commit
    integer :: commit_status

    if (.not. same_type_as(m, m)) error stop 'F-WOF37 unreachable model type'
    call k%advance_interval(p, state, f, c, t0, t1, result, candidate, diagnostics, checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-WOF37 F-KT trial completes')
    call require(candidate%ready(), 'F-WOF37 F-KT candidate materialized')
    call k%commit_candidate(state, candidate, diagnostics, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'F-WOF37 F-KT candidate commits')
  end subroutine advance_and_commit_physical

'''
if s.count(helper_anchor) != 1:
    raise SystemExit(f'F-WOF37 helper anchor count={s.count(helper_anchor)}')
s = s.replace(helper_anchor, helpers + helper_anchor, 1)

Path(sys.argv[3]).write_text(f34_module + s, encoding='utf-8')
print('FWOF37_CROSS_SEAM_TEST_MATERIALIZED=PASS')
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
)

for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  pushd "$OUT" >/dev/null
  for src in "${SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$src"
  done
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$BUILD/fwof37_cross_seam.f90" ./*.o -o test
  ./test > output.txt 2>&1
  popd >/dev/null
  for marker in \
    'FWOF37_REJECTED_PHYSICAL_TRIAL_ZERO_CROSS_SEAM_CONTRIBUTION=PASS' \
    'FWOF37_ACCEPTED_WINDOW_EXACT_FROZEN_AGGREGATE_CARRIER=PASS' \
    'FWOF37_CROP_CANDIDATE_READY_WITH_OWNER_AND_DELIVERY_UNCOMMITTED=PASS' \
    'FWOF37_FROZEN_DELIVERY_PREPARE_REPLAY_AFTER_CANDIDATE=PASS' \
    'FWOF37_FAILED_OR_DISCARDED_CROP_COMPLETION_LEAVES_DELIVERY_UNCOMMITTED=PASS' \
    'FWOF37_ATOMIC_CROP_COMMIT_HELD=PASS' \
    'FWOF37_PREPARED_CROP_CANDIDATE_GATE PASS' \
    'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  done
  echo "FWOF37_PREPARED_CANDIDATE_O${OPT}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF37_PREPARED_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FWOF37_PREPARED_CROP_CANDIDATE_COMPOSITION_GATE PASS'
