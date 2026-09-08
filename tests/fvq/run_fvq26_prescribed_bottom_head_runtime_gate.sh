#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq26-$$"
FSI_WORKTREE="${TMPDIR:-/tmp}/swap5-fvq26-fsi16-$$"
FMR11_CLOSEOUT="86924e93ee81f8c246c28e8277b8ade6079ebaa7"
FSI16_CLOSEOUT="6591b2f481e1760f844514e63ef873e8deda301f"
mkdir -p "$BUILD"
cleanup() {
  git -C "$ROOT" worktree remove --force "$FSI_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD" "$FSI_WORKTREE"
}
trap cleanup EXIT
cd "$ROOT"

fail() { echo "FVQ26_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  echo "FVQ26_SOURCE_LOCK PASS $path $actual"
}

# F-VQ26 is verification only.  Any production-source edit relative to the
# exact F-MR11 closeout is an immediate failure.
if ! git diff --quiet "$FMR11_CLOSEOUT" -- src; then
  echo 'FVQ26_PRODUCTION_IMMUTABILITY FAIL' >&2
  git diff --name-only "$FMR11_CLOSEOUT" -- src >&2
  exit 1
fi
echo 'FVQ26_PRODUCTION_IMMUTABILITY PASS'

# Exact F-MR11/F-SI16 production locks plus protected transaction/composition
# sources.  These are verified independently of the owner status artifact.
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob src/legacy/b1_10_port/headcalc.f90 d92f77963329d61ab3feb988f912252c0161436c
check_blob src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob src/adapter/mod_b110_serialized_context_binding.f90 e21c964eac48d5feb91388cfd06a646c4002a497
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 6f39d60a87c1987ae95d7faec2f55f865af90a08
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/runtime/mod_fmr_checkpoint_orchestrator.f90 232875e7192f995930c102609cee08dc8938c86a
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
echo 'FVQ26_SOURCE_LOCKS PASS'

python3 - <<'PY'
from pathlib import Path
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
context = Path('src/adapter/mod_b110_serialized_context_binding.f90').read_text()
multiswap = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()
assert 'parameters%bottom_mode == 5' in backend
assert 'request%boundary%bottom_head = self%bottom_head' in backend
assert 'self%last_observation%bottom_flux = solve_result%bottom_flux' in backend
assert 'max(0.0_real64, bottom_flux) * step_duration' in backend
assert 'max(0.0_real64, -bottom_flux) * step_duration' in backend
assert 'self%bottom_mode /= 5' in backend
assert 'temporal_tolerance' not in backend
assert 'request%boundary%bottom_mode /= 5' in context
assert 'hbot = request%boundary%bottom_head' in context
assert 'fmr_capture_checkpoint' in multiswap
assert 'fmr_commit_candidate' in multiswap
assert 'fmr_discard_candidate' in multiswap
print('FVQ26_STATIC_INDEPENDENT_AUDIT PASS')
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
  tests/fvq/test_fvq26_prescribed_bottom_head_runtime.f90
  tests/fmr/test_fmr09_root_sink_runtime.f90
  tests/fmr/test_fmr10_root_uptake_runtime_bridge.f90
  tests/fmr/test_fmr07_committed_process_hydraulic_view.f90
  tests/fmr/test_fmr06_snow_smoke.f90
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
    timeout 60s "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
  done

  for marker in \
    'FVQ26_INDEPENDENT_DARCY_QBOT=PASS' \
    'FVQ26_BOTTOM_HEAD_AUTHORITY=PASS' \
    'FVQ26_BOTTOM_FLUX_SEED_IRRELEVANCE=PASS' \
    'FVQ26_POSITIVE_NEGATIVE_QBOT=PASS' \
    'FVQ26_QBOT_MASS_EXACTLY_ONCE=PASS' \
    'FVQ26_TRANSACTION_DISCARD_ISOLATION=PASS' \
    'FVQ26_A_B_A_REPLAY=PASS' \
    'FVQ26_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS' \
    'FVQ26_FAIL_CLOSED_PROFILE=PASS' \
    'FVQ26_SERIALIZED_ONLY=PASS' \
    'FVQ26_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/test_fvq26_prescribed_bottom_head_runtime.txt" || fail "missing $marker at O$opt"
  done
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/test_fmr09_root_sink_runtime.txt"
  grep -Fq 'FMR10_ROOT_UPTAKE_RUNTIME_BRIDGE_TEST PASS' "$OUT/test_fmr10_root_uptake_runtime_bridge.txt"
  grep -Fq 'FMR07_COMMITTED_PROCESS_HYDRAULIC_VIEW PASS' "$OUT/test_fmr07_committed_process_hydraulic_view.txt"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/test_fmr06_snow_smoke.txt"
  grep -Fq 'FVQ22_ROOT_UPTAKE_RUNTIME_ORACLE PASS' "$OUT/test_fvq22_root_uptake_runtime_oracle.txt"
  cat "${TESTS[@]/#/}" >/dev/null 2>&1 || true
  cat "$OUT/test_fvq26_prescribed_bottom_head_runtime.txt" \
      "$OUT/test_fmr09_root_sink_runtime.txt" \
      "$OUT/test_fmr10_root_uptake_runtime_bridge.txt" \
      "$OUT/test_fmr07_committed_process_hydraulic_view.txt" \
      "$OUT/test_fmr06_snow_smoke.txt" \
      "$OUT/test_fvq22_root_uptake_runtime_oracle.txt" > "$OUT/output.txt"
  echo "FVQ26_O${opt}=PASS"
