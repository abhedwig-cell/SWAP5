#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-sw-rib-pa01-owner-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -J "$BUILD" -I "$BUILD"   -c src/runtime/mod_fmr_runtime_core.f90 -o "$BUILD/runtime_core.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -J "$BUILD" -I "$BUILD"   -c src/runtime/mod_fmr_surface_water_owner_contract.f90 -o "$BUILD/owner.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -J "$BUILD" -I "$BUILD"   -c tests/sw-rib-pa01/test_owner_contract.f90 -o "$BUILD/test.o"
gfortran "$BUILD/runtime_core.o" "$BUILD/owner.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test" | tee "$BUILD/output.txt"
grep -Fq 'SW_RIB_PA01_OWNER_XOR_CONTRACT=PASS' "$BUILD/output.txt"
echo 'SW_RIB_PA01_OWNER_GATE=PASS'
