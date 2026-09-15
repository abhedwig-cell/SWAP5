#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross05-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
KERNEL_TX=src/kernel/mod_kernel_transactions.f90
ORCH=src/runtime/mod_fmr_checkpoint_orchestrator.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
TABLE_KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
ADAPTER=src/runtime/mod_rossfast_d3r_kernel_model_adapter.f90
TEST=tests/ross/test_ross05_d3r_transactional_selector_composition.f90
ASSET_ROOT=assets/rossfast/d3r

# Immutable authorities inherited by F-ROSS05.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$RUNTIME)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:$KERNEL_TX)" = d3a53385e3707f05e5396bbd6f218633b9803f65
test "$(git rev-parse HEAD:$ORCH)" = 0dceaa2d108d5c7e1263e0f424a056a8df585908
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
test "$(git rev-parse HEAD:$BINDING)" = 9f29ba7a08844692ba2628c7869d23713409f92b
test "$(git rev-parse HEAD:$TABLE_KERNEL)" = 034136c193b287bcf9a953a9b89df2a8fb0c97cc
test "$(git rev-parse HEAD:$PROVIDER)" = afc05eb3001d91f66ca542978c3c6795283a7ac0
test "$(git rev-parse HEAD:$ADAPTER)" = dabd5da97e7a4d5990cb5a0f07928aa9f03a6c1e

test "$(git rev-parse HEAD:integration/f-ci/F-CI68_STATUS.json)" = 4661b9c53101c04718a18709a4652b36e45c7f18
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS03_STATUS.json)" = 6733b7a5ddd4b9761c9bdad26a5c7e21c8e92c7c
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS04_STATUS.json)" = e4ae23777d3f329822bf74051f4b139c04a59877
test "$(git rev-parse HEAD:$ASSET_ROOT/manifest.json)" = 1266d15149af5feb8d7fb0a5ef90d41b5881fd55

grep -Fq 'QUALIFIED_ROSSFAST_D3R_TABLE_ASSET_REGISTRY' "$ASSET_ROOT/manifest.json"
grep -Fq 'runtime_generation": false' "$ASSET_ROOT/manifest.json"
grep -Fq 'ROSSFAST_D3R_COMPOSED_INTERNAL_SUBSTEPS = 8' "$ADAPTER"
grep -Fq 'parameters%equal_internal_substeps /= ROSSFAST_D3R_COMPOSED_INTERNAL_SUBSTEPS' "$ADAPTER"
for material in B01 B12 O01 O05 O14 O18; do
  test -f "$ASSET_ROOT/${material}_log_mobility_f32.hex"
done

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/$opt"

  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TX" -o "$moddir/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONTRACTS" -o "$moddir/contracts.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$RUNTIME" -o "$moddir/runtime.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$KERNEL_TX" -o "$moddir/kernel_tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$ORCH" -o "$moddir/orch.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$POLICY" -o "$moddir/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$BINDING" -o "$moddir/binding.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TABLE_KERNEL" -o "$moddir/table_kernel.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$PROVIDER" -o "$moddir/provider.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$ADAPTER" -o "$moddir/adapter.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/runtime.o" \
    "$moddir/kernel_tx.o" "$moddir/orch.o" "$moddir/policy.o" "$moddir/binding.o" \
    "$moddir/table_kernel.o" "$moddir/provider.o" "$moddir/adapter.o" "$moddir/test.o" \
    -o "$moddir/test"

  "$moddir/test" "$ASSET_ROOT" > "$moddir/output.txt"
  grep -Fq 'ROSS05_D3R_TRANSACTIONAL_SELECTOR_COMPOSITION PASS' "$moddir/output.txt"
  for material in B01 B12 O01 O05 O14 O18; do
    grep -Fq "ROSS05_MATERIAL $material PRODUCTION_AND_CHAIN_PASS" "$moddir/output.txt"
  done
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS05_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'ROSS05_D3R_TRANSACTIONAL_SELECTOR_COMPOSITION=PASS'
