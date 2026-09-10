#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr34-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR34_GATE_FAIL $*" >&2; exit 34; }
BASE=c0fc660c1e68064f77f4ec4f3376d385fbe88b4a
OLD_MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868

mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "src/runtime/mod_fmr_parallel_worker_pool.f90" ]] || \
  fail "unexpected production delta: ${src_delta[*]:-none}"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_parallel_worker_pool.f90)" == "20de332f6c13d91b02b26946bee25ddd77acd764" ]] || fail 'worker-pool candidate blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "fe5a06c9af59308cdad86c5126379f413591b0cd" ]] || fail 'serialized runtime drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "9af5a494526810324dc00706b444e448e770cba9" ]] || fail 'serialized backend drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_reference_et_root_uptake_composition.f90)" == "8ed7610144700f58d0b89482925471fcb2ff7d69" ]] || fail 'root-uptake composition drift'
echo 'FMR34_SOURCE_LOCK=PASS'
echo 'FMR34_PRODUCTION_DELTA_WORKER_POOL_ONLY=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text()
assert '%root_extraction_active .or.' not in p
assert 'if (parameter_registry(parameter_index)%root_extraction_active) then' in p
assert 'root_extraction_sink < 0.0_real64' in p
assert 'any(abs(forcing_registry(forcing_index)%root_extraction_sink) > 0.0_real64)' in p
assert 'parameter_registry(parameter_index)%snow_active .or.' in p
assert 'parameter_registry(parameter_index)%macropore_active .or.' in p
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in p
assert 'backends(w), transaction_controls(w)' in p
print('FMR34_ROOT_ADMISSION_MIRRORS_SERIALIZED_SIGN_CONTRACT=PASS')
print('FMR34_WORKER_OWNED_BACKEND_AND_TRANSACTION_CONTROL=PASS')
print('FMR34_OTHER_UNSUPPORTED_PHYSICS_STILL_FAIL_CLOSED_STATIC=PASS')
PY

# Preserve the prior real-physics parallel V1 matrix. The old immutable test
# encoded root extraction itself as unsupported; F-MR34 deliberately widens
# exactly that family, so only historical unsupported mode 1 is omitted from
# the temporary regression copy. Modes 2..5 and all positive/isolation/overlap
# controls remain byte-derived from the qualified old harness.
git cat-file blob "$OLD_MATRIX_BLOB" > "$BUILD/prior_parallel_v1.f90"
[[ "$(git hash-object "$BUILD/prior_parallel_v1.f90")" == "$OLD_MATRIX_BLOB" ]] || fail 'prior matrix blob mismatch'
python3 - "$BUILD/prior_parallel_v1.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='    do mode = 1, 5\n'
new='    do mode = 2, 5\n'
assert s.count(old)==1
p.write_text(s.replace(old,new))
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr34_parallel_root_extraction.f90 -o "$OUT/fmr34.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fmr34.o" -o "$OUT/fmr34"
  "$OUT/fmr34" > "$OUT/fmr34.txt" 2>&1 || { cat "$OUT/fmr34.txt" >&2; fail "owner root sentinel O$opt"; }
  for marker in \
    FMR34_ROOT_QROT_FAIL_CLOSED_MATRIX=PASS \
    FMR34_PROBLEM_COLUMN_ISOLATION=PASS \
    FMR34_TRUE_MULTIWORKER_ROOT_OVERLAP=PASS \
    FMR34_HARD_MASS_CONSERVATION=PASS \
    FMR34_SERIAL_2_4_ROOT_SCIENTIFIC_IDENTITY=PASS \
    FMR34_CANONICAL_PUBLICATION=PASS \
    'FMR34_OWNER_REAL_PHYSICS_ROOT_SENTINEL PASS'; do
    grep -Fq "$marker" "$OUT/fmr34.txt" || fail "missing owner marker O$opt: $marker"
  done
  for n in 2 7 17 32; do
    grep -Fq "FMR34_ALL_ACTIVE_N${n}=PASS" "$OUT/fmr34.txt" || fail "all-active n=$n O$opt"
    grep -Fq "FMR34_MIXED_ACTIVE_N${n}=PASS" "$OUT/fmr34.txt" || fail "mixed-active n=$n O$opt"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/prior_parallel_v1.f90" -o "$OUT/prior.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/prior.o" -o "$OUT/prior"
  "$OUT/prior" > "$OUT/prior.txt" 2>&1 || { cat "$OUT/prior.txt" >&2; fail "prior V1 regression O$opt"; }
  grep -Fq 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS' "$OUT/prior.txt" || fail "prior V1 positive matrix marker O$opt"
  grep -Fq 'FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS' "$OUT/prior.txt" || fail "prior non-root unsupported matrix O$opt"
  grep -Fq 'FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS' "$OUT/prior.txt" || fail "prior overlap O$opt"
  grep -Fq 'FMQ26_HARD_MASS_ALL_CASES=PASS' "$OUT/prior.txt" || fail "prior mass O$opt"
  echo "FMR34_O${opt}=PASS"
done

cmp -s "$BUILD/o0/fmr34.txt" "$BUILD/o2/fmr34.txt" || { diff -u "$BUILD/o0/fmr34.txt" "$BUILD/o2/fmr34.txt" >&2 || true; fail 'FMR34 O0/O2 root output identity'; }
cmp -s "$BUILD/o0/prior.txt" "$BUILD/o2/prior.txt" || { diff -u "$BUILD/o0/prior.txt" "$BUILD/o2/prior.txt" >&2 || true; fail 'prior V1 O0/O2 output identity'; }
echo 'FMR34_O0_O2_EXACT_OUTPUT_IDENTITY=PASS'
echo 'FMR34_PRIOR_PARALLEL_V1_NONROOT_SCOPE_PRESERVED=PASS'
cat "$BUILD/o0/fmr34.txt"
echo 'FMR34_OWNER_GATE=PASS'
