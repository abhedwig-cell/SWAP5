#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe10-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=485003c1be6e55521297b7b6bdc0195a15ca0f4f
fail() { echo "FPE10_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:605593edf96a510a291695356f47390caf17d01c \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:e2993e171c9203f4c66e35cab2889130591d3b05 \
  src/runtime/mod_a23bu_worker_execution_context.f90:0ecb09bfa318a284e7841749d474d2f871363c81 \
  src/solver/mod_reference_richards_workspace.f90:59ef9d037c1875610d45ac83387ebab9e917e0fe \
  src/solver/mod_b110_default_mvg_provider.f90:ffd4701740dceb2df12f05e9cad73e81eeb55b43 \
  src/adapter/mod_reference_richards_legacy_binding.f90:1e3a227883cb2a0f79e40a22f016e7953d5fbab1 \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:d1881ac6dd18363c731c4f57a078433883b2bb63 \
  tests/fmr/test_fmr20_parallel_v1_qualification.f90:bfebfde94b3931367d69d502a6fc7b1deb8f2ad6 \
  tests/fpe/test_fpe08_scratch_dedup.f90:3b9ae676b5e38a782336af80cfd6515f30bac848 \
  tests/fpe/test_fpe09_cache_reuse.f90:ce067bb5dc68874e18a9afd89f31eb092a09f74b \
  tests/fpe/test_fpe10_target_lifetime_probe.f90:2e261ca09a2d595ae3a76ac23e98ff49b213537a; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FPE10_G01_SOURCE_LOCK=PASS'

if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  git fetch --quiet --no-tags --depth=1 origin "$BASE"
fi
git diff --name-only "$BASE" HEAD -- src | sort > "$BUILD/src.changed"
printf '%s\n' \
  src/runtime/mod_fmr_parallel_worker_pool.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 | sort > "$BUILD/src.expected"
diff -u "$BUILD/src.expected" "$BUILD/src.changed" >/dev/null || {
  diff -u "$BUILD/src.expected" "$BUILD/src.changed" >&2 || true
  fail 'production source scope differs from exact three-file forcing-view prototype'
}
echo 'FPE10_G02_BOUNDED_PRODUCTION_SCOPE=PASS'

python3 - <<'PY'
from pathlib import Path
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
serial = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()
pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text()

assert 'logical :: direct_forcing_views_enabled = .false.' in backend
assert 'logical, intent(in), optional :: enable_direct_forcing_views' in backend
assert 'requested_direct_views = .false.' in backend
assert 'if (present(enable_direct_forcing_views)) requested_direct_views = enable_direct_forcing_views' in backend
assert 'type(fmr_b110_physical_forcing_t), target, intent(in) :: forcing' in backend
assert 'self%model%qdra => forcing%drainage_flux_by_level' in backend
assert 'self%model%qssdi => forcing%subsurface_irrigation_source' in backend
assert 'self%model%qrot => forcing%root_extraction_sink' in backend
assert 'if (self%direct_forcing_views_enabled) then' in backend
assert 'self%qdra = forcing%drainage_flux_by_level' in backend
assert 'self%qssdi = forcing%subsurface_irrigation_source' in backend
assert 'self%qrot = forcing%root_extraction_sink' in backend

call_pos = backend.index('    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &')
pre = backend.rfind('      self%model%qdra => forcing%drainage_flux_by_level', 0, call_pos)
post = backend.index('      nullify(self%model%qdra, self%model%qssdi, self%model%qrot)', call_pos)
assert pre >= 0 and pre < call_pos < post
segment = backend[pre:post]
assert segment.count('return') == 0
print('FPE10_G03_TRIAL_SCOPED_ASSOCIATE_CALL_RELEASE_ORDER=PASS')

assert 'type(fmr_b110_physical_forcing_t), target, intent(in) :: forcing_registry(:)' in serial
assert 'type(fmr_b110_physical_forcing_t), target, intent(in) :: forcing_registry(:)' in pool
assert 'call backends(w)%initialize(top_boundary, enable_direct_forcing_views=.true.)' in pool
# Single-worker reference remains the old call and does not opt in.
single = pool[pool.index('if (worker_count == 1) then'):pool.index('if ((worker_count /= 2 .and. worker_count /= 4)')]
assert 'enable_direct_forcing_views' not in single
assert 'fmr_run_serialized_physical_multiswap' in single
print('FPE10_G04_PARALLEL_ONLY_EXPLICIT_OPT_IN=PASS')

# Direct mode is explicitly narrower than the generic backend; no admission widening.
direct_guard = backend[backend.index('if (self%model%direct_forcing_views_enabled) then', call_pos-3000):call_pos]
for token in ('parameters%bottom_mode /= 7','parameters%swkimpl /= 0','parameters%swsophy /= 0',
              'parameters%root_extraction_active','parameters%snow_active','parameters%macropore_active',
              'parameters%frost_active','parameters%hysteresis_active','parameters%tabulated_hydraulics_active',
              'parameters%elasticity_active'):
    assert token in direct_guard, token
print('FPE10_G05_DIRECT_VIEW_PROFILE_FAIL_CLOSED=PASS')
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe09_cache_reuse.f90 -o "$OUT/cache_test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/cache_test.o" -o "$OUT/cache_test"
  "$OUT/cache_test" > "$OUT/cache.txt" 2>&1 || { cat "$OUT/cache.txt" >&2; exit 1; }
  for marker in \
    FPE09_CACHE_FIRST_ALLOCATION=PASS \
    FPE09_CACHE_SAME_SHAPE_REUSE_AND_REFRESH=PASS \
    FPE09_CACHE_SHAPE_CHANGE_REALLOCATION=PASS \
    FPE09_CACHE_SECOND_SHAPE_REUSE=PASS \
    FPE09_CACHE_LEGACY_CALL_FORM=PASS \
    'FPE09_CACHE_REUSE_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/cache.txt" || fail "missing O$opt cache marker: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe08_scratch_dedup.f90 -o "$OUT/memory_test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/memory_test.o" -o "$OUT/memory_test"
  "$OUT/memory_test" > "$OUT/memory.txt" 2>&1 || { cat "$OUT/memory.txt" >&2; exit 1; }
  grep -Fq 'FPE08_CANONICAL_LEAN_SCRATCH_BYTES=0' "$OUT/memory.txt" || fail "PE08 scratch regression O$opt"
  grep -Fq 'FPE08_KNOWN_WORKER_PAYLOAD_AFTER_BYTES=2380' "$OUT/memory.txt" || fail "PE08 payload regression O$opt"
  grep -Fq 'FPE08_SCRATCH_DEDUP_PROBE PASS' "$OUT/memory.txt" || fail "PE08 probe regression O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr20_parallel_v1_qualification.f90 -o "$OUT/science_test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/science_test.o" -o "$OUT/science_test"
  "$OUT/science_test" > "$OUT/science.txt" 2>&1 || { cat "$OUT/science.txt" >&2; exit 1; }
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
    grep -Fq "$marker" "$OUT/science.txt" || fail "missing O$opt science marker: $marker"
  done

  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -O"$opt" \
    tests/fpe/test_fpe10_target_lifetime_probe.f90 -o "$OUT/lifetime_test"
  "$OUT/lifetime_test" > "$OUT/lifetime.txt" 2>&1 || { cat "$OUT/lifetime.txt" >&2; exit 1; }
  grep -Fq 'FPE10_TARGET_LIFETIME_PROBE PASS' "$OUT/lifetime.txt" || fail "lifetime probe O$opt"

  echo "FPE10_O${opt}=PASS"
done

cmp -s "$BUILD/o0/cache.txt" "$BUILD/o2/cache.txt" || { diff -u "$BUILD/o0/cache.txt" "$BUILD/o2/cache.txt" >&2 || true; fail 'cache O0/O2 identity'; }
cmp -s "$BUILD/o0/memory.txt" "$BUILD/o2/memory.txt" || { diff -u "$BUILD/o0/memory.txt" "$BUILD/o2/memory.txt" >&2 || true; fail 'memory O0/O2 identity'; }
cmp -s "$BUILD/o0/science.txt" "$BUILD/o2/science.txt" || { diff -u "$BUILD/o0/science.txt" "$BUILD/o2/science.txt" >&2 || true; fail 'science O0/O2 identity'; }
cmp -s "$BUILD/o0/lifetime.txt" "$BUILD/o2/lifetime.txt" || { diff -u "$BUILD/o0/lifetime.txt" "$BUILD/o2/lifetime.txt" >&2 || true; fail 'lifetime O0/O2 identity'; }
echo 'FPE10_G06_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/cache.txt"
cat "$BUILD/o0/memory.txt"
cat "$BUILD/o0/science.txt"
cat "$BUILD/o0/lifetime.txt"
echo 'FPE10_FORCING_VIEW_QUALIFICATION_GATE=PASS'
