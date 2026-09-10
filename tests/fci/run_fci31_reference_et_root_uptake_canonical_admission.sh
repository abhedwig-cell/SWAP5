#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci31-$$"
mkdir -p "$BUILD"
cleanup_fci31() { rm -rf "$BUILD"; }
trap cleanup_fci31 EXIT
cd "$ROOT"

fail() { echo "FCI31_GATE_FAIL $*" >&2; exit 1; }

BASE=42b11df9b863afe9bfe2c24a6556293c04bbe555
CANDIDATE=764c291c70290b9956f7ce806b9e989601f25d0a
CANDIDATE_SOURCE=src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
CANDIDATE_BLOB=8ed7610144700f58d0b89482925471fcb2ff7d69
FVQ46_TEST_BLOB=5ea862e6337992afa1af5b2eec50fd0ddbba45a7
FVQ46_OUTPUT_SHA=fa86ec802b10d520a3984ad1553ffcee347af6bb26ca44cb136636b95c6187b0

# Exact one-source composition on the current F-CI30 canonical authority.
git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail 'candidate not descended from exact F-CI30 canonical base'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'qualification head not descended from exact source candidate'
mapfile -t candidate_delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src | sort)
printf '%s\n' "${candidate_delta[@]}" > "$BUILD/candidate-src.txt"
printf '%s\n' "$CANDIDATE_SOURCE" > "$BUILD/expected-src.txt"
cmp -s "$BUILD/candidate-src.txt" "$BUILD/expected-src.txt" || {
  cat "$BUILD/candidate-src.txt" >&2
  fail 'production delta from F-CI30 is not exactly the F-MR28 composition source'
}
git diff --quiet "$CANDIDATE"..HEAD -- src || {
  git diff --name-only "$CANDIDATE"..HEAD -- src >&2
  fail 'qualification mutated production source after F-CI31 candidate'
}
[[ "$(git rev-parse "HEAD:$CANDIDATE_SOURCE")" == "$CANDIDATE_BLOB" ]] || fail 'F-MR28 composition blob drift'
echo 'FCI31_EXACT_SINGLE_SOURCE_PRODUCTION_DELTA=PASS'
echo 'FCI31_PRODUCTION_SOURCE_IMMUTABLE_DURING_QUALIFICATION=PASS'
echo 'FCI31_EXACT_FMR28_DONOR_BLOB=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "protected blob drift $path expected=$expected actual=$actual"
}
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7bfb4a269256f0f1d50c32a20fd42479cf033528
check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
echo 'FCI31_FCI30_PARALLEL_AND_ET_ROOT_AUTHORITIES_LOCKED=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_reference_et_root_uptake_composition.f90').read_text(encoding='utf-8').lower()
for required in ('fmr_bind_reference_et_ptra_to_root_input','fmr_evaluate_shared_crop_root_uptake'):
    assert required in p, required
for forbidden in ('evaluate_macro_feddes_drought_uptake','reference_et_mm_per_day','vegetation_cover_fraction',
                  'crop_factor','co2_transpiration_factor','pressure_head','headcalc','newton','jacobian',
                  'mass_accounting','total_in','total_out','open(','read(','write(','save'):
    assert forbidden not in p, forbidden
print('FCI31_STATELESS_COMPOSITION_BOUNDARY=PASS')
print('FCI31_NO_ET_OR_ROOT_PHYSICS_REIMPLEMENTATION=PASS')
print('FCI31_NO_HYDRAULIC_INTERNAL_OR_MASS_LEDGER_ACCESS=PASS')
PY

