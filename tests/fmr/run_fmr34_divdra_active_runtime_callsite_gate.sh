#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr34-$$"
EVIDENCE_DIR="${FMR34_EVIDENCE_DIR:-}"
BASE="c0fc660c1e68064f77f4ec4f3376d385fbe88b4a"
HELPER="src/runtime/mod_fmr_divdra_serialized_composition.f90"
RUNTIME="src/runtime/mod_fmr_divdra_serialized_runtime.f90"
TEST="tests/fmr/test_fmr34_divdra_active_runtime_callsite_v2.f90"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR34_GATE_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "trusted dependency drift: $path expected=$expected actual=$actual"
}

git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD not descended from current canonical F-CI35 authority'
printf '%s\n' "$HELPER" "$RUNTIME" | sort > "$BUILD/expected-src.txt"
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src.txt"
cmp -s "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || {
  cat "$BUILD/actual-src.txt" >&2
  fail 'production delta is not exactly the two F-MR34 feature runtime files'
}
[[ -z "$(git diff --name-only "$BASE"..HEAD -- reference)" ]] || fail 'reference source changed'

check_blob src/process/mod_drainage_spatial_distribution.f90 1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a
check_blob src/runtime/mod_fmr_divdra_runtime_binding.f90 e4737fb6f00a11ed16e34bee44b3442ac84b31aa
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FMR34_EXACT_TWO_FEATURE_RUNTIME_SOURCE_DELTA=PASS'
echo 'FMR34_GENERIC_RUNTIME_BYTE_IDENTICAL=PASS'
echo 'FMR34_TRUSTED_DIVDRA_AUTHORITIES_LOCKED=PASS'
echo 'FMR34_REFERENCE_SOURCE_UNCHANGED=PASS'

python3 - <<'PY'
from pathlib import Path
import re
helper = Path('src/runtime/mod_fmr_divdra_serialized_composition.f90').read_text(encoding='utf-8').lower()
runtime = Path('src/runtime/mod_fmr_divdra_serialized_runtime.f90').read_text(encoding='utf-8').lower()
combined = helper + '\n' + runtime
flat = ' '.join(combined.split())
for token in ('fmr_preflight_serialized_divdra','fmr_bind_single_level_positive_divdra',
              'fmr_run_serialized_physical_multiswap','cleanup_materialized_divdra',
              'distribution_parameter_ref','hydraulic_view_ref','scalar_transfer'):
    assert token in flat, f'missing required composition token: {token}'
for forbidden in ('fmr_build_committed_process_hydraulic_view','headcalc','modflow','.swp',
                  'predictor','corrector','jacobian','response_tangent'):
    assert forbidden not in combined, f'forbidden scope coupling: {forbidden}'
assert not re.search(r'%mass%[a-z0-9_]+\s*=', combined), 'F-MR34 mutates transaction mass accounting'
for forbidden in ('drainage resistance','exchange_law','qdrain =','mass_out = mass_out +','total_out = total_out +'):
    assert forbidden not in combined, f'forbidden exchange/mass reconstruction: {forbidden}'
assert 'forcing_registry =' not in runtime, 'whole forcing registry copy/mutation detected'
assert 'effective_forcing_registry' not in runtime, 'full registry shadow copy detected'
assert 'forcing_use_count' in helper and 'forcing_use_count(forcing_index) /= 1' in helper
assert runtime.count('call fmr_run_serialized_physical_multiswap(') == 1
assert runtime.find('call fmr_preflight_serialized_divdra') < runtime.find('call fmr_run_serialized_physical_multiswap(')
assert runtime.find('cleanup_materialized_divdra') >= 0
print('FMR34_PREFLIGHT_BEFORE_CORE_RUNTIME=PASS')
print('FMR34_NO_HIDDEN_COMMITTED_VIEW_SUBSTITUTION=PASS')
print('FMR34_NO_EXCHANGE_LAW_OR_SECOND_MASS_BOOKING=PASS')
print('FMR34_SHARED_FORCING_FAIL_CLOSED_GATE=PASS')
print('FMR34_NO_FULL_FORCING_REGISTRY_COPY=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/process/mod_drainage_spatial_distribution.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_divdra_runtime_binding.f90
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
  for src in "$HELPER" "$RUNTIME"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr04_fixed_top_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/mod_fmr04_fixed_top_provider.f90 -o "$obj"
  objects+=("$obj")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "O$opt executable"; }
  for marker in \
    'FMR34_INACTIVE_GENERIC_RUNTIME_IDENTITY=PASS' \
    'FMR34_MANUAL_BINDING_RUNTIME_EQUIVALENCE=PASS' \
    'FMR34_EXISTING_MASS_LEDGER_EXACTLY_ONCE_EQUIVALENCE=PASS' \
    'FMR34_CALLER_FORCING_RESTORED=PASS' \
    'FMR34_EXPLICIT_HYDRAULIC_VIEW_NOT_SUBSTITUTED=PASS' \
    'FMR34_ZERO_TRANSFER_ACTIVE_CALLSITE=PASS' \
    'FMR34_INVALID_TRANSFER_PRECOMMIT_REJECTION=PASS' \
    'FMR34_PREBOUND_TARGET_NO_OVERWRITE=PASS' \
    'FMR34_SHARED_FORCING_NO_CROSS_COLUMN_LEAKAGE=PASS' \
    'FMR34_ACTIVE_RUNTIME_CALLSITE_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "FMR34_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 runtime output identity'
}
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "FMR34_O0_O2_OUTPUT_SHA256=$HASH"
echo 'FMR34_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
  cp "$BUILD/o0/output.txt" "$EVIDENCE_DIR/o0-output.txt"
  cp "$BUILD/o2/output.txt" "$EVIDENCE_DIR/o2-output.txt"
  printf '%s\n' "$HASH" > "$EVIDENCE_DIR/output-sha256.txt"
  git rev-parse HEAD > "$EVIDENCE_DIR/tested-head.txt"
  git rev-parse "HEAD:$HELPER" > "$EVIDENCE_DIR/helper-blob.txt"
  git rev-parse "HEAD:$RUNTIME" > "$EVIDENCE_DIR/runtime-blob.txt"
fi
echo 'FMR34_OWNER_GATE=PASS'
