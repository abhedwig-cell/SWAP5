#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "EB_I20_GATE_FAIL $*" >&2; exit 220; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
I01_TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
I01_LEDGER_BLOB="aba5a63a10d7f37cb89e31882851d0f4e9b99ffa"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"

git fetch -q origin integration/f-ci-canonical
LIVE="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'workunit is not rooted in exact current canonical'
echo 'EB_I20_CURRENT_CANONICAL_LOCK=PASS'

changed_src="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
expected_src=$'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf 'unexpected source delta:\n%s\n' "$changed_src" >&2; fail 'production source scope'; }
[[ -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" ]] || fail 'reference source changed'
[[ "$(git rev-parse "HEAD:$TYPES")" == "$I01_TYPES_BLOB" ]] || fail 'EB-I01 energy types blob drift'
[[ "$(git rev-parse "HEAD:$LEDGER")" == "$I01_LEDGER_BLOB" ]] || fail 'EB-I01 ledger blob drift'
echo 'EB_I20_EXACT_IMMUTABLE_I01_SOURCE_RECOMPOSITION=PASS'

for src in "$TYPES" "$LEDGER"; do
  if grep -Eiq '^[[:space:]]*use[[:space:]].*(groundwater_interface_mass_ledger|groundwater_coupling)' "$src"; then
    fail "energy accounting depends on groundwater-specific mass authority: $src"
  fi
  if grep -Eiq '^[[:space:]]*(open|read|write|close)[[:space:]]*\(' "$src"; then
    fail "I/O primitive found in energy accounting source: $src"
  fi
done
echo 'EB_I20_KERNEL_RUNTIME_IO_AND_COUPLING_SEPARATION=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASELINE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/types-o$opt"; mkdir -p "$OUT"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TYPES" -o "$OUT/types.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/eb/test_ebi01_energy_conservation_types.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/types.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "energy types O$opt"; }
  for marker in \
    'EBI01_INTERNAL_TRANSFER_CANCELS_IN_OUTER_CV=PASS' \
    'EBI01_NESTED_CONTROL_VOLUMES_CLOSE=PASS' \
    'EBI01_UNDECLARED_TRANSFER_ENDPOINT_REJECTED=PASS' \
    'EBI01_INVALID_ACCOUNTING_INPUT_REJECTED=PASS' \
    'EBI01_ENERGY_CONSERVATION_TYPES_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing energy types marker O$opt: $marker"
  done
done
cmp "$BUILD/types-o0/out.txt" "$BUILD/types-o2/out.txt" || fail 'energy types O0/O2 mismatch'
echo 'EB_I20_ENERGY_TYPES_O0_O2_IDENTITY=PASS'

for opt in 0 2; do
  OUT="$BUILD/receipt-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${BASELINE[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/eb/test_ebi01_energy_ledger_receipt_integration.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "receipt integration O$opt"; }
  for marker in \
    'EBI01_UNREGISTERED_INTERNAL_COMPONENT_REJECTED=PASS' \
    'EBI01_REAL_FKT_RECEIPT_PUBLISHES_ENERGY_ONCE=PASS' \
    'EBI01_ROLLBACK_PUBLISHES_NO_ENERGY=PASS' \
    'EBI01_ROLLBACK_REPLAY_FROM_SAME_COMMITTED_ORIGIN=PASS' \
    'EBI01_EXISTING_FKT_MASS_PATH_PRESERVED=PASS' \
    'EBI01_ENERGY_LEDGER_RECEIPT_INTEGRATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing receipt marker O$opt: $marker"
  done
done
cmp "$BUILD/receipt-o0/out.txt" "$BUILD/receipt-o2/out.txt" || fail 'receipt integration O0/O2 mismatch'
echo 'EB_I20_TRANSACTIONAL_RECEIPT_O0_O2_IDENTITY=PASS'

# Preserve the current accepted-commit receipt semantics without linking the
# recomposed energy ledger itself.
for opt in 0 2; do
  OUT="$BUILD/fmr18-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${BASELINE[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr18_accepted_commit_receipt.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "FMR18 preservation O$opt"; }
  grep -Fq 'FMR18_ACCEPTED_COMMIT_RECEIPT_TEST PASS' "$OUT/out.txt" || fail "FMR18 marker O$opt"
done
cmp "$BUILD/fmr18-o0/out.txt" "$BUILD/fmr18-o2/out.txt" || fail 'FMR18 preservation O0/O2 mismatch'
echo 'EB_I20_CURRENT_TRANSACTION_RECEIPT_PRESERVATION=PASS'

# Characterize, do not silently alter, current architectural debt in the old
# ledger. Error-stop call sites are reported for the follow-up admission review.
ERROR_STOP_COUNT="$(grep -Ec '^[[:space:]]*error stop' "$LEDGER" || true)"
echo "EB_I20_LEDGER_ERROR_STOP_COUNT=$ERROR_STOP_COUNT"

git diff --check "$CANONICAL..HEAD"
echo "EB_I20_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'EB_I20_CURRENT_CANONICAL_REQUALIFICATION=PASS'
