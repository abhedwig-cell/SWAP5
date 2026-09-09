#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt10-real-history-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
DRIVER=tests/fkt/test_fkt10_real_richards_history_binding.f90

fail() { echo "FKT10_REAL_HISTORY_RUNNER_FAIL $*" >&2; exit 1; }

# Source-level governance guards: numerical continuation must stay separate
# from physical optional-state topology and B_inf must not silently become the
# F-KT09 model certificate.
python3 - <<'PY'
from pathlib import Path
core=Path('src/runtime/mod_fmr_runtime_core.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
snow_test=Path('tests/fmr/test_fmr06_snow_multiswap.f90').read_text().lower()
assert 'optional_state_layout_id = 60605' in snow_test
assert 'numerical_continuation_layout_id' in core
assert 'select case (template%numerical_continuation_layout_id)' in backend
assert 'select case (template%optional_state_layout_id)' not in backend
assert 'outcome%temporal_certificate_available = .true.' not in backend
assert 'outcome%temporal_indicator = indicator_result%head_inf_bound' not in backend
print('FKT10_GATE_D_PHYSICAL_NUMERICAL_LAYOUT_SEPARATION=PASS')
print('FKT10_GATE_E_CERTIFICATE_NONPROMOTION_SOURCE_GUARD=PASS')
PY

# Replace only the deliberately-zero F-SI04 TRIDAG fixture with the exact
# reference TRIDAG implementation already used by F-SI25 qualification.
git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FKT10_REAL_REFERENCE_TRIDAG_SOURCE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

build_and_run() {
  local opt="$1" tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/fkt10_real_history"
  timeout 180s "$out/fkt10_real_history" > "$out/output.txt" 2>&1 || {
    cat "$out/output.txt" >&2
    fail "real history driver failed opt=$tag"
  }
  grep -Fq 'FKT10_GATE_D_REAL_RICHARDS_HISTORY_BINDING=PASS' "$out/output.txt"
  grep -Fq 'FKT10_GATE_E_PHYSICS_MASS_AND_COST_NONINTERFERENCE=PASS' "$out/output.txt"
  grep -Fq 'FKT10_GATE_F_REAL_TRANSACTION_HISTORY_ROLLBACK_COMMIT=PASS' "$out/output.txt"
  grep -Fq 'FKT10_GATE_E_FKT09_CERTIFICATE_NONPROMOTION=PASS' "$out/output.txt"
  grep -Fq 'FKT10_REAL_RICHARDS_HISTORY_BINDING_TEST PASS' "$out/output.txt"
  echo "FKT10_REAL_HISTORY_${tag}=PASS"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output drift'
}
echo 'FKT10_GATE_H_REAL_RICHARDS_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

# Preserve the already-persisted synthetic transaction lifecycle evidence too.
bash tests/fkt/run_fkt10_temporal_history_transaction.sh > "$BUILD/synthetic.txt" 2>&1 || {
  cat "$BUILD/synthetic.txt" >&2
  fail 'synthetic lifecycle regression failed'
}
grep -Fq 'FKT10_TEMPORAL_HISTORY_RUNNER PASS' "$BUILD/synthetic.txt"
echo 'FKT10_GATE_B_C_F_SYNTHETIC_REGRESSION=PASS'

echo 'FKT10_REAL_RICHARDS_HISTORY_EXECUTION_GATE PASS'
