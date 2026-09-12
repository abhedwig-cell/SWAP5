#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-ebi01-$$"
BASE="c6494f913303b7aefc4f9c53c6c157082d54ea4b"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() {
  echo "EBI01_GATE_FAIL $*" >&2
  exit 1
}

cd "$ROOT"

git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/src-delta.txt"
printf '%s\n' \
  'src/kernel/mod_energy_conservation_types.f90' \
  'src/runtime/mod_energy_conservation_ledger.f90' | sort > "$BUILD/expected-src-delta.txt"
diff -u "$BUILD/expected-src-delta.txt" "$BUILD/src-delta.txt" || fail "unexpected production source delta"
echo 'EBI01_EXACT_ADDITIVE_SOURCE_DELTA=PASS'

for src in src/kernel/mod_energy_conservation_types.f90 src/runtime/mod_energy_conservation_ledger.f90; do
  if grep -Eiq '^[[:space:]]*use[[:space:]].*(groundwater_interface_mass_ledger|groundwater_coupling)' "$src"; then
    fail "energy accounting depends on groundwater-specific mass authority: $src"
  fi
  if grep -Eiq '^[[:space:]]*(open|read|write|close)[[:space:]]*\(' "$src"; then
    fail "I/O primitive found in energy accounting production source: $src"
  fi
done
echo 'EBI01_NO_GROUNDWATER_MASS_LEDGER_DEPENDENCY=PASS'
echo 'EBI01_KERNEL_RUNTIME_IO_SEPARATION=PASS'

COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/types-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/kernel/mod_energy_conservation_types.f90 -o "$OUT/types.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/eb/test_ebi01_energy_conservation_types.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/types.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "energy type test O$opt"; }
  for marker in \
    'EBI01_INTERNAL_TRANSFER_CANCELS_IN_OUTER_CV=PASS' \
    'EBI01_NESTED_CONTROL_VOLUMES_CLOSE=PASS' \
    'EBI01_INVALID_ACCOUNTING_INPUT_REJECTED=PASS' \
    'EBI01_ENERGY_CONSERVATION_TYPES_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing O$opt marker: $marker"
  done
done
cmp "$BUILD/types-o0/out.txt" "$BUILD/types-o2/out.txt" || fail "energy type O0/O2 output mismatch"
echo 'EBI01_TYPES_O0_O2_IDENTITY=PASS'

for opt in 0 2; do
  OUT="$BUILD/receipt-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${BASE_MODULES[@]}" src/kernel/mod_energy_conservation_types.f90 src/runtime/mod_energy_conservation_ledger.f90; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/eb/test_ebi01_energy_ledger_receipt_integration.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "receipt integration O$opt"; }
  for marker in \
    'EBI01_REAL_FKT_RECEIPT_PUBLISHES_ENERGY_ONCE=PASS' \
    'EBI01_ROLLBACK_PUBLISHES_NO_ENERGY=PASS' \
    'EBI01_ROLLBACK_REPLAY_FROM_SAME_COMMITTED_ORIGIN=PASS' \
    'EBI01_EXISTING_FKT_MASS_PATH_PRESERVED=PASS' \
    'EBI01_ENERGY_LEDGER_RECEIPT_INTEGRATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing O$opt marker: $marker"
  done
done
cmp "$BUILD/receipt-o0/out.txt" "$BUILD/receipt-o2/out.txt" || fail "receipt integration O0/O2 output mismatch"
echo 'EBI01_RECEIPT_INTEGRATION_O0_O2_IDENTITY=PASS'

# Existing receipt/mass transaction behavior must still compile and execute
# unchanged from the current-canonical source image. The EB-I01 modules are not
# linked into this replay.
for opt in 0 2; do
  OUT="$BUILD/fmr18-o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr18_accepted_commit_receipt.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "FMR18 preservation O$opt"; }
  grep -Fq 'FMR18_ACCEPTED_COMMIT_RECEIPT_TEST PASS' "$OUT/out.txt" || fail "FMR18 preservation marker O$opt"
done
cmp "$BUILD/fmr18-o0/out.txt" "$BUILD/fmr18-o2/out.txt" || fail "FMR18 preservation O0/O2 output mismatch"
echo 'EBI01_EXISTING_RECEIPT_MASS_TRANSACTION_REPLAY=PASS'

echo 'EBI01_ENERGY_CONSERVATION_LEDGER_GATE PASS'
