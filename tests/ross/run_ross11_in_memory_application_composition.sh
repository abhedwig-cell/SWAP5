#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross11-${GITHUB_RUN_ID:-local}-$$"
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
KERNEL_ADAPTER=src/runtime/mod_rossfast_d3r_kernel_model_adapter.f90
SERIAL_BACKEND=src/runtime/mod_fmr_serialized_kernel_backend.f90
DISPATCH=src/runtime/mod_fmr_rossfast_registry_dispatch.f90
SELECTION=src/runtime/mod_fmr_rossfast_application_selection.f90
CONFIG=src/runtime/mod_fmr_rossfast_application_config.f90
FILE_ADAPTER=src/adapter/mod_rossfast_application_config_file_adapter.f90
APP_RUNTIME=src/runtime/mod_fmr_rossfast_application_runtime.f90
TEST=tests/ross/test_ross11_in_memory_application_composition.f90
ASSET_ROOT=assets/rossfast/d3r
FCI80_STATUS=integration/f-ci/F-CI80_STATUS.json
FROSS10_STATUS=integration/f-ross/F-ROSS10_STATUS.json
LEGACY_SOILWATER=src/legacy/b1_10_port/soilwater.f90
LEGACY_MAIN=src/legacy/b1_10_port/swap_main.f90
FULL_RICHARDS=src/adapter/mod_b110_production_soil_water_task2.f90
CONFIG_FILE="$BUILD/rossfast-model.conf"
printf '%s\n' 'SOIL_WATER_MODEL=ROSSFAST_D3R' > "$CONFIG_FILE"

# Exact current-canonical qualified dependencies. F-ROSS11 is composition only.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$RUNTIME)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:$KERNEL_TX)" = d3a53385e3707f05e5396bbd6f218633b9803f65
test "$(git rev-parse HEAD:$ORCH)" = 0dceaa2d108d5c7e1263e0f424a056a8df585908
test "$(git rev-parse HEAD:$FMR_CORE)" = 43eef1979e0202f8ecc92f73eb7d8025dab515a4
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
test "$(git rev-parse HEAD:$BINDING)" = 9f29ba7a08844692ba2628c7869d23713409f92b
test "$(git rev-parse HEAD:$TABLE_KERNEL)" = 034136c193b287bcf9a953a9b89df2a8fb0c97cc
test "$(git rev-parse HEAD:$PROVIDER)" = afc05eb3001d91f66ca542978c3c6795283a7ac0
test "$(git rev-parse HEAD:$KERNEL_ADAPTER)" = dabd5da97e7a4d5990cb5a0f07928aa9f03a6c1e
test "$(git rev-parse HEAD:$SERIAL_BACKEND)" = 29093b517bc6fdd40f32325018729c4c3dee6e85
test "$(git rev-parse HEAD:$DISPATCH)" = 7f900e75f4bea1c9b999464b7a8d4f7be4b35064
test "$(git rev-parse HEAD:$SELECTION)" = 5b652f04f172a8faa468d38faa23883ce6f35294
test "$(git rev-parse HEAD:$CONFIG)" = 5892d5b2573c678ab8d121ae80353870b66886d2
test "$(git rev-parse HEAD:$FILE_ADAPTER)" = 55dc1632eb4d72d52cc2e038765710801bee5dd2
test "$(git rev-parse HEAD:$ASSET_ROOT/manifest.json)" = 1266d15149af5feb8d7fb0a5ef90d41b5881fd55
test "$(git rev-parse HEAD:$ASSET_ROOT/B01_log_mobility_f32.hex)" = c4cced37b0a6ba284f43dbf8c78cd5ac7ebe8d4e
test "$(git rev-parse HEAD:$ASSET_ROOT/B12_log_mobility_f32.hex)" = bda7bb0339289fc21671964676cb7d2bd8eccc89
test "$(git rev-parse HEAD:$ASSET_ROOT/O01_log_mobility_f32.hex)" = 831b29f7c1d04546906c928a15becc20c7328f30
test "$(git rev-parse HEAD:$ASSET_ROOT/O05_log_mobility_f32.hex)" = 39ddd5f390857d722cc80c4878f90b4f2a4e5908
test "$(git rev-parse HEAD:$ASSET_ROOT/O14_log_mobility_f32.hex)" = 9746cb348093b735bc10a7cb8f3d5a67a57018bf
test "$(git rev-parse HEAD:$ASSET_ROOT/O18_log_mobility_f32.hex)" = 68855f4d34d63b7d14743305d2519038d946ed67
test "$(git rev-parse HEAD:$FCI80_STATUS)" = 87660f85b51eb10345ce54f9c033505986aad1b2
test "$(git rev-parse HEAD:$FROSS10_STATUS)" = ec398adbaae6948fdf6323c55e476f5f080f20d1

# Explicit exclusions: no legacy, SW_SOLVE, Full-Richards or reference-runtime wiring.
test "$(git rev-parse HEAD:$LEGACY_SOILWATER)" = 2ab6ea917525cd6f2560860bd55aec1da16be014
test "$(git rev-parse HEAD:$LEGACY_MAIN)" = b6609df617c6b5875c62324570fb8c7d8c0bfe21
test "$(git rev-parse HEAD:$FULL_RICHARDS)" = 5f51a34b03b63cf7cdf254f6115c2bb2db4ea693
if grep -Eiq 'swap_main|swsolve|MOD_SoilWater|mod_rossfast_application_config_file_adapter|mod_fmr_serialized_reference_backend|mod_fmr_serialized_multiswap_runtime|open\s*\(|read\s*\(' "$APP_RUNTIME"; then
  echo 'ROSS11_APPLICATION_RUNTIME_CROSSES_EXCLUDED_BOUNDARY' >&2
  exit 111
fi
grep -Fq 'fmr_bind_rossfast_application_config' "$APP_RUNTIME"
grep -Fq 'dispatcher%execute_batch' "$APP_RUNTIME"
grep -Fq 'FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED' "$APP_RUNTIME"

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
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$KERNEL_ADAPTER" -o "$moddir/kernel_adapter.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SERIAL_BACKEND" -o "$moddir/serial_backend.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$DISPATCH" -o "$moddir/dispatch.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SELECTION" -o "$moddir/selection.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONFIG" -o "$moddir/config.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$FILE_ADAPTER" -o "$moddir/file_adapter.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$APP_RUNTIME" -o "$moddir/app_runtime.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"

  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/runtime.o" \
    "$moddir/kernel_tx.o" "$moddir/orch.o" "$moddir/fmr_core.o" "$moddir/policy.o" \
    "$moddir/binding.o" "$moddir/table_kernel.o" "$moddir/provider.o" "$moddir/kernel_adapter.o" \
    "$moddir/serial_backend.o" "$moddir/dispatch.o" "$moddir/selection.o" "$moddir/config.o" \
    "$moddir/file_adapter.o" "$moddir/app_runtime.o" "$moddir/test.o" -o "$moddir/test"

  "$moddir/test" "$ASSET_ROOT" "$CONFIG_FILE" > "$moddir/output.txt"
  grep -Fq 'ROSS11_IN_MEMORY_APPLICATION_COMPOSITION PASS' "$moddir/output.txt"
  grep -Fq 'ROSS11_FILE_ADAPTER_TO_TYPED_RUNTIME PASS' "$moddir/output.txt"
  for material in B01 B12 O01 O05 O14 O18; do
    grep -Fq "ROSS11_MATERIAL $material" "$moddir/output.txt"
  done
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS11_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'ROSS11_IN_MEMORY_APPLICATION_COMPOSITION=PASS'
