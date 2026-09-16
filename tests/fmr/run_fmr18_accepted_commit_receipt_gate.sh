#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr18-$$"
BASE="9f89d3dc9700378b80439e137ed64a95e5d575fa"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/fwo34-o0" "$BUILD/fwo34-o2"
trap 'rm -rf "$BUILD"' EXIT

fail() {
  echo "FMR18_GATE_FAIL $*" >&2
  exit 1
}

cd "$ROOT"

# F-MR18 may add exactly one generic production module at this gate. No
# existing kernel/runtime/solver/process/crop source is modified yet.
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/src-delta.txt"
printf '%s\n' 'src/runtime/mod_fmr_accepted_commit_receipt.f90' > "$BUILD/expected-src-delta.txt"
diff -u "$BUILD/expected-src-delta.txt" "$BUILD/src-delta.txt" || fail "unexpected production source delta"
echo 'FMR18_EXACT_ADDITIVE_SOURCE_DELTA=PASS'

RECEIPT_SRC="$ROOT/src/runtime/mod_fmr_accepted_commit_receipt.f90"
if grep -Eiq '^[[:space:]]*use[[:space:]].*(wofost|snow|irrig|crop|root_water_uptake)' "$RECEIPT_SRC"; then
  fail "domain-specific import found in generic receipt module"
fi
if grep -Eiq '^[[:space:]]*allocate[[:space:]]*\(' "$RECEIPT_SRC"; then
  fail "receipt module unexpectedly allocates memory"
fi
echo 'FMR18_GENERIC_NO_DOMAIN_IMPORTS=PASS'
echo 'FMR18_RECEIPT_MODULE_ALLOCATION_FREE=PASS'

COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr18_accepted_commit_receipt.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "F-MR18 O$opt executable"; }
  cat "$OUT/out.txt"
  for marker in \
    'FMR18_REAL_FKT_COMMIT_CREATES_EXACT_RECEIPT=PASS' \
    'FMR18_COMMIT_REJECTION_EMITS_NO_RECEIPT=PASS' \
    'FMR18_EXPECTED_RECEIPT_FAILURES_PRECEDE_PHYSICAL_COMMIT=PASS' \
    'FMR18_PREVALIDATION_REJECTION_IS_NONMUTATING_AND_REPLAYABLE=PASS' \
    'FMR18_ACCEPTED_COMMIT_RECEIPT_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing O$opt marker: $marker"
  done
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail "F-MR18 O0/O2 output mismatch"
echo 'FMR18_O0_O2_OUTPUT_IDENTITY=PASS'

# Directly replay the already-qualified F-WOF34 accepted-window oracle against
# the current composition tree. F-MR18 is additive and unused by this replay;
# the exact historical transcript must remain unchanged.
FWO_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/crop/mod_wofost_actual_biomass_state.f90
  src/crop/mod_wofost_crop_owner_state.f90
  src/crop/mod_wofost_one_day_structural_evolution.f90
  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
)
for opt in 0 2; do
  OUT="$BUILD/fwo34-o$opt"
  objects=()
  for src in "${FWO_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran -std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace \
      -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran -std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "F-WOF34 O$opt replay"; }
done
cmp "$BUILD/fwo34-o0/out.txt" "$BUILD/fwo34-o2/out.txt" || fail "F-WOF34 O0/O2 replay mismatch"
FWO_SHA="$(sha256sum "$BUILD/fwo34-o0/out.txt" | awk '{print $1}')"
[[ "$FWO_SHA" == "$EXPECTED_FWO34_OUTPUT_SHA" ]] || fail "F-WOF34 transcript changed: $FWO_SHA"
echo "FMR18_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS SHA256=$FWO_SHA"

echo 'FMR18_ACCEPTED_COMMIT_RECEIPT_GATE PASS'
