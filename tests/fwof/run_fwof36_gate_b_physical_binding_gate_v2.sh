#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/swap5-fwof36-gate-b-v2-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

python3 - "$ROOT/tests/fwof/run_fwof36_gate_b_physical_binding_gate.sh" "$TMP/gate.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')

# The V1 failure was confined to the generated disposable Fortran main. Add
# only the missing names/helper; production source and all physical test cases
# are unchanged.
old = '''new_use = (old_use +
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\\n"'''
new = '''new_use = (old_use +
"  use mod_kernel_transactions, only: kernel_checkpoint_t\\n"
"  use mod_fmr_serialized_multiswap_runtime, only: FMR_SERIAL_DISPATCH_INVALID_REQUEST\\n"
"  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t\\n"'''
if src.count(old) != 1:
    raise SystemExit(f'FWOF36 V2 generated-use anchor count={src.count(old)}')
src = src.replace(old, new, 1)

old = "extra_helpers = r'''  subroutine execute_wofost_case"
new = r'''extra_helpers = r''' + "'''" + r'''  logical function all_revisions_zero(states) result(zero)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i
    zero = .true.
    do i = 1, size(states)
      if (states(i)%current_revision() /= 0_int64) then
        zero = .false.
        return
      end if
    end do
  end function all_revisions_zero

  subroutine execute_wofost_case'''
if src.count(old) != 1:
    raise SystemExit(f'FWOF36 V2 helper anchor count={src.count(old)}')
src = src.replace(old, new, 1)

Path(sys.argv[2]).write_text(src, encoding='utf-8')
print('FWOF36_GATE_B_V2_DISPOSABLE_MAIN_FIX=PASS')
PY

chmod +x "$TMP/gate.sh"
bash "$TMP/gate.sh"
