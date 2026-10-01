#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
B="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/top02-$$";mkdir -p "$B";trap 'rm -rf "$B"' EXIT
python3 "$ROOT/tests/rom/compile_f_rom0_fortran_closure.py" --root "$ROOT" --stub "$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90" --target "$ROOT/tests/fapp/test_sw_rib_top02_external_head.f90" --build "$B/o0" --opt 0
"$B/o0/rom0_test"
python3 "$ROOT/tests/rom/compile_f_rom0_fortran_closure.py" --root "$ROOT" --stub "$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90" --target "$ROOT/tests/fapp/test_sw_rib_top02_external_head.f90" --build "$B/o2" --opt 2
"$B/o2/rom0_test"
echo SW_RIB_TOP02_O0_O2=PASS
