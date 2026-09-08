#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe05-fvq19-$$"
EVIDENCE_DIR="${FPE05_EVIDENCE_DIR:-$ROOT/fpe05-evidence}"
mkdir -p "$BUILD" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPE05_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
  printf '%s  %s\n' "$actual" "$path" >> "$EVIDENCE_DIR/source-blobs.txt"
}

: > "$EVIDENCE_DIR/source-blobs.txt"
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7a60f8b8d18672098fed1c6890a95aac738ed21d
check_blob src/kernel/mod_kernel_transactions.f90 af42c7d51ef545e20c76d3000f1ed1493690d68e
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0
check_blob src/legacy/b1_10_port/headcalc.f90 be5978827095445b15de7baf607728792de6a366
check_blob tests/fmr/test_fmr06_snow_multiswap.f90 ed4b742b76e97ff0ad27b386850c1d093e4f03d1

python3 - <<'PY' | tee "$EVIDENCE_DIR/source-audit.txt"
from pathlib import Path
import subprocess

base = '7b35af8049c7b2185d0fbe87189c1791bfa5d532'
changed = subprocess.check_output(['git','diff','--name-only',base,'HEAD','--','src'], text=True).splitlines()
expected = ['src/kernel/mod_kernel_transactions.f90', 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90']
assert changed == expected, f'unexpected production source scope since F-VQ19 closeout: {changed}'

backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
tx = Path('src/transaction/mod_transaction_reference.f90').read_text().lower()
fixture = Path('tests/fmr/test_fmr06_snow_multiswap.f90').read_text().lower()
runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
kernel = Path('src/kernel/mod_kernel_transactions.f90').read_text().lower()

for token in ['prepare_snow_outer_event', 'snow_event_applied_this_call', 'snow_outer_t0', 'snow_melt_rate']:
    assert token in backend, f'missing SNOW outer-event token: {token}'
for token in ['checkpoint%clone(full_state)', 'checkpoint%clone(half_state)',
              'model%advance(half_state, t0, midpoint, half1_outcome)',
              'model%advance(half_state, midpoint, attempt_t1, half2_outcome)',
              'call move_alloc(half_state, committed)']:
    assert token in tx, f'missing reference full/two-half transaction token: {token}'
assert 'cfg%transaction%temporal_tolerance=0.0_real64' in fixture
assert 'real(real64), parameter :: t0 = 1600.375_real64' in fixture
assert 'real(real64), parameter :: t1 = 1601.375_real64' in fixture
for token in ['accepted_substeps', 'solver_nonlinear_iterations', 'solver_internal_retries',
              'solver_headcalc_calls', 'solver_jacobian_builds', 'solver_linear_solves',
              'solver_backtracking_attempts', 'solver_alternative_solver_calls']:
    assert token in runtime, f'missing runtime diagnostic: {token}'
for token in ['diagnostics%nonlinear_iterations = runtime_diagnostics%nonlinear_iterations',
              'diagnostics%headcalc_calls = runtime_diagnostics%headcalc_calls']:
    assert token in kernel, f'missing kernel diagnostic mapping: {token}'
print('FPE05_PRODUCTION_SCOPE=PASS_EXACT_TWO_OBSERVER_FILES')
print('FPE05_SNOW_OUTER_EVENT_TWO_HALF_COMPATIBILITY_SOURCE_AUDIT=PASS')
print('FPE05_ZERO_TEMPORAL_TOLERANCE_NONMIDNIGHT_DAILY_FIXTURE=PASS')
print('FPE05_COST_DIAGNOSTIC_CHAIN_SOURCE_AUDIT=PASS')
PY

python3 tests/fpe/fpe05_make_cost_probe.py "$BUILD/test_fpe05_cost_probe.f90" | tee "$EVIDENCE_DIR/probe-generation.txt"

git show 1d9ff946f45488557d10700f047089d3298a4794:tests/vq/fvq17/test_fvq17_snow_multiswap_reference.f90 > \
  "$BUILD/test_fvq17_snow_multiswap_reference.f90"
FVQ17_VERIFIER_BLOB="$(git hash-object "$BUILD/test_fvq17_snow_multiswap_reference.f90")"
[[ "$FVQ17_VERIFIER_BLOB" == "2465fcc504839d3677b28299ca0a5af5bfbe825e" ]] || {
  echo "FPE05_FVQ17_VERIFIER_BLOB_MISMATCH actual=$FVQ17_VERIFIER_BLOB" >&2
  exit 1
}
echo "FPE05_IMMUTABLE_FVQ17_VERIFIER_BLOB=$FVQ17_VERIFIER_BLOB" | tee "$EVIDENCE_DIR/fvq17-verifier-lock.txt"

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
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr06_snow_multiswap.f90 -o "$OUT/original.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/original.o" -o "$OUT/original"
  "$OUT/original" > "$OUT/original.txt" 2>&1 || { cat "$OUT/original.txt" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_MULTISWAP_TEST PASS' "$OUT/original.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fpe05_cost_probe.f90" -o "$OUT/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/probe.o" -o "$OUT/probe"
  "$OUT/probe" > "$OUT/probe-a.txt" 2>&1 || { cat "$OUT/probe-a.txt" >&2; exit 1; }
  "$OUT/probe" > "$OUT/probe-b.txt" 2>&1 || { cat "$OUT/probe-b.txt" >&2; exit 1; }
  grep -Fq 'FPE05_COST_DIAGNOSTICS_PROBE=PASS' "$OUT/probe-a.txt"
  test "$(grep -c '^FPE05_COST ' "$OUT/probe-a.txt")" -eq 51
  cmp "$OUT/probe-a.txt" "$OUT/probe-b.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/test_fvq17_snow_multiswap_reference.f90" -o "$OUT/fvq17-replay.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fvq17-replay.o" -o "$OUT/fvq17-replay"
  "$OUT/fvq17-replay" > "$OUT/fvq17-replay.txt" 2>&1 || { cat "$OUT/fvq17-replay.txt" >&2; exit 1; }
  grep -Fq 'FVQ17_SUBDAILY_RUNTIME_FAIL_CLOSED=PASS' "$OUT/fvq17-replay.txt"
  grep -Fq 'FVQ17_MULTIDAY_RUNTIME_FAIL_CLOSED=PASS' "$OUT/fvq17-replay.txt"
  grep -Fq 'FVQ17_INDEPENDENT_SNOW_MULTISWAP_REFERENCE PASS' "$OUT/fvq17-replay.txt"

  cp "$OUT/original.txt" "$EVIDENCE_DIR/original-o${opt}.txt"
  cp "$OUT/probe-a.txt" "$EVIDENCE_DIR/probe-o${opt}.txt"
  cp "$OUT/fvq17-replay.txt" "$EVIDENCE_DIR/fvq17-current-lineage-o${opt}.txt"
  sha256sum "$OUT/original.txt" "$OUT/probe-a.txt" "$OUT/fvq17-replay.txt" > "$EVIDENCE_DIR/output-o${opt}.sha256"
  echo "FPE05_O${opt}_ORIGINAL_FIXTURE=PASS"
  echo "FPE05_O${opt}_COST_PROBE_REPEAT_IDENTITY=PASS"
  echo "FPE05_O${opt}_CURRENT_LINEAGE_FVQ17_ROLLBACK_REPLAY=PASS"
done

cmp "$BUILD/o0/original.txt" "$BUILD/o2/original.txt"
cmp "$BUILD/o0/probe-a.txt" "$BUILD/o2/probe-a.txt"
cmp "$BUILD/o0/fvq17-replay.txt" "$BUILD/o2/fvq17-replay.txt"
grep '^FPE05_COST ' "$BUILD/o0/probe-a.txt" > "$EVIDENCE_DIR/cost-envelope.txt"
sha256sum "$EVIDENCE_DIR/cost-envelope.txt" > "$EVIDENCE_DIR/cost-envelope.sha256"

{
  echo 'FPE05_COMPOSED_SCIENTIFIC_FIXTURE_O0_O2_OUTPUT_IDENTITY=PASS'
  echo 'FPE05_COST_PROBE_O0_O2_OUTPUT_IDENTITY=PASS'
  echo 'FPE05_COST_PROBE_REPEAT_IDENTITY=PASS'
  echo 'FPE05_COST_RECORD_COUNT=51'
  echo 'FPE05_MASS_AND_COMMIT_ASSERTIONS_REUSED_FROM_IMMUTABLE_FMR06_FIXTURE=PASS'
  echo 'FPE05_CURRENT_LINEAGE_FAILURE_ROLLBACK_NO_LEAKAGE_REPLAY=PASS'
  echo 'FPE05_CURRENT_LINEAGE_FVQ17_REPLAY_O0_O2_IDENTITY=PASS'
  echo 'FPE05_NO_NEW_NUMERIC_TOLERANCE=PASS'
  echo 'FPE05_BALANCED_THROUGHPUT_FALLBACK_NOT_ADMITTED=PASS'
  echo 'FPE05_GATE PASS_REFERENCE_NONSTATIONARY_TEMPORAL_COST_CHARACTERIZATION'
} | tee "$EVIDENCE_DIR/summary.txt"

cat "$EVIDENCE_DIR/cost-envelope.txt"
cat "$EVIDENCE_DIR/summary.txt"