done

cmp "$BUILD/o0/test_fvq26_prescribed_bottom_head_runtime.txt" "$BUILD/o2/test_fvq26_prescribed_bottom_head_runtime.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ26_O0_O2_OUTPUT_IDENTITY PASS'
echo 'FVQ26_FMR09_REGRESSION PASS'
echo 'FVQ26_FMR10_REGRESSION PASS'
echo 'FVQ26_FMR07_REGRESSION PASS'
echo 'FVQ26_FMR06_REGRESSION PASS'
echo 'FVQ26_FVQ22_REGRESSION PASS'
cat "$BUILD/o0/test_fvq26_prescribed_bottom_head_runtime.txt"
echo "FVQ26_RUNTIME_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"

# Replay the separately qualified F-SI16 exact B1.10 oracle on its own source
# lineage.  This is deliberately not run against the F-VQ26 worktree.
git worktree add --detach "$FSI_WORKTREE" "$FSI16_CLOSEOUT" >/dev/null
(
  cd "$FSI_WORKTREE"
  bash tests/fsi/run_fsi16_b110_direct_oracle_gate.sh
) > "$BUILD/fsi16-oracle.txt" 2>&1 || { cat "$BUILD/fsi16-oracle.txt" >&2; exit 1; }
grep -Fq 'F-SI16_B110_EXACT_COMMON_IDENTITY_O0 PASS' "$BUILD/fsi16-oracle.txt"
grep -Fq 'F-SI16_B110_EXACT_COMMON_IDENTITY_O2 PASS' "$BUILD/fsi16-oracle.txt"
grep -Fq 'F-SI16_B110_INDEPENDENT_QBOT_AUTHORITY PASS' "$BUILD/fsi16-oracle.txt"
grep -Fq 'F-SI16_B110_INDEPENDENT_ORACLE_GATE PASS' "$BUILD/fsi16-oracle.txt"
echo 'FVQ26_FSI16_CANONICAL_B110_REPLAY PASS'
echo "FVQ26_FSI16_ORACLE_SHA256=$(sha256sum "$BUILD/fsi16-oracle.txt" | cut -d' ' -f1)"

echo 'FVQ26_INDEPENDENT_PRESCRIBED_BOTTOM_HEAD_RUNTIME_GATE PASS'
