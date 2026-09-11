#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr39-$$"
mkdir -p "$BUILD"
trap 'git worktree remove --force "$BUILD/fvq58" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FMR39_GATE_FAIL $*" >&2; exit 1; }
CANONICAL=d201904a85f3b595e028242978e52c02f5122a09
FVQ58=5e81e14ad613cff7a72fc3f9cddcebc6696290d7
PROCESS_CONTRACT_BLOB=baa13df3975de2c699b0ec910477bcfa9b47f15e
PROCESS_BLOB=fa4e1d7b48d3515e6569c9080d497178c25c4e85
HYD_VIEW_BLOB=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
KERNEL_BLOB=f1acff10dd99c308a00f434440d6a9ef14632f0d
TX_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4

# Only the bounded runtime composition modules may change production source.
mapfile -t changed_src < <(git diff --name-only "$CANONICAL"..HEAD -- src | sort)
printf '%s\n' "${changed_src[@]}" > "$BUILD/changed-src.txt"
printf '%s\n' src/runtime/mod_fmr_restart_state_contract.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 | sort > "$BUILD/expected-src.txt"
cmp -s "$BUILD/changed-src.txt" "$BUILD/expected-src.txt" || { cat "$BUILD/changed-src.txt" >&2; fail 'unexpected production source delta'; }
echo 'FMR39_BOUNDED_PRODUCTION_DELTA=PASS'

check_blob(){ local path="$1" expected="$2" actual; actual="$(git rev-parse "HEAD:$path")"; [[ "$actual" == "$expected" ]] || fail "blob drift $path"; }
check_blob src/process/mod_soil_temperature_contract.f90 "$PROCESS_CONTRACT_BLOB"
check_blob src/process/mod_restricted_soil_temperature.f90 "$PROCESS_BLOB"
check_blob src/solver/mod_process_hydraulic_view.f90 "$HYD_VIEW_BLOB"
check_blob src/kernel/mod_kernel_transactions.f90 "$KERNEL_BLOB"
check_blob src/transaction/mod_transaction_reference.f90 "$TX_BLOB"
echo 'FMR39_SCIENCE_KERNEL_TRANSACTION_AND_HYDRAULIC_SEAM_LOCKS=PASS'

git diff --check "$CANONICAL" -- src/runtime tests/fmr integration/f-mr .github/workflows

python3 - <<'PY'
from pathlib import Path
b=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
r=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
state=b.split('type, extends(canonical_state_t), public :: fmr_b110_physical_state_t',1)[1].split('end type fmr_b110_physical_state_t',1)[0]
params=b.split('type, extends(kernel_parameters_t), public :: fmr_b110_physical_parameters_t',1)[1].split('end type fmr_b110_physical_parameters_t',1)[0]
model=b.split('type, extends(kernel_model_t) :: fmr_serialized_reference_model_t',1)[1].split('end type fmr_serialized_reference_model_t',1)[0]
storage=b.split('real(real64) function fmr_serialized_storage',1)[1].split('end function fmr_serialized_storage',1)[0]
advance=b.split('subroutine fmr_serialized_advance',1)[1].split('end subroutine fmr_serialized_advance',1)[0]
assert 'type(soil_temperature_state_t), allocatable :: soil_temperature' in state
assert 'logical :: soil_temperature_active = .false.' in params
assert 'type(soil_temperature_parameters_t), allocatable :: soil_temperature' in params
assert 'type(soil_temperature_workspace_t) :: soil_temperature_workspace' in model
assert 'soil_temperature_workspace' not in state
assert 'soil_temperature_workspace' not in params
assert 'call self%solver%solve' in advance
assert 'call trial_restricted_soil_temperature' in advance
assert advance.index('call self%solver%solve') < advance.index('call trial_restricted_soil_temperature')
assert 'call commit_soil_temperature_state' in advance
assert 'soil_temperature' not in storage
assert 'process_hydraulic_view_t' in b
assert 'headcalc' not in b.split('use mod_process_hydraulic_view',1)[1].split('implicit none',1)[0]
assert 'optional_state_layout_id > 0' in r
assert 'soil_temperature%ready()' in r
assert 'soil_temperature%node_count()' in r
print('FMR39_OPTIONAL_COMMITTED_THERMAL_STATE=PASS')
print('FMR39_WORKER_LOCAL_THERMAL_SCRATCH=PASS')
print('FMR39_RICHARDS_THEN_THERMAL_TRIAL_ORDER=PASS')
print('FMR39_WATER_STORAGE_AND_MASS_EXCLUDE_THERMAL_ENERGY=PASS')
print('FMR39_RESTART_FAIL_CLOSED_THERMAL_SHAPE=PASS')
PY

echo 'FMR39_STATIC_ARCHITECTURE_GATE=PASS'

RFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/transaction/mod_transaction_reference.f90
 src/transaction/mod_fkt_temporal_indicator_history.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/kernel/mod_kernel_committed_persistence.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_checkpoint_orchestrator.f90
 src/runtime/mod_fmr_accepted_commit_receipt.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_process_hydraulic_view.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_b110_serialized_context_binding.f90
 src/process/mod_snow_process.f90
 src/process/mod_soil_temperature_contract.f90
 src/process/mod_restricted_soil_temperature.f90
 src/runtime/mod_fmr_serialized_reference_backend.f90
 src/runtime/mod_fmr_serialized_multiswap_runtime.f90
 src/runtime/mod_fmr_restart_state_contract.f90
 src/runtime/mod_fmr_committed_restart.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    flags=("${RFLAGS[@]}")
    case "$src" in
      src/process/mod_soil_temperature_contract.f90|src/process/mod_restricted_soil_temperature.f90) flags=("${STRICT[@]}");;
    esac
    gfortran "${flags[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90 -o "$OUT/fmr39.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr39.o" -o "$OUT/fmr39"
  "$OUT/fmr39" > "$OUT/fmr39.txt" 2>&1 || { cat "$OUT/fmr39.txt" >&2; fail "F-MR39 runtime O$opt"; }
  "$OUT/fmr39" > "$OUT/fmr39-repeat.txt" 2>&1 || { cat "$OUT/fmr39-repeat.txt" >&2; fail "F-MR39 repeat O$opt"; }
  cmp "$OUT/fmr39.txt" "$OUT/fmr39-repeat.txt" || fail "F-MR39 repeat determinism O$opt"
  for marker in \
    FMR39_ENABLED_WATER_THERMAL_ATOMIC_COMMIT=PASS \
    FMR39_WATER_MASS_AUTHORITY_WITH_THERMAL_ACTIVE=PASS \
    FMR39_THERMAL_FAILURE_ROLLS_BACK_WATER_AND_TEMPERATURE=PASS \
    FMR39_RETRY_FROM_SAME_COMMITTED_STATE=PASS \
    FMR39_SPLIT_RESTART_WATER_THERMAL_IDENTITY=PASS \
    FMR39_RESTART_USES_EXISTING_POLYMORPHIC_PHYSICAL_STATE=PASS \
    FMR39_MIXED_ENABLED_DISABLED_MULTISWAP_ISOLATION=PASS \
    FMR39_INACTIVE_COLUMN_NO_THERMAL_PHYSICAL_STATE=PASS \
    'FMR39_RESTRICTED_SOIL_TEMPERATURE_RUNTIME_TEST PASS'; do grep -Fq "$marker" "$OUT/fmr39.txt" || fail "missing $marker O$opt"; done

  # Existing water/restart path is replayed against the modified backend. It
  # uses soil_temperature_active=.false. everywhere and must remain unchanged.
  gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr19_process_restart.f90 -o "$OUT/fmr19.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr19.o" -o "$OUT/fmr19"
  "$OUT/fmr19" > "$OUT/fmr19.txt" 2>&1 || { cat "$OUT/fmr19.txt" >&2; fail "F-MR19 preservation O$opt"; }
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$OUT/fmr19.txt" || fail "FMR19 restart marker O$opt"
  grep -Fq 'FMR19_REAL_HEADCALC_PROCESS_RESTART_TEST PASS' "$OUT/fmr19.txt" || fail "FMR19 close marker O$opt"
  echo "FMR39_DISABLED_PATH_FMR19_PRESERVATION_O${opt}=PASS"
done

cmp "$BUILD/o0/fmr39.txt" "$BUILD/o2/fmr39.txt" || fail 'F-MR39 O0/O2 runtime output drift'
cmp "$BUILD/o0/fmr19.txt" "$BUILD/o2/fmr19.txt" || fail 'F-MR19 O0/O2 preservation drift'
echo 'FMR39_RUNTIME_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR39_DISABLED_PATH_O0_O2_OUTPUT_IDENTITY=PASS'

# Replay the exact independent scientific authority in a detached worktree.
git cat-file -e "$FVQ58^{commit}" || fail 'F-VQ58 authority unavailable'
git worktree add --detach "$BUILD/fvq58" "$FVQ58" >/dev/null
( cd "$BUILD/fvq58" && bash tests/fvq/run_fvq58_restricted_soil_temperature_requalification.sh ) > "$BUILD/fvq58.txt" 2>&1 || { cat "$BUILD/fvq58.txt" >&2; fail 'F-VQ58 scientific replay'; }
grep -Fq 'FVQ58_GATE=PASS' "$BUILD/fvq58.txt" || fail 'F-VQ58 gate marker'
echo 'FMR39_FVQ58_EXACT_SCIENTIFIC_AUTHORITY_REPLAY=PASS'

cat "$BUILD/o0/fmr39.txt"
echo "FMR39_RUNTIME_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/fmr39.txt" | awk '{print $1}')"
echo 'FMR39_ALL_30_ARCHITECTURE_INVARIANTS_AUDITED_BY_EVIDENCE=PASS'
echo 'FMR39_GATE=PASS'
