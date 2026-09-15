#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci81-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PREIMAGE=4a01641ffed8a2260260909825c3887db2dff1ac
OWNER_HEAD=acd0e6ddfb144f553dc396a909c24f8785099b56
OWNER_QUALIFIED_HEAD=a799f5437e28794fbf9bf2ef811f9944805ce22f
LIVE_CANON="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
test "$LIVE_CANON" = "$PREIMAGE"
git merge-base --is-ancestor "$PREIMAGE" HEAD

STEP_DIRECTION=src/solver/mod_soil_water_accepted_step_direction_contract.f90
TRAJECTORY_DIRECTION=src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
TRAJECTORY_PUBLICATION=src/transaction/mod_accepted_trajectory_directional_publication.f90
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
APP_RUNTIME=src/runtime/mod_fmr_rossfast_application_runtime.f90
TEST=tests/integration/test_fci81_rossfast_application_composition.f90
ASSET_ROOT=assets/rossfast/d3r
FROSS11_STATUS=integration/f-ross/F-ROSS11_STATUS.json
FCI80_STATUS=integration/f-ci/F-CI80_STATUS.json
REFERENCE_BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
REFERENCE_RUNTIME=src/runtime/mod_fmr_serialized_multiswap_runtime.f90
LEGACY_SOILWATER=src/legacy/b1_10_port/soilwater.f90
LEGACY_MAIN=src/legacy/b1_10_port/swap_main.f90
FULL_RICHARDS=src/adapter/mod_b110_production_soil_water_task2.f90

# Current-canonical inherited authorities must remain exact after F-KT22.
test "$(git rev-parse HEAD:$STEP_DIRECTION)" = 52698b1ad2350bf787862a053a49c7c73c3358f0
test "$(git rev-parse HEAD:$TRAJECTORY_DIRECTION)" = 95381d3124b185aa0fbafd1ea3da6179a841deda
test "$(git rev-parse HEAD:$TRAJECTORY_PUBLICATION)" = 31bc721f333a77c52f6530b357af44c627f44629
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3962c270a7579b7403764674302445fe15ef5f72
test "$(git rev-parse HEAD:$RUNTIME)" = 0b50dda5caf3b73a82561d7b0ba1e92386a08fee
test "$(git rev-parse HEAD:$KERNEL_TX)" = e4db4ede8162c8be877c8cad9f1babd57ba451b6
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

# Exact owner-qualified F-ROSS11 projection and provenance.
test "$(git rev-parse HEAD:$APP_RUNTIME)" = a1af0d6eb0041565602711251748666f7b959d8e
test "$(git rev-parse HEAD:$FROSS11_STATUS)" = 9a532b643faaef71e43c0eee58e4be7f9c661328
grep -Fq '"qualified_head": "a799f5437e28794fbf9bf2ef811f9944805ce22f"' "$FROSS11_STATUS"
grep -Fq '"conclusion": "success"' "$FROSS11_STATUS"

# Exact immutable RossFast assets and current F-CI80 governance postimage.
test "$(git rev-parse HEAD:$ASSET_ROOT/manifest.json)" = 1266d15149af5feb8d7fb0a5ef90d41b5881fd55
test "$(git rev-parse HEAD:$ASSET_ROOT/B01_log_mobility_f32.hex)" = c4cced37b0a6ba284f43dbf8c78cd5ac7ebe8d4e
test "$(git rev-parse HEAD:$ASSET_ROOT/B12_log_mobility_f32.hex)" = bda7bb0339289fc21671964676cb7d2bd8eccc89
test "$(git rev-parse HEAD:$ASSET_ROOT/O01_log_mobility_f32.hex)" = 831b29f7c1d04546906c928a15becc20c7328f30
test "$(git rev-parse HEAD:$ASSET_ROOT/O05_log_mobility_f32.hex)" = 39ddd5f390857d722cc80c4878f90b4f2a4e5908
test "$(git rev-parse HEAD:$ASSET_ROOT/O14_log_mobility_f32.hex)" = 9746cb348093b735bc10a7cb8f3d5a67a57018bf
test "$(git rev-parse HEAD:$ASSET_ROOT/O18_log_mobility_f32.hex)" = 68855f4d34d63b7d14743305d2519038d946ed67
test "$(git rev-parse HEAD:$FCI80_STATUS)" = 78ea09f1715c20ed3266557fd4157ff19ba96eed

