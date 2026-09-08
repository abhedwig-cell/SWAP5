#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr11-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR11_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  echo "FMR11_SOURCE_LOCK PASS $path $actual"
}

# Exact F-SI16 production seam.
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob src/legacy/b1_10_port/headcalc.f90 d92f77963329d61ab3feb988f912252c0161436c
check_blob src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6

# F-MR11 runtime seam and protected transaction/composition sources.
check_blob src/adapter/mod_b110_serialized_context_binding.f90 e21c964eac48d5feb91388cfd06a646c4002a497
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 6f39d60a87c1987ae95d7faec2f55f865af90a08
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/runtime/mod_fmr_checkpoint_orchestrator.f90 232875e7192f995930c102609cee08dc8938c86a
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11

echo 'FMR11_SOURCE_LOCKS PASS'

python3 - <<'PY'
from pathlib import Path
ctx = Path('src/adapter/mod_b110_serialized_context_binding.f90').read_text()
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
multiswap = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()

assert 'request%boundary%bottom_mode /= 5' in ctx
assert 'hbot = request%boundary%bottom_head' in ctx
assert 'qbot = request%boundary%bottom_flux' in ctx

assert 'parameters%bottom_mode == 5' in backend
assert 'self%bottom_head = forcing%bottom_head' in backend
assert 'request%boundary%bottom_head = self%bottom_head' in backend
assert 'self%last_observation%bottom_flux = solve_result%bottom_flux' in backend
assert 'max(0.0_real64, bottom_flux) * step_duration' in backend
assert 'max(0.0_real64, -bottom_flux) * step_duration' in backend
assert 'if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5)' in backend
assert 'all(full%pressure_head == half%pressure_head)' in backend
assert 'all(full%water_content == half%water_content)' in backend
assert 'value = 0.0_real64' in backend and 'value = huge(0.0_real64)' in backend
assert 'temporal_tolerance' not in backend

assert 'fmr_capture_checkpoint' in multiswap
assert 'fmr_commit_candidate' in multiswap
assert 'fmr_discard_candidate' in multiswap
print('FMR11_STATIC_RUNTIME_CONTRACT PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

TESTS=(
  tests/fmr/test_fmr11_prescribed_bottom_head_runtime.f90
  tests/fmr/test_fmr09_root_sink_runtime.f90
  tests/fmr/test_fmr10_root_uptake_process_binding.f90
  tests/fmr/test_fmr10_root_uptake_runtime_bridge.f90
  tests/fmr/test_fmr07_committed_process_hydraulic_view.f90
  tests/fmr/test_fmr06_snow_smoke.f90
  tests/fvq/test_fvq22_root_uptake_scientific_oracle.f90
  tests/fvq/test_fvq22_root_uptake_runtime_oracle.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  for test in "${TESTS[@]}"; do
    name="$(basename "${test%.*}")"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/$name.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
    "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
  done

  for marker in \
    'FMR11_BOTTOM_HEAD_AUTHORITY=PASS' \
    'FMR11_AUTHORITATIVE_QBOT_OBSERVED=PASS' \
    'FMR11_POSITIVE_NEGATIVE_QBOT=PASS' \
    'FMR11_TRIAL_DISCARD_NO_COMMIT=PASS' \
    'FMR11_A_B_A_REPLAY=PASS' \
    'FMR11_UNSUPPORTED_PHYSICAL_ROUTES_FAIL_CLOSED=PASS' \
    'FMR11_EXACT_TEMPORAL_ZERO_TOLERANCE_ACCEPTANCE=PASS' \
    'FMR11_QBOT_MASS_EXACTLY_ONCE=PASS' \
    'FMR11_BOTTOM_FLUX_SEED_INDEPENDENCE=PASS' \
    'FMR11_SERIALIZED_ONLY=PASS' \
    'FMR11_PRESCRIBED_BOTTOM_HEAD_RUNTIME_TEST PASS'; do
    grep -Fq "$marker" "$OUT/test_fmr11_prescribed_bottom_head_runtime.txt"
  done

  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR10_ROOT_UPTAKE_PROCESS_BINDING_TEST PASS' "$OUT/test_fmr10_root_uptake_process_binding.txt"
  grep -Fq 'FMR10_ROOT_UPTAKE_RUNTIME_BRIDGE_TEST PASS' "$OUT/test_fmr10_root_uptake_runtime_bridge.txt"
  grep -Fq 'FMR07_COMMITTED_PROCESS_HYDRAULIC_VIEW PASS' "$OUT/test_fmr07_committed_process_hydraulic_view.txt"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FVQ22_ROOT_UPTAKE_SCIENTIFIC_ORACLE PASS' "$OUT/test_fvq22_root_uptake_scientific_oracle.txt"
  grep -Fq 'FVQ22_ROOT_UPTAKE_RUNTIME_ORACLE PASS' "$OUT/test_fvq22_root_uptake_runtime_oracle.txt"

  cat \
    "$OUT/test_fmr11_prescribed_bottom_head_runtime.txt" \
    "$OUT/test_fmr09_root_sink_runtime.txt" \
    "$OUT/test_fmr10_root_uptake_process_binding.txt" \
    "$OUT/test_fmr10_root_uptake_runtime_bridge.txt" \
    "$OUT/test_fmr07_committed_process_hydraulic_view.txt" \
    "$OUT/test_fmr06_snow_smoke.txt" \
    "$OUT/test_fvq22_root_uptake_scientific_oracle.txt" \
    "$OUT/test_fvq22_root_uptake_runtime_oracle.txt" > "$OUT/output.txt"
  echo "FMR11_O${opt}=PASS"
done

cmp "$BUILD/o0/test_fmr11_prescribed_bottom_head_runtime.txt" "$BUILD/o2/test_fmr11_prescribed_bottom_head_runtime.txt"
cmp "$BUILD/o0/test_fmr09_root_sink_runtime.txt" "$BUILD/o2/test_fmr09_root_sink_runtime.txt"
cmp "$BUILD/o0/test_fmr10_root_uptake_process_binding.txt" "$BUILD/o2/test_fmr10_root_uptake_process_binding.txt"
cmp "$BUILD/o0/test_fmr10_root_uptake_runtime_bridge.txt" "$BUILD/o2/test_fmr10_root_uptake_runtime_bridge.txt"
cmp "$BUILD/o0/test_fmr07_committed_process_hydraulic_view.txt" "$BUILD/o2/test_fmr07_committed_process_hydraulic_view.txt"
cmp "$BUILD/o0/test_fmr06_snow_smoke.txt" "$BUILD/o2/test_fmr06_snow_smoke.txt"
cmp "$BUILD/o0/test_fvq22_root_uptake_scientific_oracle.txt" "$BUILD/o2/test_fvq22_root_uptake_scientific_oracle.txt"
cmp "$BUILD/o0/test_fvq22_root_uptake_runtime_oracle.txt" "$BUILD/o2/test_fvq22_root_uptake_runtime_oracle.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"

echo 'FMR11_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR11_FMR09_FUNCTIONAL_REGRESSION=PASS'
echo 'FMR11_FMR10_FUNCTIONAL_REGRESSION=PASS'
echo 'FMR11_FMR07_HYDRAULIC_VIEW_REGRESSION=PASS'
echo 'FMR11_FMR06_SNOW_REGRESSION=PASS'
echo 'FMR11_FVQ22_ROOT_UPTAKE_REGRESSION=PASS'
cat "$BUILD/o0/test_fmr11_prescribed_bottom_head_runtime.txt"
echo "FMR11_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FMR11_PRESCRIBED_BOTTOM_HEAD_RUNTIME_GATE PASS'
