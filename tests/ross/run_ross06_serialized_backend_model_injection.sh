#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
KERNEL_TX=src/kernel/mod_kernel_transactions.f90
ORCH=src/runtime/mod_fmr_checkpoint_orchestrator.f90
FMR_CORE=src/runtime/mod_fmr_runtime_core.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
TABLE_KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
ADAPTER=src/runtime/mod_rossfast_d3r_kernel_model_adapter.f90
SERIAL_BACKEND=src/runtime/mod_fmr_serialized_kernel_backend.f90
TEST=tests/ross/test_ross06_serialized_backend_model_injection.f90
ASSET_ROOT=assets/rossfast/d3r

# Immutable qualified dependencies inherited from the green F-ROSS05 stack.
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
test "$(git rev-parse HEAD:$ASSET_ROOT/manifest.json)" = 1266d15149af5feb8d7fb0a5ef90d41b5881fd55

grep -Fq 'FMR_BACKEND_SERIALIZED_INJECTED_KERNEL = 4' "$SERIAL_BACKEND"
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' "$SERIAL_BACKEND"
grep -Fq 'call fmr_capture_checkpoint' "$SERIAL_BACKEND"
grep -Fq 'call fmr_commit_candidate' "$SERIAL_BACKEND"
if grep -Eqi 'rossfast' "$SERIAL_BACKEND"; then
  echo 'ROSS06_GENERIC_SERIALIZED_BACKEND_CONTAINS_ROSSFAST_POLICY' >&2
  exit 106
fi
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
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$FMR_CORE" -o "$moddir/fmr_core.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$POLICY" -o "$moddir/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$BINDING" -o "$moddir/binding.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TABLE_KERNEL" -o "$moddir/table_kernel.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$PROVIDER" -o "$moddir/provider.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$ADAPTER" -o "$moddir/adapter.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SERIAL_BACKEND" -o "$moddir/serial_backend.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/runtime.o" \
    "$moddir/kernel_tx.o" "$moddir/orch.o" "$moddir/fmr_core.o" "$moddir/policy.o" \
    "$moddir/binding.o" "$moddir/table_kernel.o" "$moddir/provider.o" "$moddir/adapter.o" \
    "$moddir/serial_backend.o" "$moddir/test.o" -o "$moddir/test"

  "$moddir/test" "$ASSET_ROOT" > "$moddir/output.txt"
  grep -Fq 'ROSS06_SERIALIZED_BACKEND_MODEL_INJECTION PASS' "$moddir/output.txt"
  for material in B01 B12 O01 O05 O14 O18; do
    grep -Fq "ROSS06_MATERIAL $material SERIALIZED_PRODUCTION_AND_CHAIN_PASS" "$moddir/output.txt"
  done
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS06_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'ROSS06_SERIALIZED_BACKEND_MODEL_INJECTION=PASS'
