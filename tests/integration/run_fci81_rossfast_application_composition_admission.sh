#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci81-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PREIMAGE=aa25126ee19e25c60bd266951b7494ba635efeca
OWNER_HEAD=acd0e6ddfb144f553dc396a909c24f8785099b56
OWNER_QUALIFIED_HEAD=a799f5437e28794fbf9bf2ef811f9944805ce22f
LIVE_CANON="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
test "$LIVE_CANON" = "$PREIMAGE"
git merge-base --is-ancestor "$PREIMAGE" HEAD

lock() { test "$(git rev-parse "HEAD:$1")" = "$2"; }

# F-KT22 dependency chain now required by canonical contracts.
lock src/solver/mod_soil_water_accepted_step_direction_contract.f90 52698b1ad2350bf787862a053a49c7c73c3358f0
lock src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 95381d3124b185aa0fbafd1ea3da6179a841deda
lock src/transaction/mod_accepted_trajectory_directional_publication.f90 31bc721f333a77c52f6530b357af44c627f44629

# Current-canonical transaction/runtime authorities.
lock src/transaction/mod_transaction_reference.f90 d5a71a526efaebd82054580c3186f8e3545db331
lock src/runtime/mod_canonical_contracts.f90 3962c270a7579b7403764674302445fe15ef5f72
lock src/runtime/mod_canonical_interval_runtime.f90 0b50dda5caf3b73a82561d7b0ba1e92386a08fee
lock src/kernel/mod_kernel_transactions.f90 e4db4ede8162c8be877c8cad9f1babd57ba451b6
lock src/runtime/mod_fmr_checkpoint_orchestrator.f90 0dceaa2d108d5c7e1263e0f424a056a8df585908
lock src/runtime/mod_fmr_runtime_core.f90 43eef1979e0202f8ecc92f73eb7d8025dab515a4
lock src/runtime/mod_rossfast_d3r_execution_policy.f90 a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

# Canonically admitted restricted RossFast stack.
lock src/runtime/mod_rossfast_d3r_model_binding.f90 9f29ba7a08844692ba2628c7869d23713409f92b
lock src/solver/mod_rossfast_d3r_table_kernel.f90 034136c193b287bcf9a953a9b89df2a8fb0c97cc
lock src/solver/mod_rossfast_d3r_table_provider.f90 afc05eb3001d91f66ca542978c3c6795283a7ac0
lock src/runtime/mod_rossfast_d3r_kernel_model_adapter.f90 dabd5da97e7a4d5990cb5a0f07928aa9f03a6c1e
lock src/runtime/mod_fmr_serialized_kernel_backend.f90 29093b517bc6fdd40f32325018729c4c3dee6e85
lock src/runtime/mod_fmr_rossfast_registry_dispatch.f90 7f900e75f4bea1c9b999464b7a8d4f7be4b35064
lock src/runtime/mod_fmr_rossfast_application_selection.f90 5b652f04f172a8faa468d38faa23883ce6f35294
lock src/runtime/mod_fmr_rossfast_application_config.f90 5892d5b2573c678ab8d121ae80353870b66886d2

# Exact owner-qualified F-ROSS11 projection and provenance.
lock src/runtime/mod_fmr_rossfast_application_runtime.f90 a1af0d6eb0041565602711251748666f7b959d8e
lock integration/f-ross/F-ROSS11_STATUS.json 9a532b643faaef71e43c0eee58e4be7f9c661328
grep -Fq '"qualified_head": "a799f5437e28794fbf9bf2ef811f9944805ce22f"' integration/f-ross/F-ROSS11_STATUS.json
grep -Fq '"conclusion": "success"' integration/f-ross/F-ROSS11_STATUS.json

# Immutable assets and preserved reference/legacy routes.
ASSET_ROOT=assets/rossfast/d3r
lock "$ASSET_ROOT/manifest.json" 1266d15149af5feb8d7fb0a5ef90d41b5881fd55
lock "$ASSET_ROOT/B01_log_mobility_f32.hex" c4cced37b0a6ba284f43dbf8c78cd5ac7ebe8d4e
lock "$ASSET_ROOT/B12_log_mobility_f32.hex" bda7bb0339289fc21671964676cb7d2bd8eccc89
lock "$ASSET_ROOT/O01_log_mobility_f32.hex" 831b29f7c1d04546906c928a15becc20c7328f30
lock "$ASSET_ROOT/O05_log_mobility_f32.hex" 39ddd5f390857d722cc80c4878f90b4f2a4e5908
lock "$ASSET_ROOT/O14_log_mobility_f32.hex" 9746cb348093b735bc10a7cb8f3d5a67a57018bf
lock "$ASSET_ROOT/O18_log_mobility_f32.hex" 68855f4d34d63b7d14743305d2519038d946ed67
lock integration/f-ci/F-CI80_STATUS.json 78ea09f1715c20ed3266557fd4157ff19ba96eed
lock src/runtime/mod_fmr_serialized_reference_backend.f90 9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13
lock src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1aa2454048d0e480becaee34f596f20f1a7bd66e
lock src/legacy/b1_10_port/soilwater.f90 2ab6ea917525cd6f2560860bd55aec1da16be014
lock src/legacy/b1_10_port/swap_main.f90 b6609df617c6b5875c62324570fb8c7d8c0bfe21
lock src/adapter/mod_b110_production_soil_water_task2.f90 5f51a34b03b63cf7cdf254f6115c2bb2db4ea693

