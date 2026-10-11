#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="${TMPDIR:-/tmp}/swap5_pp02_kernel_qualification"
rm -rf "$WORK"
mkdir -p "$WORK"

FC="${FC:-gfortran}"
PYTHON="${PYTHON:-python3}"

ASSIM_SRC="$ROOT/src/crop/mod_wofost81_assimilation.f90"
N_SRC="$ROOT/src/crop/mod_wofost81_nitrogen.f90"
NSTRESS_SRC="$ROOT/src/crop/mod_wofost81_n_stress.f90"
T="$ROOT/tests/fwof/pp02"

"$FC" -std=f2008 -O0 "$ASSIM_SRC" "$T/test_wofost81_assimilation_driver.f90" -o "$WORK/assim_O0"
"$FC" -std=f2008 -O2 "$ASSIM_SRC" "$T/test_wofost81_assimilation_driver.f90" -o "$WORK/assim_O2"
"$PYTHON" "$T/check_wofost81_assimilation_oracle.py" "$WORK/assim_O0" "$WORK/assim_O2"

"$FC" -std=f2008 -O2 "$N_SRC" "$T/test_wofost81_nitrogen_driver.f90" -o "$WORK/nitrogen_driver"
"$PYTHON" "$T/check_wofost81_nitrogen.py" "$WORK/nitrogen_driver"
"$FC" -std=f2008 -O2 "$N_SRC" "$T/test_wofost81_nitrogen_edges.f90" -o "$WORK/nitrogen_edges"
"$WORK/nitrogen_edges"

"$FC" -std=f2008 -O2 "$NSTRESS_SRC" "$T/test_wofost81_n_stress_driver.f90" -o "$WORK/nstress_driver"
"$PYTHON" "$T/check_wofost81_n_stress.py" "$WORK/nstress_driver"
