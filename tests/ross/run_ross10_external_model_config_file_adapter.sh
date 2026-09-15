#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross10-${GITHUB_RUN_ID:-local}-$$"
FIXTURES="$BUILD/fixtures"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$FIXTURES"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=b98e7d40e76fd919198766d318b83c1c3c15661e
LIVE="$(git ls-remote origin refs/heads/work/f-ross09-explicit-application-model-config-binding | awk '{print $1}')"
test "$LIVE" = "$BASE"
git merge-base --is-ancestor "$BASE" HEAD

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
ROSS09_STATUS=integration/f-ross/F-ROSS09_STATUS.json
LEGACY_SOILWATER=src/legacy/b1_10_port/soilwater.f90
LEGACY_MAIN=src/legacy/b1_10_port/swap_main.f90
PRODUCTION_TASK2=src/adapter/mod_b110_production_soil_water_task2.f90

# F-ROSS10 inherits the exact qualified typed selection/configuration stack.
test "$(git rev-parse HEAD:$FMR_CORE)" = 43eef1979e0202f8ecc92f73eb7d8025dab515a4
test "$(git rev-parse HEAD:$SERIAL_BACKEND)" = 29093b517bc6fdd40f32325018729c4c3dee6e85
test "$(git rev-parse HEAD:$SELECTION)" = 5b652f04f172a8faa468d38faa23883ce6f35294
test "$(git rev-parse HEAD:$CONFIG)" = 5892d5b2573c678ab8d121ae80353870b66886d2
test "$(git rev-parse HEAD:$ROSS09_STATUS)" = 231b22bc321e679bfe1af59434f8701b6e3cf02e
test "$(git rev-parse HEAD:$LEGACY_SOILWATER)" = c1850ea7fa82a1ed8974af57e1da95aa11a771be
test "$(git rev-parse HEAD:$LEGACY_MAIN)" = b6609df617c6b5875c62324570fb8c7d8c0bfe21
test "$(git rev-parse HEAD:$PRODUCTION_TASK2)" = 3090e1d3d5701a87b3624412ad88590e17369d63

# The external adapter may perform file I/O and syntax translation only.  It
# must flow through the F-ROSS09 typed config contract and may not bypass it to
# touch solver selection, legacy routing, or production Full-Richards code.
grep -Fq 'use mod_fmr_rossfast_application_config' "$FILE_ADAPTER"
if grep -Eiq 'mod_fmr_rossfast_application_selection|sw_solve|swsolve|MOD_SoilWater|mod_b110_production_soil_water_task2|serialized_reference_backend|serialized_multiswap_runtime' "$FILE_ADAPTER"; then
  echo 'ROSS10_FILE_ADAPTER_CROSSES_OWNERSHIP_BOUNDARY' >&2
  exit 110
fi
grep -Fq "open(newunit=unit, file=trim(path), status='old', action='read'" "$FILE_ADAPTER"
grep -Fq 'FMR_ROSSFAST_CONFIG_FILE_MULTIPLE_ASSIGNMENTS' "$FILE_ADAPTER"
grep -Fq 'FMR_ROSSFAST_CONFIG_FILE_MAX_BYTES = 4096' "$FILE_ADAPTER"

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

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp -ffree-line-length-none)
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

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS10_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'ROSS10_EXTERNAL_MODEL_CONFIG_FILE_ADAPTER=PASS'