# Reference/legacy production routes are current-canonical preservation locks.
test "$(git rev-parse HEAD:$REFERENCE_BACKEND)" = 9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13
test "$(git rev-parse HEAD:$REFERENCE_RUNTIME)" = 1aa2454048d0e480becaee34f596f20f1a7bd66e
test "$(git rev-parse HEAD:$LEGACY_SOILWATER)" = 2ab6ea917525cd6f2560860bd55aec1da16be014
test "$(git rev-parse HEAD:$LEGACY_MAIN)" = b6609df617c6b5875c62324570fb8c7d8c0bfe21
test "$(git rev-parse HEAD:$FULL_RICHARDS)" = 5f51a34b03b63cf7cdf254f6115c2bb2db4ea693

# F-ROSS11 must remain an in-memory composition seam, not a new I/O, legacy,
# reference-backend or generic Public API owner.
if grep -Eiq 'swap_main|swsolve|MOD_SoilWater|mod_rossfast_application_config_file_adapter|mod_fmr_serialized_reference_backend|mod_fmr_serialized_multiswap_runtime|open\s*\(|read\s*\(' "$APP_RUNTIME"; then
  echo 'FCI81_APPLICATION_RUNTIME_CROSSES_EXCLUDED_BOUNDARY' >&2
  exit 181
fi
grep -Fq 'fmr_bind_rossfast_application_config' "$APP_RUNTIME"
grep -Fq 'dispatcher%execute_batch' "$APP_RUNTIME"
grep -Fq 'FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED' "$APP_RUNTIME"

# Candidate surface is bounded to the exact F-ROSS11 source/provenance plus
# independent F-CI81 qualification/governance evidence.
allowed_re='^(src/runtime/mod_fmr_rossfast_application_runtime\.f90|integration/f-ross/F-ROSS11_STATUS\.json|tests/integration/test_fci81_rossfast_application_composition\.f90|tests/integration/run_fci81_rossfast_application_composition_admission\.sh|\.github/workflows/f-ci81-rossfast-application-composition-admission\.yml|integration/f-ci/F-CI81_STATUS\.json)$'
while IFS= read -r path; do
  [[ "$path" =~ $allowed_re ]] || { echo "FCI81_UNEXPECTED_PATH $path" >&2; exit 182; }
done < <(git diff --name-only "$PREIMAGE..HEAD")

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp -ffree-line-length-none)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/$opt"

  # F-KT22 introduced a publication type into canonical contracts. Compile the
  # exact admitted dependency chain first; this changes qualification build
  # order only and does not alter any production source or semantics.
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$STEP_DIRECTION" -o "$moddir/step_direction.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TRAJECTORY_DIRECTION" -o "$moddir/trajectory_direction.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TRAJECTORY_PUBLICATION" -o "$moddir/trajectory_publication.o"
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
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$APP_RUNTIME" -o "$moddir/app_runtime.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"

  gfortran -fopenmp "$moddir/step_direction.o" "$moddir/trajectory_direction.o" "$moddir/trajectory_publication.o" \
    "$moddir/tx.o" "$moddir/contracts.o" "$moddir/runtime.o" "$moddir/kernel_tx.o" "$moddir/orch.o" \
    "$moddir/fmr_core.o" "$moddir/policy.o" "$moddir/binding.o" "$moddir/table_kernel.o" \
    "$moddir/provider.o" "$moddir/kernel_adapter.o" "$moddir/serial_backend.o" "$moddir/dispatch.o" \
    "$moddir/selection.o" "$moddir/config.o" "$moddir/app_runtime.o" "$moddir/test.o" -o "$moddir/test"

  "$moddir/test" "$ASSET_ROOT" > "$moddir/output.txt"
  grep -Fq 'FCI81_INDEPENDENT_ROSSFAST_APPLICATION_COMPOSITION PASS' "$moddir/output.txt"
  grep -Fq 'FCI81_REFERENCE_REJECT PASS' "$moddir/output.txt"
  grep -Fq 'FCI81_MISSING_ASSET_PREFLIGHT PASS' "$moddir/output.txt"
  for material in B01 B12 O01 O05 O14 O18; do
    grep -Fq "FCI81_EQUIV $material" "$moddir/output.txt"
  done
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "FCI81_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "FCI81_OWNER_HEAD=$OWNER_HEAD"
echo "FCI81_OWNER_QUALIFIED_HEAD=$OWNER_QUALIFIED_HEAD"
echo 'FCI81_ROSSFAST_APPLICATION_COMPOSITION_ADMISSION=PASS'
