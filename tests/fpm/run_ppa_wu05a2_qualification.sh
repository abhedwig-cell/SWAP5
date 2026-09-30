#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a2-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/runtime/mod_macropore_continuation_state.f90 -o "$OUT/state.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a2_macropore_state.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/state.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  grep -Fq 'PPA_WU05A2_MACROPORE_STATE_TEST PASS' "$OUT/out.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"

echo 'PPA_WU05A2_DTO_O0_O2=PASS'
bash tests/fkt/run_fkt22_fmr_compile_gate.sh

echo 'PPA_WU05A2_INTEGRATED_FMR_COMPILE=PASS'

python3 - <<'PY'
from pathlib import Path
core=Path('src/runtime/mod_fmr_runtime_core.f90').read_text()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
restart=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text()

assert 'FMR_OPTIONAL_STATE_LAYOUT_MACROPORE = 505001_int64' in core
assert 'FMR_OPTIONAL_STATE_LAYOUT_MACROPORE)' in core
assert 'type(macropore_continuation_state_t), allocatable :: macropore' in backend
assert 'if (allocated(target%macropore)) deallocate(target%macropore)' in backend
assert 'target%macropore = source%macropore' in backend
assert 'case (FMR_OPTIONAL_STATE_LAYOUT_MACROPORE)' in restart
assert 'state%macropore%ready()' in restart
assert 'state%macropore%num_nodes == state%active_nodes' in restart
print('PPA_WU05A2_RUNTIME_BINDING_STATIC=PASS')
PY

git diff --check -- src/runtime/mod_macropore_continuation_state.f90   src/runtime/mod_fmr_runtime_core.f90   src/runtime/mod_fmr_serialized_reference_backend.f90   src/runtime/mod_fmr_restart_state_contract.f90   tests/fpm/test_ppa_wu05a2_macropore_state.f90

echo 'PPA_WU05A2_GATE=PASS'
