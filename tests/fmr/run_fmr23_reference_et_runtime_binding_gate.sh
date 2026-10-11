#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr23-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=f49e17c6627717d5dea181808a122f2e35960739
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/runtime/mod_fmr_reference_et_demand_binding.f90" ]] || {
  echo "FMR23_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FMR23_PRODUCTION_DELTA_SINGLE_RUNTIME_BINDING=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR23_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_canonical_contracts.f90 c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
echo 'FMR23_QUALIFIED_ET_AND_TIME_CONTRACT_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/runtime/mod_fmr_reference_et_demand_binding.f90').read_text()
low = p.lower()
for forbidden in [
    'headcalc', 'newton', 'jacobian', 'process_hydraulic_view',
    'root_water_uptake', 'crop_root_uptake', 'mass_accounting',
    'total_in', 'total_out', 'open(', 'read(', 'write(', 'flDay'.lower(),
    'date', 'calendar'
]:
    assert forbidden not in low, forbidden
assert 'canonical_interval_t' in p
assert 'fmr_reference_et_forcing_span_t' in p
assert 'interval%t1 <= interval%t0' in p
assert 'forcing_span%t1 <= forcing_span%t0' in p
assert 'interval%t0 < forcing_span%t0' in p
assert 'interval%t1 > forcing_span%t1' in p
assert 'evaluate_restricted_reference_et_demand' in p
assert 'reference_et_mm_per_day' in p
assert 'interval_duration' in p
assert 'allocatable' not in low
assert 'save' not in low
print('FMR23_GENERIC_TIME_CONTRACT_STATIC=PASS')
print('FMR23_NO_HYDRAULIC_ROOT_OR_MASS_BINDING=PASS')
print('FMR23_NO_PERSISTENT_RUNTIME_STATE=PASS')
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
    src/process/mod_reference_et_demand_process.f90 -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_reference_et_demand_binding.f90 -o "$OUT/mod_fmr_reference_et_demand_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr23_reference_et_runtime_binding.f90 -o "$OUT/test_fmr23_reference_et_runtime_binding.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_reference_et_demand_process.o" \
    "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/test_fmr23_reference_et_runtime_binding.o" \
    -o "$OUT/test_fmr23_reference_et_runtime_binding"
  "$OUT/test_fmr23_reference_et_runtime_binding" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FMR23_ARBITRARY_SUBDAY_INTERVAL=PASS' \
    'FMR23_FORCING_SPAN_CONTAINMENT=PASS' \
    'FMR23_RATE_NOT_IMPLICITLY_TIME_INTEGRATED=PASS' \
    'FMR23_INVALID_TIME_FAIL_CLOSED=PASS' \
    'FMR23_PROCESS_REJECTION_FAIL_CLOSED=PASS' \
    'FMR23_NONEMERGED_CANOPY_SEMANTICS=PASS' \
    'FMR23_STATELESS_A_B_A_IDENTITY=PASS' \
    'FMR23_REFERENCE_ET_RUNTIME_BINDING_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FMR23_RUNTIME_BINDING_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR23_RUNTIME_BINDING_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FMR23_RUNTIME_BINDING_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FMR23_REFERENCE_ET_RUNTIME_BINDING_GATE PASS'
