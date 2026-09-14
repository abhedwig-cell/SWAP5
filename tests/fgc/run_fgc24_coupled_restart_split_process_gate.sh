#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FGC21_OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
BUILD="${TMPDIR:-/tmp}/swap5-fgc24-$$"
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

echo 'FGC24_FGC21_OWNER_FIXTURE=PASS'

python3 - <<'PY'
from pathlib import Path
prod=Path('src/runtime/mod_groundwater_coupled_restart.f90').read_text().lower()
ledger=Path('src/runtime/mod_groundwater_interface_mass_ledger.f90').read_text().lower()
for forbidden in ['.swp', 'midnight', '86400', 'modflow']:
    assert forbidden not in prod, forbidden
for forbidden in ['open(', 'read(', 'write(']:
    assert forbidden not in prod.replace(' ', ''), forbidden
assert 'backend_token' not in prod
assert 'candidate_token' not in prod
assert 'prepare_token' not in prod
assert 'class(transaction_state_t), allocatable :: swap_physical_state' in prod
assert 'class(groundwater_restart_state_t), allocatable :: backend_state' in prod
assert 'trial_exchange_m' not in ledger.split('type, public :: groundwater_interface_mass_restart_record_t',1)[1].split('end type groundwater_interface_mass_restart_record_t',1)[0]
assert 'prepared_generation' not in ledger.split('type, public :: groundwater_interface_mass_restart_record_t',1)[1].split('end type groundwater_interface_mass_restart_record_t',1)[0]
assert 'discarded_trial_count' in ledger.split('type, public :: groundwater_interface_mass_restart_record_t',1)[1].split('end type groundwater_interface_mass_restart_record_t',1)[0]
print('FGC24_NO_KERNEL_IO_CALENDAR_OR_MODFLOW_DEPENDENCY=PASS')
print('FGC24_NO_TRANSIENT_PUBLICATION_TOKEN_PERSISTENCE=PASS')
print('FGC24_LEDGER_COMMITTED_ONLY_RESTART_RECORD=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/runtime/mod_groundwater_coupled_restart.f90
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  : > "$dir/compiler.txt"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" "$BUILD/fgc21_fixture.f90" tests/fgc/test_fgc24_coupled_restart_split_process.f90 \
      -o "$dir/test" 2>"$dir/compiler.txt"; then
    echo "FGC24_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC24_UNEXPECTED_NON_COMPARE_REAL_WARNING_O${opt}" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi

  "$dir/test" continuous "$dir/continuous.bin"
  "$dir/test" export "$dir/restart.bin"
  "$dir/test" restore "$dir/restart.bin" "$dir/split.bin"
  "$dir/test" selftest

  cmp "$dir/continuous.bin" "$dir/split.bin"
  echo "FGC24_TRUE_PROCESS_SPLIT_EQUIVALENCE_O${opt}=PASS"
  echo "FGC24_SIGNATURE_SHA256_O${opt}=$(sha256sum "$dir/continuous.bin" | cut -d' ' -f1)"
done

cmp "$BUILD/o0/continuous.bin" "$BUILD/o2/continuous.bin"
cmp "$BUILD/o0/split.bin" "$BUILD/o2/split.bin"
echo 'FGC24_O0_O2_SIGNATURE_IDENTITY=PASS'
echo 'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS'
