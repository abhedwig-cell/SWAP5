#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for opt in "-O0" "-O2"; do
  rm -f "$BUILD"/*.o "$BUILD"/*.mod "$BUILD"/gate
  "$FC" -std=f2008 -Wall -Wextra -fcheck=all $opt -J"$BUILD" -I"$BUILD" -c     "$ROOT/src/process/macropore/mod_macropore_covering_layer_input.f90" -o "$BUILD/op.o"
  "$FC" -std=f2008 -Wall -Wextra -fcheck=all $opt -J"$BUILD" -I"$BUILD"     "$ROOT/tests/fpm/test_ppa_wu05_migmac01_covering_layer.f90" "$BUILD/op.o" -o "$BUILD/gate"
  "$BUILD/gate"
done
echo "PPA_WU05_MIGMAC01_COVERING_LAYER_GATE=PASS"
