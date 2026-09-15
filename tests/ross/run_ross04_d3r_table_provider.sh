#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 MATERIAL FIXTURE.txt" >&2
  exit 64
fi
MATERIAL=$1
FIXTURE=$2

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross04-${MATERIAL}-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
TEST=tests/ross/test_ross04_d3r_table_provider.f90
ASSET_ROOT=assets/rossfast/d3r

# F-ROSS04 is strictly additive above the qualified F-ROSS03 candidate.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
test "$(git rev-parse HEAD:$BINDING)" = 9f29ba7a08844692ba2628c7869d23713409f92b

test -f "$ASSET_ROOT/${MATERIAL}_log_mobility_f32.hex"
test -f "$ASSET_ROOT/manifest.json"
grep -Fq 'runtime_generation": false' "$ASSET_ROOT/manifest.json"
grep -Fq 'QUALIFIED_ROSSFAST_D3R_TABLE_ASSET_REGISTRY' "$ASSET_ROOT/manifest.json"
grep -Fq "case('B01','B12','O01','O05','O14','O18')" "$PROVIDER"
grep -Fq "status='delete'" "$TEST"

case "$MATERIAL" in
  B01) OTHER=B12 ;;
  B12) OTHER=B01 ;;
  O01) OTHER=O05 ;;
  O05) OTHER=O01 ;;
  O14) OTHER=O18 ;;
  O18) OTHER=O14 ;;
  *) echo "unsupported material: $MATERIAL" >&2; exit 65 ;;
esac

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/$opt"
  positive="$moddir/assets"
  mismatch="$moddir/mismatch"
  mkdir -p "$positive" "$mismatch"
  cp "$ASSET_ROOT/${MATERIAL}_log_mobility_f32.hex" "$positive/${MATERIAL}_log_mobility_f32.hex"
  cp "$ASSET_ROOT/${OTHER}_log_mobility_f32.hex" "$mismatch/${MATERIAL}_log_mobility_f32.hex"

  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TX" -o "$moddir/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONTRACTS" -o "$moddir/contracts.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$POLICY" -o "$moddir/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$BINDING" -o "$moddir/binding.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$KERNEL" -o "$moddir/kernel.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$PROVIDER" -o "$moddir/provider.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/policy.o" "$moddir/binding.o" \
    "$moddir/kernel.o" "$moddir/provider.o" "$moddir/test.o" -o "$moddir/test"

  "$moddir/test" "$MATERIAL" "$positive" "$FIXTURE" "$mismatch" > "$moddir/output.txt"
  grep -Fq 'ROSS04_TABLE_PROVIDER_GATE PASS' "$moddir/output.txt"
  test ! -e "$positive/${MATERIAL}_log_mobility_f32.hex"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS04_${MATERIAL}_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "ROSS04_${MATERIAL}_TABLE_PROVIDER=PASS"
