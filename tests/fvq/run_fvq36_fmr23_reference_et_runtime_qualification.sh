#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq36-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=a0cf508581677d1af100d754bc9cb5e5d67ac84d
RUNTIME_SOURCE=src/runtime/mod_fmr_reference_et_demand_binding.f90
ET_SOURCE=src/process/mod_reference_et_demand_process.f90
FMR23_STATUS=integration/f-mr/F-MR23_STATUS.json

if ! git diff --quiet "$BASE"..HEAD -- src; then
  echo 'FVQ36_CANDIDATE_PRODUCTION_MUTATED' >&2
  git diff --name-only "$BASE"..HEAD -- src >&2
  exit 1
fi
echo 'FVQ36_CANDIDATE_PRODUCTION_IMMUTABLE=PASS'

if ! git diff --quiet "$BASE"..HEAD -- tests/fmr; then
  echo 'FVQ36_OWNER_TESTS_MUTATED' >&2
  git diff --name-only "$BASE"..HEAD -- tests/fmr >&2
  exit 1
fi
echo 'FVQ36_OWNER_TESTS_IMMUTABLE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ36_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob "$RUNTIME_SOURCE" 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob "$ET_SOURCE" f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob "$FMR23_STATUS" 3e2aef36f902e7525adabc133fddb3c26f31c78f
echo 'FVQ36_CANDIDATE_AND_UPSTREAM_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

p = Path('src/runtime/mod_fmr_reference_et_demand_binding.f90').read_text()
low = p.lower()
for forbidden in [
    'headcalc', 'newton', 'jacobian', 'process_hydraulic_view',
    'root_water_uptake', 'crop_root_uptake', 'mass_accounting',
    'total_in', 'total_out', 'open(', 'read(', 'write(', 'flday',
    'calendar', 'date', 'allocatable', 'save'
]:
    assert forbidden not in low, forbidden
for required in [
    'canonical_interval_t', 'fmr_reference_et_forcing_span_t',
    'interval%t1 <= interval%t0', 'forcing_span%t1 <= forcing_span%t0',
    'interval%t0 < forcing_span%t0', 'interval%t1 > forcing_span%t1',
    'evaluate_restricted_reference_et_demand', 'reference_et_mm_per_day'
]:
    assert required in p, required
status = json.loads(Path('integration/f-mr/F-MR23_STATUS.json').read_text())
assert status['decision'] == 'RESTRICTED_REFERENCE_ET_GENERIC_TIME_RUNTIME_BINDING_READY_FOR_INDEPENDENT_QUALIFICATION'
assert status['candidate']['runtime_source_blob'] == '8c679f911c9a82c498258224d83f5fce3cb09163'
assert status['scope']['potential_ET_rates_only'] is True
assert status['scope']['root_uptake_binding'] is False
assert status['scope']['hydraulic_boundary_binding'] is False
assert status['scope']['mass_ledger_binding'] is False
print('FVQ36_GENERIC_TIME_BINDING_STATIC=PASS')
print('FVQ36_NO_ROOT_HYDRAULIC_OR_MASS_SCOPE=PASS')
print('FVQ36_FMR23_STATUS_SCOPE_LOCK=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/transaction/mod_transaction_reference.f90 -o "$OUT/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_contracts.f90 -o "$OUT/mod_canonical_contracts.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    "$ET_SOURCE" -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    "$RUNTIME_SOURCE" -o "$OUT/mod_fmr_reference_et_demand_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq36_fmr23_reference_et_runtime_oracle.f90 -o "$OUT/test_fvq36.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_reference_et_demand_process.o" \
    "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/test_fvq36.o" -o "$OUT/test_fvq36"
  "$OUT/test_fvq36" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FVQ36_INDEPENDENT_GRID_CASES=13824' \
    'FVQ36_GENERIC_SIGNED_TIME_ORIGINS=PASS' \
    'FVQ36_VARIABLE_FORCING_SPAN_LENGTHS=PASS' \
    'FVQ36_INDEPENDENT_ET_RATE_ORACLE=PASS' \
    'FVQ36_RATE_INVARIANT_TO_CONTAINED_INTERVAL_DURATION=PASS' \
    'FVQ36_EXACT_FORCING_BOUNDARIES=PASS' \
    'FVQ36_OUTSIDE_FORCING_FAILS_BEFORE_PROCESS=PASS' \
    'FVQ36_INVALID_TIME_GEOMETRY_FAIL_CLOSED=PASS' \
    'FVQ36_NONEMERGED_DEPENDENCY_SEMANTICS=PASS' \
    'FVQ36_STATELESS_A_B_A_IDENTITY=PASS' \
    'FVQ36_FMR23_REFERENCE_ET_RUNTIME_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FVQ36_QUALIFICATION_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ36_QUALIFICATION_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ36_QUALIFICATION_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FVQ36_FMR23_REFERENCE_ET_RUNTIME_QUALIFICATION PASS'
