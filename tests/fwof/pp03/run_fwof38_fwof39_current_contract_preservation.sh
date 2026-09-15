#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp03-preservation-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FWO38=tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh
FWO39=tests/fwof/run_fwof39_crop_event_lifecycle_gate.sh
EXPECTED_FWO38=435ae756e326fc059a771f202eb3d9a144460257
EXPECTED_FWO39=c85424228f65799757833f34272dba570c3ea5c0

[[ "$(git hash-object "$FWO38")" == "$EXPECTED_FWO38" ]] || {
  echo 'F-WOF-PP03 F-WOF38 source drift' >&2
  exit 1
}
[[ "$(git hash-object "$FWO39")" == "$EXPECTED_FWO39" ]] || {
  echo 'F-WOF-PP03 F-WOF39 source drift' >&2
  exit 1
}
echo 'F_WOF_PP03_FWO38_SOURCE_BLOB_UNCHANGED=PASS'
echo 'F_WOF_PP03_FWO39_SOURCE_BLOB_UNCHANGED=PASS'

# F-WOF38/F-WOF39 predate two later generic transaction changes:
# 1) F-KT18 requires explicit fail-closed mass-completeness metadata from the
#    historical F-WOF34 physical fixture; and
# 2) current generic transaction sources intentionally use exact time identity,
#    which newer gfortran reports under -Wcompare-reals.  The legacy gate had
#    -Werror globally, so that later compiler hygiene warning prevents the gate
#    from reaching its scientific assertions even though the gate semantics did
#    not change.
#
# For PP03 qualification only, materialize copies of the immutable gate scripts.
# The copies retain every legacy assertion and O0/O2 identity check.  We adapt
# only the historical F-WOF34 fixture's now-required explicit mass metadata and
# demote the two compiler-only warning classes from error to warning. Production
# sources and the immutable F-WOF38/F-WOF39 scripts are never modified.

cat > "$BUILD/adapt_gate.py" <<'PY'
from pathlib import Path
import sys

src_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
root_mode = sys.argv[3]
s = src_path.read_text(encoding='utf-8')

if root_mode == 'pp03':
    old_root = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"\n'
    new_root = 'ROOT="${FWOF_PP03_ROOT:?FWOF_PP03_ROOT not set}"\n'
    if s.count(old_root) != 1:
        raise SystemExit('PP03 preservation root anchor mismatch')
    s = s.replace(old_root, new_root, 1)

old_flags = 'COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)'
new_flags = 'COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)'
if s.count(old_flags) != 1:
    raise SystemExit('PP03 preservation compiler-flags anchor mismatch')
s = s.replace(old_flags, new_flags, 1)

anchor = "print('FWOF38_ATOMIC_TEST_MATERIALIZED=PASS')\nPY\n\nCOMMON="
if s.count(anchor) != 1:
    raise SystemExit('PP03 preservation F-WOF38 materialization anchor mismatch')

adapter = r'''print('FWOF38_ATOMIC_TEST_MATERIALIZED=PASS')
PY

python3 - "$BUILD/fwof38_atomic.f90" <<'PYPP03'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

repls = [
    (
        'use, intrinsic :: iso_fortran_env, only: real64',
        'use, intrinsic :: iso_fortran_env, only: real64, int64',
    ),
    (
        'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t',
        'use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &\n'
        '       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED',
    ),
    (
        '    procedure :: temporal_error => fwof34_temporal_error\n  end type fwof34_model_t',
        '    procedure :: temporal_error => fwof34_temporal_error\n'
        '    procedure :: storage_accounting_status => fwof34_storage_accounting_status\n'
        '  end type fwof34_model_t',
    ),
    (
        '    outcome%solver_ok = .true.\n    outcome%mass_in = transfer_mass',
        '    outcome%solver_ok = .true.\n'
        '    outcome%mass_accounting_complete = .true.\n'
        '    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE\n'
        '    outcome%mass_in = transfer_mass',
    ),
]
for old, new in repls:
    if old not in s:
        raise SystemExit(f'PP03 F-WOF34 compatibility anchor missing: {old!r}')
    s = s.replace(old, new, 1)

end_marker = '\nend module mod_fwof34_test_model\n'
if s.count(end_marker) != 1:
    raise SystemExit('PP03 F-WOF34 module-end anchor mismatch')
helper = r'''

  subroutine fwof34_storage_accounting_status(self, state, complete, missing_mask)
    class(fwof34_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (self%scale < 0.0_real64) return
    select type (state)
    type is (fwof34_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      return
    end select
  end subroutine fwof34_storage_accounting_status
'''
s = s.replace(end_marker, helper + end_marker, 1)
p.write_text(s, encoding='utf-8')
print('F_WOF_PP03_FWO34_CURRENT_MASS_CONTRACT_ADAPTED=PASS')
PYPP03

COMMON='''
s = s.replace(anchor, adapter, 1)
out_path.write_text(s, encoding='utf-8')
PY

python3 "$BUILD/adapt_gate.py" "$FWO38" "$BUILD/run_fwof38_compat.sh" pp03
chmod +x "$BUILD/run_fwof38_compat.sh"
FWOF_PP03_ROOT="$ROOT" bash "$BUILD/run_fwof38_compat.sh" | tee "$BUILD/fwof38.out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' "$BUILD/fwof38.out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fwof38.out"
echo 'F_WOF_PP03_FWO38_CURRENT_CONTRACT_PRESERVATION=PASS'

# F-WOF39 deliberately derives from the exact immutable F-WOF38 donor and
# verifies its hash. Keep that mechanism intact. Adapt only the derived script
# after F-WOF39 has produced it, using the same compatibility transformation.
python3 - "$FWO39" "$BUILD/run_fwof39_compat.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
old_root = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"\n'
new_root = 'ROOT="${FWOF_PP03_ROOT:?FWOF_PP03_ROOT not set}"\n'
if src.count(old_root) != 1:
    raise SystemExit('PP03 F-WOF39 root anchor mismatch')
src = src.replace(old_root, new_root, 1)

old_run = 'FWOF39_ROOT="$ROOT" bash "$BUILD/run_fwof39_derived.sh" | tee "$BUILD/output.txt"\n'
new_run = '''python3 "$FWOF_PP03_ADAPTER" "$BUILD/run_fwof39_derived.sh" "$BUILD/run_fwof39_derived_compat.sh" derived
chmod +x "$BUILD/run_fwof39_derived_compat.sh"
FWOF39_ROOT="$ROOT" bash "$BUILD/run_fwof39_derived_compat.sh" | tee "$BUILD/output.txt"
'''
if src.count(old_run) != 1:
    raise SystemExit('PP03 F-WOF39 derived-run anchor mismatch')
src = src.replace(old_run, new_run, 1)
Path(sys.argv[2]).write_text(src, encoding='utf-8')
PY
chmod +x "$BUILD/run_fwof39_compat.sh"
FWOF_PP03_ROOT="$ROOT" FWOF_PP03_ADAPTER="$BUILD/adapt_gate.py" \
  bash "$BUILD/run_fwof39_compat.sh" | tee "$BUILD/fwof39.out"
grep -Fq 'FWOF39_LIFECYCLE_RETIREMENT_GATE PASS' "$BUILD/fwof39.out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fwof39.out"
echo 'F_WOF_PP03_FWO39_CURRENT_CONTRACT_PRESERVATION=PASS'
echo 'F_WOF_PP03_FWO38_FWO39_CURRENT_CONTRACT_PRESERVATION_GATE PASS'
