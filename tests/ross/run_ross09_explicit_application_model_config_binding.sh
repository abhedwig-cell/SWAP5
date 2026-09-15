#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross09-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=7b16da2aadcfdcda842002b1cd5ba4f9bab5a00f
LIVE="$(git ls-remote origin refs/heads/work/f-ross08-explicit-application-model-selection | awk '{print $1}')"
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
TEST=tests/ross/test_ross09_explicit_application_model_config_binding.f90
ROSS08_STATUS=integration/f-ross/F-ROSS08_STATUS.json
LEGACY_SOILWATER=src/legacy/b1_10_port/soilwater.f90
PRODUCTION_TASK2=src/adapter/mod_b110_production_soil_water_task2.f90

# Reuse the immutable F-ROSS08 scientific qualification.  The reconciliation
# merge after that qualification changed ancestry/governance only, not these
# qualified source or evidence blobs.
test "$(git rev-parse HEAD:$FMR_CORE)" = 43eef1979e0202f8ecc92f73eb7d8025dab515a4
test "$(git rev-parse HEAD:$SERIAL_BACKEND)" = 29093b517bc6fdd40f32325018729c4c3dee6e85
test "$(git rev-parse HEAD:$SELECTION)" = 5b652f04f172a8faa468d38faa23883ce6f35294
test "$(git rev-parse HEAD:$ROSS08_STATUS)" = 7cf4028b72adea5c97962d2c7206c81515e12333
test "$(git rev-parse HEAD:$LEGACY_SOILWATER)" = c1850ea7fa82a1ed8974af57e1da95aa11a771be
test "$(git rev-parse HEAD:$PRODUCTION_TASK2)" = 3090e1d3d5701a87b3624412ad88590e17369d63

# The new seam is deliberately configuration-only.  It may bind the exact
# F-ROSS08 application key, but it may not reach into legacy routing or the
# Full-Richards production adapter.
if grep -Eiq 'sw_solve|swsolve|MOD_SoilWater|mod_b110_production_soil_water_task2|serialized_reference_backend|serialized_multiswap_runtime' "$CONFIG"; then
  echo 'ROSS09_CONFIG_CROSSES_EXCLUDED_ROUTING_BOUNDARY' >&2
  exit 109
fi
grep -Fq "FMR_APPLICATION_CONFIG_KEY_SOIL_WATER_MODEL = 'SOIL_WATER_MODEL'" "$CONFIG"
grep -Fq 'FMR_APPLICATION_MODEL_ROSSFAST_D3R' "$CONFIG"
grep -Fq 'if (.not. config%supplied) return' "$CONFIG"
grep -Fq 'FMR_ROSSFAST_CONFIG_COLUMN_CONFLICT' "$CONFIG"

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
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SERIAL_BACKEND" -o "$moddir/serial_backend.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$SELECTION" -o "$moddir/selection.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONFIG" -o "$moddir/config.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"

  gfortran -fopenmp "$moddir/fmr_core.o" "$moddir/selection.o" "$moddir/config.o" "$moddir/test.o" \
    -o "$moddir/test"
  "$moddir/test" > "$moddir/output.txt"
  grep -Fq 'ROSS09_EXPLICIT_APPLICATION_MODEL_CONFIG_BINDING PASS' "$moddir/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo "ROSS09_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'ROSS09_EXPLICIT_APPLICATION_MODEL_CONFIG_BINDING=PASS'
