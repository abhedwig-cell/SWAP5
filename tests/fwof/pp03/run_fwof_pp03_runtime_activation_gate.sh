#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp03-runtime-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Inherited immutable numerical evidence is executable, not merely cited.
bash tests/fwof/pp02/run_wofost81_one_day_candidate_integration.sh
bash tests/fwof/pp02/run_wofost81_case001_fullseason_gate.sh

# Reuse only the tiny already-qualified F-WOF34 synthetic kernel model as a
# physical accepted-window source. No crop physics is taken from this fixture.
# F-WOF34 predates the current fail-closed F-KT18 mass-completeness contract.
# Materialize a qualification-only copy and add ONLY the now-required explicit
# mass-completeness metadata/storage-status for its already-qualified exact
# storage law. The immutable historical F-WOF34 source and production code are
# not modified.
FWO34=85c0f7838d56c63d49f16af8242bdf4cbe4219d9
git show "$FWO34:tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90" > "$BUILD/fwof34.f90"
python3 - "$BUILD/fwof34.f90" "$BUILD/fwof34_module.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
marker = '\nprogram test_fwof34_accepted_window_runtime_lineage\n'
if marker not in src:
    raise SystemExit('F-WOF-PP03 cannot isolate immutable F-WOF34 test model')
mod = src.split(marker, 1)[0].rstrip() + '\n'
repls = [
    (
        'use, intrinsic :: iso_fortran_env, only: real64',
        'use, intrinsic :: iso_fortran_env, only: real64, int64',
    ),
    (
        'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t',
        'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &\n'
        '       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED',
    ),
    (
        '    procedure :: temporal_error => fwof34_temporal_error\n  end type fwof34_model_t',
        '    procedure :: temporal_error => fwof34_temporal_error\n'
        '    procedure :: storage_accounting_status => fwof34_storage_accounting_status\n'
        '  end type fwof34_model_t',
    ),
    (
        '    outcome%solver_ok = .true.\n    outcome%mass_in = transfer_mass',
        '    outcome%solver_ok = .true.\n'
        '    outcome%mass_accounting_complete = .true.\n'
        '    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE\n'
        '    outcome%mass_in = transfer_mass',
    ),
]
for old, new in repls:
    if mod.count(old) != 1:
        raise SystemExit(f'F-WOF-PP03 fixture adaptation anchor mismatch: {old!r}')
    mod = mod.replace(old, new, 1)
insert = '''
  subroutine fwof34_storage_accounting_status(self, state, complete, missing_mask)
    class(fwof34_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (self%scale < 0.0_real64) return
    select type (state)
    type is (fwof34_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      return
    end select
  end subroutine fwof34_storage_accounting_status
'''
end_marker = '\nend module mod_fwof34_test_model\n'
if mod.count(end_marker) != 1:
    raise SystemExit('F-WOF-PP03 fixture module end anchor mismatch')
mod = mod.replace(end_marker, insert + end_marker, 1)
Path(sys.argv[2]).write_text(mod, encoding='utf-8')
print('FWOF_PP03_FWO34_PHYSICAL_FIXTURE_MATERIALIZED=PASS')
print('FWOF_PP03_FWO34_CURRENT_MASS_CONTRACT_ADAPTED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

BASE_SOURCES=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/crop/mod_wofost_rate_table.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/crop/mod_wofost_one_day_rate_state_view.f90
  src/crop/mod_wofost_rate_parameters.f90
  src/crop/mod_wofost_prepare_assimilation.f90
  src/crop/mod_wofost_finalize_rates.f90
)
WOF81_SOURCES=(
  src/crop/mod_wofost81_assimilation.f90
  src/crop/mod_wofost81_nitrogen.f90
  src/crop/mod_wofost81_n_stress.f90
  src/crop/mod_wofost81_parameter_contract.f90
  src/crop/mod_wofost81_n_owner_state.f90
  src/crop/mod_wofost81_crop_owner_state.f90
  src/crop/mod_wofost81_daily_parameter_contract.f90
  src/crop/mod_wofost81_prepare_assimilation.f90
  src/crop/mod_wofost81_rate_correction.f90
  src/crop/mod_wofost81_leaf_structural_evolution.f90
  src/crop/mod_wofost81_one_day_candidate.f90
)
RUNTIME_SOURCES=(
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
  src/runtime/mod_fmr_wofost81_crop_transaction.f90
  src/runtime/mod_fmr_wofost81_crop_event_lifecycle.f90
)
TEST=tests/fwof/pp03/test_fwof_pp03_runtime_activation.f90

