#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d -t swap5-low01-const-XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "LOW01-CONST FAIL: $*" >&2; exit 1; }

COMMON=(-std=f2008 -Wall -Wextra -O0 -g)
OWNED=("${COMMON[@]}" -Werror)

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" \
  -c src/solver/mod_soil_water_solver_contract.f90 \
  -o "$BUILD/mod_soil_water_solver_contract.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" \
  -c src/solver/mod_b110_default_mvg_provider.f90 \
  -o "$BUILD/mod_b110_default_mvg_provider.o"
gfortran "${OWNED[@]}" -J "$BUILD" -I "$BUILD" \
  -c tests/research/support/mod_gc_low01_constitutive_bridge.f90 \
  -o "$BUILD/mod_gc_low01_constitutive_bridge.o"
gfortran "${OWNED[@]}" -J "$BUILD" -I "$BUILD" \
  -c tests/research/test_gc_low01_constitutive_bridge.f90 \
  -o "$BUILD/test_gc_low01_constitutive_bridge.o"
gfortran -O0 \
  "$BUILD/mod_soil_water_solver_contract.o" \
  "$BUILD/mod_b110_default_mvg_provider.o" \
  "$BUILD/mod_gc_low01_constitutive_bridge.o" \
  "$BUILD/test_gc_low01_constitutive_bridge.o" \
  -o "$BUILD/test_gc_low01_constitutive_bridge"

"$BUILD/test_gc_low01_constitutive_bridge" | tee "$BUILD/output.txt"

for marker in   'GC_LOW01_CONST_PROVIDER_SCALAR_EQUIVALENCE=PASS'   'GC_LOW01_CONST_SATURATED_THETA_COFGEN2=PASS'   'GC_LOW01_CONST_SATURATED_K_COFGEN3=PASS'   'GC_LOW01_CONST_KSATEXM_DISABLED_BOUND=PASS'   'GC_LOW01_CONST_BRIDGE_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/output.txt" || fail "missing marker $marker"
done

git diff --check --   integration/research/GC_LOW01B_CONSTITUTIVE_OWNERSHIP_AUDIT.json   integration/research/GC_LOW01B_PREREGISTRATION_AMENDMENT_V2.json   tests/research/support/mod_gc_low01_constitutive_bridge.f90   tests/research/test_gc_low01_constitutive_bridge.f90   tests/research/run_gc_low01_constitutive_bridge.sh

echo 'GC_LOW01_CONSTITUTIVE_BRIDGE_QUALIFICATION=PASS'
