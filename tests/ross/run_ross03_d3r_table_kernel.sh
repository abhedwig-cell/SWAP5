#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 MATERIAL TABLE.txt FIXTURE.txt" >&2
  exit 64
fi
MATERIAL=$1
TABLE=$2
FIXTURE=$3

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross03-${MATERIAL}-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
TEST=tests/ross/test_ross03_d3r_table_kernel.f90

# F-ROSS03 is stacked exactly on the qualified F-ROSS02 binding candidate.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
test "$(git rev-parse HEAD:$BINDING)" = 9f29ba7a08844692ba2628c7869d23713409f92b

grep -Fq 'ROSSFAST_D3R_TABLE_N = 241' "$KERNEL"
grep -Fq 'real(real32), allocatable :: log_mobility(:,:)' "$KERNEL"
grep -Fq 'CERTIFICATE_INTERNAL_SUBSTEPS = 8' "$KERNEL"
grep -Fq 'candidate_route' tests/ross/generate_ross03_oracle_fixture.py || true
grep -Fq 'raw_estimator = maxval(abs(refined%water_content - coarse%water_content)) / span' "$KERNEL"
grep -Fq 'bound = max(raw_estimator, ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR)' "$KERNEL"

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/$opt"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TX" -o "$moddir/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONTRACTS" -o "$moddir/contracts.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$POLICY" -o "$moddir/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$BINDING" -o "$moddir/binding.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$KERNEL" -o "$moddir/kernel.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/policy.o" "$moddir/binding.o" \
    "$moddir/kernel.o" "$moddir/test.o" -o "$moddir/test"
  "$moddir/test" "$MATERIAL" "$TABLE" "$FIXTURE" > "$moddir/output.txt"
  grep -Fq 'ROSS03_D3R_TABLE_KERNEL_GATE PASS' "$moddir/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS03_${MATERIAL}_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "ROSS03_${MATERIAL}_D3R_TABLE_KERNEL=PASS"
