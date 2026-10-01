#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
B="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/top03runots-$$";mkdir -p "$B";trap 'rm -rf "$B"' EXIT
for opt in 0 2; do
 python3 "$ROOT/tests/rom/compile_f_rom0_fortran_closure.py" --root "$ROOT" --stub "$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90" --target "$ROOT/tests/fapp/test_sw_rib_top03_external_head_runots.f90" --build "$B/o$opt" --opt "$opt"
 "$B/o$opt/rom0_test"
done
echo SW_RIB_TOP03_RUNOTS_O0_O2=PASS
