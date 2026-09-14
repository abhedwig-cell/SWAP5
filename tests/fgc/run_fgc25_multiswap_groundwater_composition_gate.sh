#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FGC21_OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
BUILD="${TMPDIR:-/tmp}/swap5-fgc25-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

git cat-file -e "$FGC21_OWNER^{commit}"
python3 - "$FGC21_OWNER" "$BUILD/fgc21_fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
owner=sys.argv[1]
out=Path(sys.argv[2])
text=subprocess.check_output([
    'git','show',f'{owner}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'
], text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
assert text.count(marker)==1
out.write_text(text.split(marker,1)[0]+'\n')
PY

echo 'FGC25_FGC21_OWNER_FIXTURE=PASS'

python3 - <<'PY'
from pathlib import Path
coupler=Path('src/runtime/mod_groundwater_multiswap_coupler.f90').read_text().lower()
pub=Path('src/runtime/mod_groundwater_multiswap_publication.f90').read_text().lower()
top=Path('src/runtime/mod_groundwater_multiswap_topology.f90').read_text().lower()
for text in (coupler,pub,top):
    for forbidden in ['modflow', 'open(', 'read(', 'write(']:
        assert forbidden not in text.replace(' ', ''), forbidden
assert 'area_fraction' in pub
assert 'stage_multiswap_tile_ledger' in pub
assert 'multiswap_publication_preflight' in pub
assert 'late swap commit failed after prior tile publication' in pub
print('FGC25_NO_MODFLOW_OR_IO_DEPENDENCY=PASS')
print('FGC25_TILE_LINEAGE_LEDGER_PUBLICATION=PASS')
print('FGC25_CELL_PUBLICATION_PREFLIGHT=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_groundwater_multiswap_topology.f90
  src/runtime/mod_groundwater_multiswap_swap_phase.f90
  src/runtime/mod_groundwater_multiswap_transaction.f90
  src/runtime/mod_groundwater_multiswap_publication.f90
  src/runtime/mod_groundwater_multiswap_coupler.f90
  "$BUILD/fgc21_fixture.f90"
  tests/fgc/mod_fgc25_multiswap_fixture.f90
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  for test in test_fgc25_multiswap_commit test_fgc25_single_tile_equivalence; do
    : > "$dir/${test}.compiler.txt"
    if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
        "${SOURCES[@]}" "tests/fgc/${test}.f90" -o "$dir/${test}" 2>"$dir/${test}.compiler.txt"; then
      echo "FGC25_COMPILE_${test}_O${opt}=FAIL" >&2
      cat "$dir/${test}.compiler.txt" >&2
      exit 30
    fi
    if grep -E 'Warning:' "$dir/${test}.compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
      echo "FGC25_UNEXPECTED_WARNING_${test}_O${opt}=FAIL" >&2
      cat "$dir/${test}.compiler.txt" >&2
      exit 31
    fi
    "$dir/${test}"
    echo "FGC25_${test}_O${opt}=PASS"
  done
done

echo 'F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS'
