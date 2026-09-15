#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci80-${GITHUB_RUN_ID:-local}-$$"
FIXTURES="$BUILD/fixtures"
mkdir -p "$BUILD/ross10/o0" "$BUILD/ross10/o2" "$FIXTURES"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PREIMAGE=b7c2e510c68e5799a138e881793d27037c482b8a
SOURCE=a483452f04a85f3bb64eaad6a383a4800abaed16
LIVE_CANON="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
test "$LIVE_CANON" = "$PREIMAGE"
git merge-base --is-ancestor "$PREIMAGE" HEAD

# Current-canonical inherited authorities. These are not replaced by F-CI80.
test "$(git rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:src/runtime/mod_canonical_interval_runtime.f90)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" = d3a53385e3707f05e5396bbd6f218633b9803f65
test "$(git rev-parse HEAD:src/runtime/mod_fmr_checkpoint_orchestrator.f90)" = 0dceaa2d108d5c7e1263e0f424a056a8df585908
test "$(git rev-parse HEAD:src/runtime/mod_fmr_runtime_core.f90)" = 43eef1979e0202f8ecc92f73eb7d8025dab515a4
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

# Exact previously qualified RossFast production projection.
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = 9f29ba7a08844692ba2628c7869d23713409f92b
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = 034136c193b287bcf9a953a9b89df2a8fb0c97cc
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = afc05eb3001d91f66ca542978c3c6795283a7ac0
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_kernel_model_adapter.f90)" = dabd5da97e7a4d5990cb5a0f07928aa9f03a6c1e
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_kernel_backend.f90)" = 29093b517bc6fdd40f32325018729c4c3dee6e85
test "$(git rev-parse HEAD:src/runtime/mod_fmr_rossfast_registry_dispatch.f90)" = 7f900e75f4bea1c9b999464b7a8d4f7be4b35064
test "$(git rev-parse HEAD:src/runtime/mod_fmr_rossfast_application_selection.f90)" = 5b652f04f172a8faa468d38faa23883ce6f35294
test "$(git rev-parse HEAD:src/runtime/mod_fmr_rossfast_application_config.f90)" = 5892d5b2573c678ab8d121ae80353870b66886d2
test "$(git rev-parse HEAD:src/adapter/mod_rossfast_application_config_file_adapter.f90)" = 55dc1632eb4d72d52cc2e038765710801bee5dd2

# Immutable table authority.
test "$(git rev-parse HEAD:assets/rossfast/d3r/manifest.json)" = 1266d15149af5feb8d7fb0a5ef90d41b5881fd55
test "$(git rev-parse HEAD:assets/rossfast/d3r/B01_log_mobility_f32.hex)" = c4cced37b0a6ba284f43dbf8c78cd5ac7ebe8d4e
test "$(git rev-parse HEAD:assets/rossfast/d3r/B12_log_mobility_f32.hex)" = bda7bb0339289fc21671964676cb7d2bd8eccc89
test "$(git rev-parse HEAD:assets/rossfast/d3r/O01_log_mobility_f32.hex)" = 831b29f7c1d04546906c928a15becc20c7328f30
test "$(git rev-parse HEAD:assets/rossfast/d3r/O05_log_mobility_f32.hex)" = 39ddd5f390857d722cc80c4878f90b4f2a4e5908
test "$(git rev-parse HEAD:assets/rossfast/d3r/O14_log_mobility_f32.hex)" = 9746cb348093b735bc10a7cb8f3d5a67a57018bf
test "$(git rev-parse HEAD:assets/rossfast/d3r/O18_log_mobility_f32.hex)" = 68855f4d34d63b7d14743305d2519038d946ed67