APP_RUNTIME=src/runtime/mod_fmr_rossfast_application_runtime.f90
if grep -Eiq 'swap_main|swsolve|MOD_SoilWater|mod_rossfast_application_config_file_adapter|mod_fmr_serialized_reference_backend|mod_fmr_serialized_multiswap_runtime|open\s*\(|read\s*\(' "$APP_RUNTIME"; then
  echo 'FCI81_APPLICATION_RUNTIME_CROSSES_EXCLUDED_BOUNDARY' >&2
  exit 181
fi
grep -Fq 'fmr_bind_rossfast_application_config' "$APP_RUNTIME"
grep -Fq 'dispatcher%execute_batch' "$APP_RUNTIME"
grep -Fq 'FMR_ROSSFAST_DISPATCH_PROVIDER_REJECTED' "$APP_RUNTIME"

allowed_re='^(src/runtime/mod_fmr_rossfast_application_runtime\.f90|integration/f-ross/F-ROSS11_STATUS\.json|tests/integration/test_fci81_rossfast_application_composition\.f90|tests/integration/run_fci81_rossfast_application_composition_admission\.sh|\.github/workflows/f-ci81-rossfast-application-composition-admission\.yml|integration/f-ci/F-CI81_STATUS\.json)$'
while IFS= read -r path; do
  [[ "$path" =~ $allowed_re ]] || { echo "FCI81_UNEXPECTED_PATH $path" >&2; exit 182; }
done < <(git diff --name-only "$PREIMAGE..HEAD")

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
TEST=tests/integration/test_fci81_rossfast_application_composition.f90
WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp -ffree-line-length-none)

for opt in o0 o2; do
  flag=-O0; [[ "$opt" == o2 ]] && flag=-O2
  d="$BUILD/$opt"
  compile() { gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$d" -I "$d" -c "$1" -o "$d/$2.o"; }

  compile "$STEP_DIRECTION" step_direction
  compile "$TRAJECTORY_DIRECTION" trajectory_direction
  compile "$TRAJECTORY_PUBLICATION" trajectory_publication
  compile "$TX" tx
  compile "$CONTRACTS" contracts
  compile "$RUNTIME" runtime
  compile "$KERNEL_TX" kernel_tx
  compile "$ORCH" orch
  compile "$FMR_CORE" fmr_core
  compile "$POLICY" policy
  compile "$BINDING" binding
  compile "$TABLE_KERNEL" table_kernel
  compile "$PROVIDER" provider
  compile "$KERNEL_ADAPTER" kernel_adapter
  compile "$SERIAL_BACKEND" serial_backend
  compile "$DISPATCH" dispatch
  compile "$SELECTION" selection
  compile "$CONFIG" config
  compile "$APP_RUNTIME" app_runtime
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$d" -I "$d" -c "$TEST" -o "$d/test.o"

  gfortran -fopenmp "$d/step_direction.o" "$d/trajectory_direction.o" "$d/trajectory_publication.o" \
    "$d/tx.o" "$d/contracts.o" "$d/runtime.o" "$d/kernel_tx.o" "$d/orch.o" "$d/fmr_core.o" \
    "$d/policy.o" "$d/binding.o" "$d/table_kernel.o" "$d/provider.o" "$d/kernel_adapter.o" \
    "$d/serial_backend.o" "$d/dispatch.o" "$d/selection.o" "$d/config.o" "$d/app_runtime.o" \
    "$d/test.o" -o "$d/test"

  "$d/test" "$ASSET_ROOT" > "$d/output.txt"
  grep -Fq 'FCI81_INDEPENDENT_ROSSFAST_APPLICATION_COMPOSITION PASS' "$d/output.txt"
  grep -Fq 'FCI81_REFERENCE_REJECT PASS' "$d/output.txt"
  grep -Fq 'FCI81_MISSING_ASSET_PREFLIGHT PASS' "$d/output.txt"
  for material in B01 B12 O01 O05 O14 O18; do grep -Fq "FCI81_EQUIV $material" "$d/output.txt"; done
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "FCI81_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "FCI81_OWNER_HEAD=$OWNER_HEAD"
echo "FCI81_OWNER_QUALIFIED_HEAD=$OWNER_QUALIFIED_HEAD"
echo 'FCI81_ROSSFAST_APPLICATION_COMPOSITION_ADMISSION=PASS'
