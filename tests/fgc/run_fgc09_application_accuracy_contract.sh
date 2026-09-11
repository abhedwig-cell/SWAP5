#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc09-$$"
UPSTREAM=96e39932c925c862f41d01a2a0f5c44c88cbaca7
CANONICAL=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
MODULE=src/runtime/mod_coupling_application_accuracy_contract.f90
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD"
cd "$ROOT"

fail(){ echo "FGC09_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$UPSTREAM" HEAD || fail 'branch is not descended from qualified F-GC08 closeout'
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'branch lost frozen canonical source ancestry'

changed_src="$(git diff --name-only "$UPSTREAM" HEAD -- src)"
[[ "$changed_src" == "$MODULE" ]] || fail "source allowlist violated: $changed_src"
[[ "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" == c06aa869a0bd479df4c7d6e1d0b4f5c07a207144 ]] || fail 'canonical contracts changed'
[[ "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" == 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4 ]] || fail 'transaction core changed'
echo 'FGC09_SOURCE_ALLOWLIST=PASS'
echo 'FGC09_CANONICAL_CONSUMER_CARRIER_UNCHANGED=PASS'

# The new seam is deliberately runtime-only. It must not acquire file I/O,
# solver/kernel ownership, mass tolerance, or a positive built-in accuracy policy.
if grep -Eiq '(^|[^[:alnum:]_])(open|read|write|close)[[:space:]]*\(' "$MODULE"; then
  fail 'runtime application contract contains file I/O'
fi
if grep -Eq 'use[[:space:]]+mod_(kernel|transaction|soil_water|reference_richards)' "$MODULE"; then
  fail 'runtime application contract depends on forbidden kernel/solver/transaction internals'
fi
grep -Fq 'logical :: h_app_available = .false.' "$MODULE" || fail 'H_app absence default changed'
grep -Fq 'real(real64) :: h_app_cm = 0.0_real64' "$MODULE" || fail 'H_app scalar default changed'
grep -Fq 'logical :: a_temporal_available = .false.' "$MODULE" || fail 'A_temporal absence default changed'
grep -Fq 'real(real64) :: a_temporal = 0.0_real64' "$MODULE" || fail 'A_temporal scalar default changed'
grep -Fq 'self%a_temporal <= 1.0_real64' "$MODULE" || fail 'temporal allocation upper-bound validation missing'
grep -Fq 'config%model_temporal_indicator_budget_available = .false.' "$MODULE" || fail 'stale budget clearing missing'
grep -Fq 'config%model_temporal_indicator_budget = 0.0_real64' "$MODULE" || fail 'stale budget value clearing missing'
echo 'FGC09_NO_IO_OR_HIDDEN_DEFAULT_POLICY=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

build(){
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$MODULE" -o "$out/application_contract.o"
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c tests/fgc/test_fgc09_application_accuracy_contract.f90 -o "$out/test.o"
  gfortran "$opt" "$out/transaction.o" "$out/contracts.o" "$out/application_contract.o" "$out/test.o" -o "$out/fgc09"
}

build -O0 o0
build -O2 o2
"$BUILD/o0/fgc09" > "$BUILD/o0.txt"
"$BUILD/o2/fgc09" > "$BUILD/o2.txt"
cmp "$BUILD/o0.txt" "$BUILD/o2.txt" || { diff -u "$BUILD/o0.txt" "$BUILD/o2.txt" >&2 || true; fail 'O0/O2 output drift'; }
cat "$BUILD/o2.txt"
echo 'FGC09_O0_O2_IDENTITY=PASS'
echo 'FGC09_APPLICATION_ACCURACY_CONTRACT_GATE PASS'
