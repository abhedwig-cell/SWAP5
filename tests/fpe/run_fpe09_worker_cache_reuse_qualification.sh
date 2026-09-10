#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe09-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=0c136148fb5a53db3804070ac74fc8cef55d81f3
fail() { echo "FPE09_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:64c3d9581c71fc7bf5e5f3764995d41280312a2e \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:be4005a97e35c498ffc40297409a75efe65ff5df \
  src/runtime/mod_a23bu_worker_execution_context.f90:0ecb09bfa318a284e7841749d474d2f871363c81 \
  src/solver/mod_reference_richards_workspace.f90:59ef9d037c1875610d45ac83387ebab9e917e0fe \
  src/solver/mod_b110_default_mvg_provider.f90:ffd4701740dceb2df12f05e9cad73e81eeb55b43 \
  src/adapter/mod_reference_richards_legacy_binding.f90:1e3a227883cb2a0f79e40a22f016e7953d5fbab1 \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:393e9bfbc4c078d259a5ec70aca78f50e54e8b35 \
  tests/fmr/test_fmr20_parallel_v1_qualification.f90:bfebfde94b3931367d69d502a6fc7b1deb8f2ad6 \
  tests/fpe/test_fpe08_scratch_dedup.f90:3b9ae676b5e38a782336af80cfd6515f30bac848 \
  tests/fpe/test_fpe09_cache_reuse.f90:ce067bb5dc68874e18a9afd89f31eb092a09f74b; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FPE09_G01_SOURCE_LOCK=PASS'

if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  git fetch --quiet --no-tags --depth=1 origin "$BASE"
fi
git diff --name-only "$BASE" HEAD -- src | sort > "$BUILD/src.changed"
printf '%s\n' \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/solver/mod_b110_default_mvg_provider.f90 | sort > "$BUILD/src.expected"
diff -u "$BUILD/src.expected" "$BUILD/src.changed" >/dev/null || {
  diff -u "$BUILD/src.expected" "$BUILD/src.changed" >&2 || true
  fail 'production source scope differs from exact two-file F-PE09 optimization'
}
echo 'FPE09_G02_BOUNDED_PRODUCTION_SCOPE=PASS'

python3 - <<'PY'
from pathlib import Path
mvg=Path('src/solver/mod_b110_default_mvg_provider.f90').read_text()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
assert 'type(b110_default_mvg_parameters_t), intent(inout) :: parameters' in mvg
assert 'logical, intent(out), optional :: storage_reused' in mvg
assert mvg.count('deallocate(parameters%cofgen)') == 1
assert 'if (.not. allocated(parameters%cofgen)) allocate(parameters%cofgen(B110_MCOF_REQUIRED,n))' in mvg
assert 'parameters%cofgen = 0.0_real64' in mvg
assert 'if (.not. associated(self%soil_parameters)) allocate(self%soil_parameters)' in backend
assert 'if (.not. associated(self%hydraulic_parameters)) allocate(self%hydraulic_parameters)' in backend
assert 'if (.not. associated(self%constitutive)) allocate(self%constitutive)' in backend
assert 'if (.not. associated(self%source_sink)) allocate(self%source_sink)' in backend
assert 'if (.not. associated(self%root_sink)) allocate(self%root_sink)' in backend
assert 'if (associated(self%soil_parameters)) deallocate(self%soil_parameters)' not in backend
for field in ('z','dz','node_distance'):
    assert f'if (size(self%soil_parameters%{field}) /= n) deallocate(self%soil_parameters%{field})' in backend
    assert f'if (.not. allocated(self%soil_parameters%{field})) allocate(self%soil_parameters%{field}(n))' in backend
assert 'if (size(self%qdra,1) /= size(forcing%drainage_flux_by_level,1) .or. size(self%qdra,2) /= n) deallocate(self%qdra)' in backend
assert 'if (size(self%qssdi) /= n) deallocate(self%qssdi)' in backend
assert 'if (size(self%qrot) /= n) deallocate(self%qrot)' in backend
assert 'if (.not. associated(self%qdra)) allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))' in backend
assert 'if (.not. associated(self%qssdi)) allocate(self%qssdi(n))' in backend
assert 'if (.not. associated(self%qrot)) allocate(self%qrot(n))' in backend
for overwrite in ('self%soil_parameters%z = parameters%z','self%soil_parameters%dz = parameters%dz',
                  'self%soil_parameters%node_distance = parameters%node_distance',
                  'self%qdra = forcing%drainage_flux_by_level','self%qssdi = forcing%subsurface_irrigation_source',
                  'self%qrot = forcing%root_extraction_sink'):
    assert overwrite in backend, overwrite
assert 'parameter_set_id ==' not in backend
print('FPE09_G03_EXACT_SHAPE_REUSE_SOURCE_SEMANTICS=PASS')
print('FPE09_G04_NO_PARAMETER_ID_SHORTCUT_OR_DIRECT_VIEW=PASS')
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
  echo "FPE09_O${opt}=PASS"
done

cmp -s "$BUILD/o0/cache.txt" "$BUILD/o2/cache.txt" || { diff -u "$BUILD/o0/cache.txt" "$BUILD/o2/cache.txt" >&2 || true; fail 'cache O0/O2 identity'; }
cmp -s "$BUILD/o0/memory.txt" "$BUILD/o2/memory.txt" || { diff -u "$BUILD/o0/memory.txt" "$BUILD/o2/memory.txt" >&2 || true; fail 'PE08 O0/O2 identity'; }
cmp -s "$BUILD/o0/science.txt" "$BUILD/o2/science.txt" || { diff -u "$BUILD/o0/science.txt" "$BUILD/o2/science.txt" >&2 || true; fail 'science O0/O2 identity'; }
echo 'FPE09_G05_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/cache.txt"
cat "$BUILD/o0/memory.txt"
cat "$BUILD/o0/science.txt"
echo 'FPE09_WORKER_CACHE_REUSE_QUALIFICATION_GATE=PASS'