# Rehydrate the exact independently qualified F-VQ46 oracle test from Git object history.
git cat-file blob "$FVQ46_TEST_BLOB" > "$BUILD/fvq46_test.f90"
[[ "$(git hash-object "$BUILD/fvq46_test.f90")" == "$FVQ46_TEST_BLOB" ]] || fail 'F-VQ46 test blob rehydration mismatch'
echo 'FCI31_EXACT_FVQ46_INDEPENDENT_TEST_REHYDRATED=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
DEPENDENCY_SRC=(
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
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
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
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/fvq46-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${DEPENDENCY_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr_reference_et_root_uptake_composition.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$CANDIDATE_SOURCE" -o "$obj"
  objects+=("$obj")
  echo "FCI31_FMR28_STRICT_COMPILE_O${opt}=PASS"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq46_test.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "F-VQ46 replay O$opt"; }
  for marker in \
    'FVQ46_HELD_OUT_ACTIVE_CASES=192' \
    'FVQ46_EXPLICIT_CHAIN_ORACLE=PASS' \
    'FVQ46_STALE_PTRA_INDEPENDENCE=PASS' \
    'FVQ46_UPSTREAM_ET_REJECTION_CONTAINED=PASS' \
    'FVQ46_INVALID_ROOT_GEOMETRY_CONTAINED=PASS' \
    'FVQ46_ACTIVE_UNAVAILABLE_COMMITTED_FAIL_CLOSED=PASS' \
    'FVQ46_INACTIVE_DEPENDENCY_FREE_ZERO_ROUTE=PASS' \
    'FVQ46_STATELESS_A_B_A_IDENTITY=PASS' \
    'FVQ46_FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing F-VQ46 marker O$opt: $marker"
  done
  [[ "$(sha256sum "$OUT/output.txt" | cut -d' ' -f1)" == "$FVQ46_OUTPUT_SHA" ]] || fail "F-VQ46 output SHA drift O$opt"
  echo "FCI31_FVQ46_INDEPENDENT_ORACLE_O${opt}=PASS"
done
cmp -s "$BUILD/fvq46-o0/output.txt" "$BUILD/fvq46-o2/output.txt" || fail 'F-VQ46 O0/O2 output drift'
echo 'FCI31_FVQ46_192_CASE_O0_O2_IDENTITY=PASS'
echo 'FCI31_FVQ46_QUALIFIED_OUTPUT_SHA_PRESERVED=PASS'

# Replay the full F-CI30 admission matrix on this candidate. Patch only the
# governance clause that previously required zero src additions after F-CI30;
# the replacement allows exactly the one source-bound F-MR28 composition file.
FCI30_REPLAY="$BUILD/fci30-preservation.sh"
cp tests/fci/run_fci30_parallel_v1_canonical_admission.sh "$FCI30_REPLAY"
python3 - "$FCI30_REPLAY" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
old_trap='''trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fmr/.fci30-fmr18-replay-$$.sh" "$ROOT/tests/fci/.fci30-fci28-replay-$$.sh"' EXIT\n'''
new_trap='''cleanup_fci30_replay() {
  rm -rf "$BUILD"
  rm -f "$ROOT/tests/fmr/.fci30-fmr18-replay-$$.sh" "$ROOT/tests/fci/.fci30-fci28-replay-$$.sh"
}
trap cleanup_fci30_replay EXIT
'''
if s.count(old_trap) != 1:
    raise SystemExit(f'F-CI31 F-CI30 cleanup anchor count={s.count(old_trap)}')
s=s.replace(old_trap,new_trap,1)
old="git diff --quiet \"$CANDIDATE\"..HEAD -- src || fail 'qualification mutated production source after candidate'"
new='''mapfile -t fci31_extension < <(git diff --name-only "$CANDIDATE"..HEAD -- src | sort)
printf '%s\\n' "${fci31_extension[@]}" > "$BUILD/fci31-extension-actual.txt"
printf '%s\\n' src/runtime/mod_fmr_reference_et_root_uptake_composition.f90 > "$BUILD/fci31-extension-expected.txt"
cmp -s "$BUILD/fci31-extension-actual.txt" "$BUILD/fci31-extension-expected.txt" || {
  cat "$BUILD/fci31-extension-actual.txt" >&2
  fail 'F-CI31 extension beyond F-CI30 is not exactly one qualified composition source'
}
echo 'FCI31_FCI30_ALLOWED_SINGLE_SOURCE_EXTENSION=PASS' '''
if s.count(old) != 1:
    raise SystemExit(f'F-CI31 F-CI30 production-immutability anchor count={s.count(old)}')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY
bash "$FCI30_REPLAY" > "$BUILD/fci30.txt" 2>&1 || { cat "$BUILD/fci30.txt" >&2; fail 'F-CI30 full preservation replay'; }
for marker in \
  FCI31_FCI30_ALLOWED_SINGLE_SOURCE_EXTENSION=PASS \
  FCI30_EXACT_CURRENT_CANONICAL_THREE_FILE_POSTIMAGE=PASS \
  FCI30_FCI29_PTRA_BLOB_PRESERVED=PASS \
  FCI30_PARALLEL_O0=PASS \
  FCI30_PARALLEL_O2=PASS \
  FCI30_PARALLEL_O0_O2_OUTPUT_IDENTITY=PASS \
  FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS \
  FMQ26_HARD_MASS_ALL_CASES=PASS \
  FMQ26_WORKER_COUNT_INDEPENDENCE=PASS \
  FMQ26_DETERMINISTIC_REPLAY=PASS \
  FMQ26_CANONICAL_PUBLICATION_ORDER=PASS \
  FCI30_SERIALIZED_SPARSE_RECEIPT_SEMANTICS_PRESERVED=PASS \
  FCI30_FCI28_RESTART_AND_FCI27_ET_PRESERVED=PASS \
  FVQ41_REFERENCE_ET_PTRA_ROOT_INPUT_QUALIFICATION \
  FCI30_RESTRICTED_PARALLEL_REAL_PHYSICS_V1_CANONICAL_ADMISSION_GATE=PASS; do
  grep -Fq "$marker" "$BUILD/fci30.txt" || { cat "$BUILD/fci30.txt" >&2; fail "missing F-CI30 preservation marker: $marker"; }
done
echo 'FCI31_FCI30_FULL_PARALLEL_MASS_RESTART_ET_PTRA_PRESERVATION=PASS'

cat "$BUILD/fvq46-o0/output.txt"
grep -E '^(FCI31_FCI30_ALLOWED_SINGLE_SOURCE_EXTENSION|FCI30_PARALLEL_O[02]|FCI30_PARALLEL_O0_O2_OUTPUT_IDENTITY|FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL|FMQ26_HARD_MASS_ALL_CASES|FMQ26_WORKER_COUNT_INDEPENDENCE|FMQ26_DETERMINISTIC_REPLAY|FMQ26_CANONICAL_PUBLICATION_ORDER|FCI30_SERIALIZED_SPARSE_RECEIPT_SEMANTICS_PRESERVED|FCI30_FCI28_RESTART_AND_FCI27_ET_PRESERVED|FCI30_RESTRICTED_PARALLEL_REAL_PHYSICS_V1_CANONICAL_ADMISSION_GATE)' "$BUILD/fci30.txt" || true
echo 'FCI31_REFERENCE_ET_ROOT_UPTAKE_CANONICAL_ADMISSION_GATE=PASS'
