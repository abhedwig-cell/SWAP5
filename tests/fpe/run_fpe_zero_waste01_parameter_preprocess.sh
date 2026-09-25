#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-param-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/mvg.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c tests/fpe/test_fpe_zero_waste01_parameter_preprocess.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/mvg.o" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" 4 100000
"$BUILD/test" 60 10000
"$BUILD/test" 200 3000
"$BUILD/test" 1000 500
echo 'FPE_ZERO_WASTE01_PARAMETER_PREPROCESS=PASS'

python3 - <<'PY'
from pathlib import Path
backend = Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text(encoding="utf-8").lower()
bootstrap = Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text(encoding="utf-8").lower()
for token in [
    "prepared_default_mvg_available",
    "prepare_fmr_b110_default_mvg",
    "prepared_default_mvg_compatible",
    "self%owned_hydraulic_parameters = parameters%prepared_default_mvg",
    "self%hydraulic_parameters => self%trusted_parameter_source%prepared_default_mvg",
    "initialize_b110_default_mvg_parameters(self%hydraulic_parameters",
]:
    assert token in backend, token
assert "call prepare_fmr_b110_default_mvg(self%parameters(i)" in bootstrap
print("FPE_ZERO_WASTE01_PREPARED_HYDRAULIC_WIRING_STATIC=PASS")
PY
