#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr22-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR22_GATE_FAIL $*" >&2; exit 1; }
CANDIDATE=4b6807c1d78c0c7d8bfe0f7a03a4c6c07d4444b9

mapfile -t changed_src < <(git diff --name-only "$CANDIDATE"..HEAD -- src)
[[ ${#changed_src[@]} -eq 1 && "${changed_src[0]}" == "src/runtime/mod_fmr_parallel_worker_pool.f90" ]] || \
  fail "unexpected production scope: ${changed_src[*]:-none}"

echo 'FMR22_SOURCE_SCOPE_PUBLICATION_ONLY=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
assert 'fmr_build_execution_order' in p
assert 'subroutine canonicalize_publication' in p
assert p.count('call canonicalize_publication(columns, results, diagnostics)') >= 5
normal=p.index('call build_parallel_aggregate')
finalize=p.index('call finalize_parallel_runtime', normal)
canon=p.index('call canonicalize_publication(columns, results, diagnostics)', finalize)
assert normal < finalize < canon
assert 'call fmr_execute_serialized_physical_column' in p[:canon]
print('FMR22_REDUCTION_PRECEDES_PUBLICATION_REORDER=PASS')
print('FMR22_INTERNAL_EXECUTION_INDEXING_PRESERVED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
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
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr20_parallel_v1_qualification.f90 -o "$OUT/fmr20.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fmr20.o" -o "$OUT/fmr20"
  "$OUT/fmr20" > "$OUT/fmr20.txt" 2>&1 || { cat "$OUT/fmr20.txt" >&2; fail "FMR20 matrix O$opt"; }
  for marker in \
    FMR20_V1_SERIAL_REFERENCE=PASS \
    FMR20_V1_REAL_OVERLAP_2_WORKERS=PASS \
    FMR20_V1_REAL_OVERLAP_4_WORKERS=PASS \
    FMR20_V1_SERIAL_VS_2_WORKER_IDENTITY=PASS \
    FMR20_V1_SERIAL_VS_4_WORKER_IDENTITY=PASS \
    FMR20_V1_WORKER_COUNT_INDEPENDENCE=PASS \
    FMR20_V1_A_B_A_REPEATABILITY=PASS \
    FMR20_V1_INPUT_ORDER_INDEPENDENCE=PASS \
    FMR20_V1_CROSS_COLUMN_REJECTION_ISOLATION=PASS \
    FMR20_V1_NEGATIVE_PROFILE_FAIL_CLOSED=PASS \
    FMR20_V1_SHARED_PARAMETER_INTEGRITY=PASS \
    'FMR20_PARALLEL_V1_QUALIFICATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/fmr20.txt" || fail "missing FMR20 O$opt marker: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr22_canonical_publication_order.f90 -o "$OUT/fmr22.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fmr22.o" -o "$OUT/fmr22"
  "$OUT/fmr22" > "$OUT/fmr22.txt" 2>&1 || { cat "$OUT/fmr22.txt" >&2; fail "canonical publication O$opt"; }
  grep -Fq 'FMR22_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/fmr22.txt" || fail "canonical publication marker O$opt"
  echo "FMR22_O${opt}=PASS"
done

cmp -s "$BUILD/o0/fmr20.txt" "$BUILD/o2/fmr20.txt" || fail 'FMR20 matrix O0/O2 identity'
cmp -s "$BUILD/o0/fmr22.txt" "$BUILD/o2/fmr22.txt" || fail 'FMR22 sentinel O0/O2 identity'

echo 'FMR22_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/fmr22.txt"
echo 'FMR22_GATE=PASS'