for opt in 0 2; do
  out="$BUILD/o$opt"
  objects=()

  for source in "${BASE_SOURCES[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  for source in "${WOF81_SOURCES[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  lineage_obj="$out/mod_fmr_wofost_accepted_window_lineage.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "${RUNTIME_SOURCES[0]}" -o "$lineage_obj"
  objects+=("$lineage_obj")

  for source in "${RUNTIME_SOURCES[@]:1}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  fixture_obj="$out/fwof34_module.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fwof34_module.f90" -o "$fixture_obj"
  objects+=("$fixture_obj")

  test_obj="$out/test_fwof_pp03_runtime_activation.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$test_obj"
  objects+=("$test_obj")

  exe="$BUILD/test_o$opt"
  gfortran "${COMMON[@]}" -O"$opt" "${objects[@]}" -o "$exe"
  set +e
  "$exe" > "$BUILD/out_o$opt.txt" 2>&1
  rc=$?
  set -e
  cat "$BUILD/out_o$opt.txt"
  if (( rc != 0 )); then
    echo "F_WOF_PP03_RUNTIME_ACTIVATION_O${opt}=FAIL RC=$rc" >&2
    exit "$rc"
  fi

  for marker in \
    'FWOF_PP03_ACCEPTED_EVENT_PROVENANCE=PASS' \
    'FWOF_PP03_RUNTIME_CANDIDATE_EQUALS_PP02_DIRECT=PASS' \
    'FWOF_PP03_PRECOMMIT_OWNER_RECEIPT_UNCHANGED=PASS' \
    'FWOF_PP03_LIFECYCLE_REQUIRES_COMMITTED_RECEIPT=PASS' \
    'FWOF_PP03_ROLLBACK_ZERO_OWNER_RECEIPT_LEAK=PASS' \
    'FWOF_PP03_OWNER_AND_RECEIPT_ONE_ATOMIC_REVISION=PASS' \
    'FWOF_PP03_LIFECYCLE_MATCHED_RETIREMENT=PASS' \
    'FWOF_PP03_LIFECYCLE_DUPLICATE_IDEMPOTENT=PASS' \
    'FWOF_PP03_DUPLICATE_EVENT_ZERO_EXTRA_ADVANCEMENT=PASS' \
    'FWOF_PP03_FAILED_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS' \
    'FWOF_PP03_FIXED_ONE_DAY_POLICY_ENFORCED=PASS' \
    'F_WOF_PP03_RUNTIME_ACTIVATION_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/out_o$opt.txt" || { cat "$BUILD/out_o$opt.txt" >&2; exit 1; }
  done
  echo "F_WOF_PP03_RUNTIME_ACTIVATION_O${opt}=PASS"
done

cmp "$BUILD/out_o0.txt" "$BUILD/out_o2.txt"
sha=$(sha256sum "$BUILD/out_o0.txt" | awk '{print $1}')
echo "F_WOF_PP03_RUNTIME_ACTIVATION_O0_O2_IDENTITY=PASS SHA256=$sha"

git diff --exit-code 5e4386f06a230c71eba103fd8e12fec97e7fae6d -- \
  src/runtime/mod_fmr_wofost_crop_transaction.f90 \
  src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90 \
  src/crop/mod_wofost_two_phase_crop_window.f90 \
  src/crop/mod_wofost_one_day_structural_evolution.f90

echo 'F_WOF_PP03_LEGACY_WOFOST_RUNTIME_UNCHANGED=PASS'
echo 'F_WOF_PP03_RUNTIME_ACTIVATION_GATE PASS'
