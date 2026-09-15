#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci68-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
ORCH=src/runtime/mod_fmr_checkpoint_orchestrator.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
TEST=tests/fci/test_fci68_rossfast_d3r_kernel_selector_routing.f90

# F-CI68 composes the already admitted F-CI66 selector and F-CI67 RossFast
# policy through the generic kernel/checkpoint path. Their scientific/numerical
# authorities remain immutable in this workunit.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$RUNTIME)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

grep -Fq 'canonical_subinterval_target_selector' "$KERNEL"
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' "$KERNEL"
grep -Fq 'run_canonical_interval(self%model, working, forcing, interval, numerical_config, runtime_result, target_selector)' "$KERNEL"
grep -Fq 'canonical_subinterval_target_selector' "$ORCH"
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' "$ORCH"
grep -Fq 'diagnostics, checkpoint, target_selector)' "$ORCH"

# Generic F-KT/FMR plumbing must not acquire RossFast-specific policy.
if grep -Eqi 'rossfast' "$KERNEL" "$ORCH"; then
  echo 'FCI68_GENERIC_LAYER_CONTAINS_ROSSFAST_SPECIFIC_POLICY' >&2
  exit 68
fi

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/$opt"

  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TX" -o "$moddir/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONTRACTS" -o "$moddir/contracts.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$RUNTIME" -o "$moddir/runtime.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$KERNEL" -o "$moddir/kernel.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$ORCH" -o "$moddir/orchestrator.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$POLICY" -o "$moddir/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/runtime.o" "$moddir/kernel.o" \
    "$moddir/orchestrator.o" "$moddir/policy.o" "$moddir/test.o" -o "$moddir/test"
  "$moddir/test" > "$moddir/output.txt"
  grep -Fq 'FCI68_ROSSFAST_D3R_KERNEL_SELECTOR_ROUTING PASS' "$moddir/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo "FCI68_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FCI68_ROSSFAST_D3R_KERNEL_SELECTOR_ROUTING=PASS'
