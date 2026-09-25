#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-gwreg-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
gfortran -std=f2008 -ffree-line-length-none -O2 tests/fpe/test_fpe_zero_waste01_gwreg_resolution.f90 -o "$BUILD/test"
for n in 100 1000 10000; do "$BUILD/test" "$n"; done

python3 - <<'PY'
from pathlib import Path
src=Path("src/runtime/mod_fmr_groundwater_participant_registry.f90").read_text(encoding="utf-8").lower()
for name in ("resolve_handle","resolve_handle_const"):
    block=src.split(f"subroutine {name}",1)[1].split(f"end subroutine {name}",1)[0]
    assert "handle <= int(size(self%slots), int64)" in block
    assert "self%slots(i)%active .and. self%slots(i)%handle_id == handle" in block
    assert "do i = 1, size(self%slots)" in block
print("FPE_ZERO_WASTE01_GWREG01_PRODUCTION_WIRING_STATIC=PASS")
PY
