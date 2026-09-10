#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr31-$$"
BASE="e3964ec0ef312f974461aeac70fb9bc5720803e3"
SOURCE="src/runtime/mod_fmr_root_uptake_attribution_receipt.f90"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR31_GATE_FAIL $*" >&2; exit 1; }

# Source authority: F-MR31 is exactly one production-source remediation on the
# frozen canonical authority.  Later canonical movement is unrelated DIVDRA
# work and is intentionally not folded into this source-bound owner candidate.
git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD not descended from frozen canonical authority'
printf '%s\n' "$SOURCE" > "$BUILD/expected-src.txt"
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src.txt"
cmp -s "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || {
  cat "$BUILD/actual-src.txt" >&2
  fail 'production delta is not exactly the F-MR31 attribution module'
}
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "trusted dependency drift: $path expected=$expected actual=$actual"
}
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7bfb4a269256f0f1d50c32a20fd42479cf033528
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b
check_blob src/kernel/mod_kernel_transactions.f90 f1acff10dd99c308a00f434440d6a9ef14632f0d
echo 'FMR31_EXACT_ONE_SOURCE_REMEDIATION=PASS'
echo 'FMR31_TRUSTED_TRANSACTION_RUNTIME_BLOBS_LOCKED=PASS'

python3 - <<'PY'
from pathlib import Path
import re
s = Path('src/runtime/mod_fmr_root_uptake_attribution_receipt.f90').read_text(encoding='utf-8').lower()
flat = ' '.join(s.split())
for forbidden in (
    'kernel_candidate_state_t',
    'fmr_prepare_root_uptake_attribution',
    'fmr_finalize_root_uptake_attribution',
):
    assert forbidden not in s, f'unsafe detached candidate/forcing API survived: {forbidden}'
for required in (
    'fmr_run_serialized_root_uptake_attribution',
    'fmr_run_serialized_physical_multiswap',
    'forcing_registry',
    'receipt_column_ids=attribution_column_ids',
    'commit_receipts=commit_receipts',
    'root_extraction_sink',
    'results(result_index)%mass%total_out',
):
    assert required in flat, f'missing trusted composition token: {required}'
assert s.count('public :: fmr_run_serialized_root_uptake_attribution') == 1
assert 'public :: fmr_prepare' not in s and 'public :: fmr_finalize' not in s
# Attribution may inspect canonical mass but must not mutate it or book a
# second output.  Reject any assignment into result mass components.
assert not re.search(r'%mass%[a-z0-9_]+\s*=', s), 'attribution mutates transaction mass accounting'
for forbidden in ('mass_out = mass_out +', 'total_out = total_out +', 'accepted_transaction_count ='):
    assert forbidden not in s, f'second mass booking pattern: {forbidden}'
print('FMR31_DETACHED_CANDIDATE_FORCING_API_REMOVED=PASS')
print('FMR31_TRUSTED_ONE_CALL_RUNTIME_BINDING=PASS')
print('FMR31_NO_SECOND_MASS_LEDGER_BOOKING=PASS')
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
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

  obj="$OUT/mod_fmr_root_uptake_attribution_receipt.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SOURCE" -o "$obj"
  objects+=("$obj")
  obj="$OUT/mod_fmr04_fixed_top_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/mod_fmr04_fixed_top_provider.f90 -o "$obj"
  objects+=("$obj")
  # The test fixture intentionally reuses an established exact-real uniformity
  # assertion; warnings remain visible, but only the new production source is
  # held to -Werror in this owner gate.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr31_root_attribution_forcing_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "O$opt executable"; }

  for marker in \
    'FMR31_EXACT_RUNTIME_FORCING_ATTRIBUTION=PASS' \
    'FMR31_A_B_NO_CROSS_CONTAMINATION=PASS' \
    'FMR31_PHYSICS_STATE_AND_MASS_IDENTITY=PASS' \
    'FMR31_ARBITRARY_INTERVAL_PROVENANCE=PASS' \
    'FMR31_REJECTED_COLUMN_NO_ATTRIBUTION=PASS' \
    'FMR31_INVALID_SPARSE_REQUEST_FAILS_PREMUTATION=PASS' \
    'FMR31_ROOT_ATTRIBUTION_FORCING_BINDING_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "FMR31_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 scientific output identity'
}
echo 'FMR31_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR31_OWNER_GATE=PASS'
