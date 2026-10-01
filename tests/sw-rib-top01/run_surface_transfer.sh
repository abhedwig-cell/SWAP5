#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/sw-rib-top01-c-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
gfortran -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow -O0   "$ROOT/tests/sw-rib-top01/mod_external_top_surface_transfer.f90"   "$ROOT/tests/sw-rib-top01/test_surface_transfer.f90" -o "$BUILD/top01_o0"
"$BUILD/top01_o0"
gfortran -std=f2008 -Wall -Wextra -fcheck=all -O0 \
  "$ROOT/tests/sw-rib-top01/mod_external_top_flooding_classifier.f90" \
  "$ROOT/tests/sw-rib-top01/test_flood_classifier.f90" -o "$BUILD/classifier"
"$BUILD/classifier"
gfortran -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow -O2   "$ROOT/tests/sw-rib-top01/mod_external_top_surface_transfer.f90"   "$ROOT/tests/sw-rib-top01/test_surface_transfer.f90" -o "$BUILD/top01_o2"
"$BUILD/top01_o2"
echo SW_RIB_TOP01_C_O0_O2=PASS