# Immutable owner qualification records projected as provenance.
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS02_STATUS.json)" = 6d4fe3bdd10c70c6edc684c6051c82217c5e1467
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS03_STATUS.json)" = 6733b7a5ddd4b9761c9bdad26a5c7e21c8e92c7c
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS04_STATUS.json)" = e4ae23777d3f329822bf74051f4b139c04a59877
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS05_STATUS.json)" = 1fe9d85d65090cf0893620dc2d5d9ea7cb271a50
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS06_STATUS.json)" = 4a7c855bb026e2a5be1c64288c53f4b1829e751c
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS07_STATUS.json)" = 1d930f4e1b1e75324cea77bf4e42f6fd3f7e7840
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS08_STATUS.json)" = 7cf4028b72adea5c97962d2c7206c81515e12333
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS09_STATUS.json)" = 231b22bc321e679bfe1af59434f8701b6e3cf02e
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS10_STATUS.json)" = ec398adbaae6948fdf6323c55e476f5f080f20d1

# Preserve current canonical reference/legacy routes exactly. The reference
# backend legitimately changed after F-CI75 for EB-I25 and must not be reverted.
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = 960ea116cad81e8c0db8a579982f4999b3d085ed
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" = 1aa2454048d0e480becaee34f596f20f1a7bd66e
test "$(git rev-parse HEAD:src/legacy/b1_10_port/soilwater.f90)" = c1850ea7fa82a1ed8974af57e1da95aa11a771be
test "$(git rev-parse HEAD:src/legacy/b1_10_port/swap_main.f90)" = b6609df617c6b5875c62324570fb8c7d8c0bfe21
test "$(git rev-parse HEAD:src/adapter/mod_b110_production_soil_water_task2.f90)" = 3090e1d3d5701a87b3624412ad88590e17369d63

# No projected RossFast adapter/selector may capture the reference or legacy
# route, SW_SOLVE, or MultiSWAP automatically.
for path in \
  src/runtime/mod_fmr_rossfast_registry_dispatch.f90 \
  src/runtime/mod_fmr_rossfast_application_selection.f90 \
  src/runtime/mod_fmr_rossfast_application_config.f90 \
  src/adapter/mod_rossfast_application_config_file_adapter.f90; do
  if grep -Eiq 'MOD_SoilWater|sw_solve|swsolve|mod_b110_production_soil_water_task2|mod_fmr_serialized_reference_backend|mod_fmr_serialized_multiswap_runtime' "$path"; then
    echo "FCI80_OWNERSHIP_BOUNDARY_CROSSED $path" >&2
    exit 180
  fi
done

# Bounded candidate surface relative to the exact current-canonical preimage.
allowed_re='^(src/runtime/mod_rossfast_d3r_model_binding\.f90|src/solver/mod_rossfast_d3r_table_kernel\.f90|src/solver/mod_rossfast_d3r_table_provider\.f90|src/runtime/mod_rossfast_d3r_kernel_model_adapter\.f90|src/runtime/mod_fmr_serialized_kernel_backend\.f90|src/runtime/mod_fmr_rossfast_registry_dispatch\.f90|src/runtime/mod_fmr_rossfast_application_selection\.f90|src/runtime/mod_fmr_rossfast_application_config\.f90|src/adapter/mod_rossfast_application_config_file_adapter\.f90|assets/rossfast/d3r/[^/]+|integration/f-ross/F-ROSS(02|03|04|05|06|07|08|09|10)_STATUS\.json|integration/f-ci/F-CI80_STATUS\.json|tests/ross/test_ross08_explicit_application_model_selection\.f90|tests/ross/run_ross08_explicit_application_model_selection\.sh|tests/ross/test_ross10_external_model_config_file_adapter\.f90|tests/integration/run_fci80_rossfast_restricted_stack_admission\.sh|\.github/workflows/f-ci80-rossfast-restricted-stack-admission\.yml)$'
while IFS= read -r path; do
  [[ "$path" =~ $allowed_re ]] || { echo "FCI80_UNEXPECTED_PATH $path" >&2; exit 181; }
done < <(git diff --name-only "$PREIMAGE..HEAD")

