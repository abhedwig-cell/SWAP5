#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
B="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/top03-$$";mkdir -p "$B";trap 'rm -rf "$B"' EXIT
for opt in 0 2; do
 gfortran -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt"   "$ROOT/src/runtime/mod_fmr_top_surface_exchange.f90" "$ROOT/tests/fapp/test_sw_rib_top03_exchange.f90" -o "$B/t"
 "$B/t"
done
echo SW_RIB_TOP03_O0_O2=PASS
