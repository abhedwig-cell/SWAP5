#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
RIBASIM_ROOT="${SW_RIB_ADM01_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_adm01_g5b"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sw-rib-adm01-g5b-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
PIN=eae77424a4078497d40d8197237cb83e3aba6a83
test -d "$RIBASIM_ROOT/.git"
test "$(git -C "$RIBASIM_ROOT" rev-parse HEAD)" = "$PIN"
echo "SW_RIB_ADM01_G5B_RIBASIM_PIN=PASS sha=$PIN"

PY_VERSION="$(cd "$RIBASIM_ROOT" && pixi run python -c 'import ribasim; print(ribasim.__version__)')"
test "$PY_VERSION" = "2026.1.2"
echo "SW_RIB_ADM01_G6_PYTHON_VERSION=PASS version=$PY_VERSION"

gfortran -std=f2008 -Wall -Wextra -Werror   src/runtime/mod_external_surface_water_transaction.f90   tests/sw-rib-adm01/g5b_transaction_bridge.f90   -o "$BUILD/bridge"

(
 cd "$RIBASIM_ROOT"
 pixi run python "$ROOT/tests/sw-rib-adm01/generate_g5b_real_ribasim.py" "$MODEL_ROOT"
 grep -R -Fq 'ribasim_version = "2026.1.2"' "$MODEL_ROOT"
 echo 'SW_RIB_ADM01_G6_MODEL_METADATA=PASS'
 pixi run instantiate-julia
 JULIA_VERSION="$(pixi run julia --startup-file=no --project=. -e 'using Ribasim; print(Ribasim.RIBASIM_VERSION)')"
 test "$JULIA_VERSION" = "2026.1.2"
 echo "SW_RIB_ADM01_G6_CORE_VERSION=PASS version=$JULIA_VERSION"
 JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.    "$ROOT/tests/sw-rib-adm01/g5b_realization.jl" "$MODEL_ROOT"
) > "$BUILD/ribasim.txt" 2>&1

cat "$BUILD/ribasim.txt"
if grep -Fq 'Version mismatch' "$BUILD/ribasim.txt"; then
  echo 'SW_RIB_ADM01_G6_FAIL version mismatch warning present' >&2
  exit 1
fi
echo 'SW_RIB_ADM01_G6_VERSION_COHERENCE=PASS'
grep -Fq 'SW_RIB_ADM01_G5B_REAL_RIBASIM_REALIZATION=PASS' "$BUILD/ribasim.txt"
python3 tests/sw-rib-adm01/verify_g5b_receipts.py "$BUILD/ribasim.txt" "$BUILD/bridge" | tee "$BUILD/bridge.txt"
grep -Fq 'SW_RIB_ADM01_G5B_RECEIPT_TO_PRODUCTION_TRANSACTION=PASS' "$BUILD/bridge.txt"
echo 'SW_RIB_ADM01_G5B_GATE=PASS'