# F-ROSS08 is the full real six-material table-kernel -> transaction ->
# registry -> explicit application route, recompiled and replayed at O0/O2.
bash tests/ross/run_ross08_explicit_application_model_selection.sh \
  > "$BUILD/ross08.log" 2>&1
cat "$BUILD/ross08.log"
grep -Fq 'ROSS08_EXPLICIT_APPLICATION_MODEL_SELECTION=PASS' "$BUILD/ross08.log"

# Re-run the F-ROSS10 typed config/file-adapter contract directly on this
# projected ancestry. The old owner runner intentionally locks owner ancestry,
# which is not part of a blob-projection canonical admission.
printf 'SOIL_WATER_MODEL=ROSSFAST_D3R\n' > "$FIXTURES/valid.cfg"
printf '\n  SOIL_WATER_MODEL = ROSSFAST_D3R  \n\n' > "$FIXTURES/spaced.cfg"
printf 'SOIL_WATER_MODEL=rossfast_d3r\n' > "$FIXTURES/lowercase.cfg"
printf 'MODEL=ROSSFAST_D3R\n' > "$FIXTURES/unknown-key.cfg"
printf 'SOIL_WATER_MODEL ROSSFAST_D3R\n' > "$FIXTURES/malformed.cfg"
printf 'SOIL_WATER_MODEL=ROSSFAST_D3R\nSOIL_WATER_MODEL=ROSSFAST_D3R\n' > "$FIXTURES/duplicate.cfg"
: > "$FIXTURES/empty.cfg"
python3 - "$FIXTURES/oversized.cfg" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text('A' * 4097, encoding='ascii')
PY

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
KERNEL_TX=src/kernel/mod_kernel_transactions.f90
ORCH=src/runtime/mod_fmr_checkpoint_orchestrator.f90
FMR_CORE=src/runtime/mod_fmr_runtime_core.f90
SERIAL_BACKEND=src/runtime/mod_fmr_serialized_kernel_backend.f90
SELECTION=src/runtime/mod_fmr_rossfast_application_selection.f90
CONFIG=src/runtime/mod_fmr_rossfast_application_config.f90
FILE_ADAPTER=src/adapter/mod_rossfast_application_config_file_adapter.f90
TEST=tests/ross/test_ross10_external_model_config_file_adapter.f90
WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp -ffree-line-length-none)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/ross10/$opt"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TX" -o "$moddir/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONTRACTS" -o "$moddir/contracts.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$RUNTIME" -o "$moddir/runtime.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$KERNEL_TX" -o "$moddir/kernel_tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$ORCH" -o "$moddir/orch.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$FMR_CORE" -o "$moddir/fmr_core.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SERIAL_BACKEND" -o "$moddir/serial_backend.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SELECTION" -o "$moddir/selection.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONFIG" -o "$moddir/config.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$FILE_ADAPTER" -o "$moddir/file_adapter.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/fmr_core.o" "$moddir/selection.o" "$moddir/config.o" \
    "$moddir/file_adapter.o" "$moddir/test.o" -o "$moddir/test"
  "$moddir/test" "$FIXTURES" > "$moddir/output.txt"
  grep -Fq 'ROSS10_EXTERNAL_MODEL_CONFIG_FILE_ADAPTER PASS' "$moddir/output.txt"
done
cmp "$BUILD/ross10/o0/output.txt" "$BUILD/ross10/o2/output.txt"
cat "$BUILD/ross10/o0/output.txt"

echo "FCI80_SOURCE_AUTHORITY=$SOURCE"
echo "FCI80_ROSS08_SHA256=$(sha256sum "$BUILD/ross08.log" | awk '{print $1}')"
echo "FCI80_ROSS10_SHA256=$(sha256sum "$BUILD/ross10/o0/output.txt" | awk '{print $1}')"
echo 'FCI80_ROSSFAST_RESTRICTED_STACK_ADMISSION=PASS'
