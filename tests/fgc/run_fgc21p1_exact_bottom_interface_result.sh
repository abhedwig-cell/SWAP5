#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc21p1-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

RESTART=c6494f913303b7aefc4f9c53c6c157082d54ea4b
for spec in \
  'src/transaction/mod_transaction_reference.f90:bottom_interface_exchange_available' \
  'src/runtime/mod_canonical_contracts.f90:bottom_outward_exchange_native' \
  'src/runtime/mod_canonical_interval_runtime.f90:accumulate_accepted_bottom_interface' \
  'src/kernel/mod_kernel_transactions.f90:terminal_bottom_outward_flux_native' \
  'src/runtime/mod_fmr_serialized_reference_backend.f90:-solve_result%bottom_flux * step_duration'; do
  file="${spec%%:*}"
  token="${spec#*:}"
  grep -Fq -- "$token" "$file" || { echo "FGC21P1_MISSING_SOURCE_SEMANTIC $file $token" >&2; exit 1; }
done
echo 'FGC21P1_REQUIRED_SOURCE_SEMANTICS=PASS'

python3 - <<'PY'
from pathlib import Path
transaction = Path('src/transaction/mod_transaction_reference.f90').read_text()
canonical = Path('src/runtime/mod_canonical_interval_runtime.f90').read_text()
kernel = Path('src/kernel/mod_kernel_transactions.f90').read_text()
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
contracts = Path('src/runtime/mod_canonical_contracts.f90').read_text()

for text, name in [(transaction,'transaction'),(canonical,'canonical-runtime'),(kernel,'kernel'),(contracts,'canonical-contract')]:
    low=text.lower()
    for forbidden in ['86400', 'cm_to_m', 'm_to_cm', 'modflow', '.swp', 'midnight', 'headcalc%']:
        assert forbidden not in low, (name, forbidden)

assert 'half1_outcome%bottom_outward_exchange_native +' in transaction
assert 'half2_outcome%bottom_outward_exchange_native' in transaction
assert 'result%terminal_bottom_outward_flux_native = half2_outcome%terminal_bottom_outward_flux_native' in transaction
assert 'result%accepted_bottom_outward_exchange_native = outcome%bottom_outward_exchange_native' in transaction
assert 'candidate_exchange = aggregate_exchange + tx%accepted_bottom_outward_exchange_native' in canonical
assert 'if (aggregate_bottom_available .and. ieee_is_finite(aggregate_bottom_exchange)' in canonical
assert 'result%bottom_interface_exchange_available = runtime_result%bottom_interface_exchange_available' in kernel
assert 'outcome%bottom_outward_exchange_native = -solve_result%bottom_flux * step_duration' in backend
assert 'outcome%terminal_bottom_outward_flux_native = -solve_result%bottom_flux' in backend
assert 'outcome%bottom_interface_exchange_available = .true.' in backend
print('FGC21P1_ACCEPTED_ROUTE_STATIC=PASS')
print('FGC21P1_GENERIC_NATIVE_UNIT_TRANSPORT=PASS')
print('FGC21P1_NO_SOLVER_INTERNAL_COUPLER_DEPENDENCY=PASS')
PY

changed_src="$(git diff --name-only "$RESTART" -- src | sort)"
expected_src="$(printf '%s\n' \
  src/kernel/mod_kernel_transactions.f90 \
  src/runtime/mod_canonical_contracts.f90 \
  src/runtime/mod_canonical_interval_runtime.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/transaction/mod_transaction_reference.f90 | sort)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FGC21P1_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf 'actual:\n%s\nexpected:\n%s\n' "$changed_src" "$expected_src" >&2
  exit 1
}
echo 'FGC21P1_PRODUCTION_DELTA_EXACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/transaction/mod_transaction_reference.f90 -o "$OUT/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_contracts.f90 -o "$OUT/mod_canonical_contracts.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_interval_runtime.f90 -o "$OUT/mod_canonical_interval_runtime.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/kernel/mod_kernel_transactions.f90 -o "$OUT/mod_kernel_transactions.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fgc/test_fgc21p1_exact_bottom_interface_result.f90 -o "$OUT/test.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" \
    "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_canonical_interval_runtime.o" \
    "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FGC21P1_TWO_HALF_REJECTED_FULL_EXCLUDED=PASS' \
    'FGC21P1_RETRY_REJECTED_EXCHANGE_EXCLUDED=PASS' \
    'FGC21P1_MODEL_CERTIFICATE_ACCEPTED_ONLY=PASS' \
    'FGC21P1_MISSING_INTERFACE_RESULT_FAILS_CLOSED=PASS' \
    'FGC21P1_CANONICAL_ACCEPTED_SUBSTEP_AGGREGATION=PASS' \
    'FGC21P1_INCOMPLETE_CANONICAL_INTERVAL_NO_PUBLICATION=PASS' \
    'FGC21P1_EXACT_BOTTOM_INTERFACE_RESULT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FGC21P1_TRANSACTION_CANONICAL_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FGC21P1_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FGC21P1_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FGC21P1_OWNER_GATE PASS'
