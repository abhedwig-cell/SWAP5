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
#    which newer gfortran reports under -Wcompare-reals. The legacy gate had
#    -Werror globally, so that later compiler hygiene warning prevents the gate
#    from reaching its scientific assertions even though gate semantics did not
#    change.
#
# PP03 therefore materializes temporary, hash-bound copies of the legacy gates.
# Every legacy scientific assertion and O0/O2 identity check remains intact.
# Only the historical F-WOF34 fixture generator gets the explicit mass metadata
# now required by F-KT18, and two compiler-only warning classes are not promoted
# to errors. No production source or immutable legacy gate is modified.

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

# Adapt the immutable F-WOF34 module while it is still a Python string inside
# the original F-WOF38 materializer. This avoids coupling to either script's
# private temporary BUILD directory.
old_materialize = "f34_module = f34.split(marker, 1)[0].rstrip() + '\\n\\n'\n"
new_materialize = r'''f34_module = f34.split(marker, 1)[0].rstrip() + '\n\n'
pp03_replacements = [
    (
        '  use, intrinsic :: iso_fortran_env, only: real64\n',
        '  use, intrinsic :: iso_fortran_env, only: real64, int64\n',
    ),
    (
        '  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t\n',
        '  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE\n',
    ),
    (
        '    procedure :: temporal_error => fwof34_temporal_error\n',
        '    procedure :: temporal_error => fwof34_temporal_error\n'
        '    procedure :: storage_accounting_status => fwof34_pp03_storage_accounting_status\n',
    ),
    (
        '    outcome%mass_in = transfer_mass\n    outcome%nonlinear_iterations = 1\n',
        '    outcome%mass_in = transfer_mass\n'
        '    outcome%mass_accounting_complete = .true.\n'
        '    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE\n'
        '    outcome%nonlinear_iterations = 1\n',
    ),
]
for old_pp03, new_pp03 in pp03_replacements:
    if f34_module.count(old_pp03) != 1:
        raise SystemExit('F-WOF-PP03 historical F-WOF34 fixture shape changed')
    f34_module = f34_module.replace(old_pp03, new_pp03, 1)
pp03_end = '\nend module mod_fwof34_test_model\n'
if f34_module.count(pp03_end) != 1:
    raise SystemExit('F-WOF-PP03 cannot locate F-WOF34 module end')
pp03_accounting = r"""

  subroutine fwof34_pp03_storage_accounting_status(self, state, complete, missing_mask)
    class(fwof34_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) then
      complete = .false.
      missing_mask = not(TX_MASS_MISSING_NONE)
      return
    end if
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fwof34_pp03_storage_accounting_status
"""
f34_module = f34_module.replace(pp03_end, pp03_accounting + pp03_end, 1)
print('F_WOF_PP03_FWO34_CURRENT_MASS_CONTRACT_ADAPTED=PASS')
'''
if s.count(old_materialize) != 1:
    raise SystemExit('PP03 preservation F-WOF34 materialization anchor mismatch')
s = s.replace(old_materialize, new_materialize, 1)

out_path.write_text(s, encoding='utf-8')
PY

python3 "$BUILD/adapt_gate.py" "$FWO38" "$BUILD/run_fwof38_compat.sh" pp03
chmod +x "$BUILD/run_fwof38_compat.sh"
FWOF_PP03_ROOT="$ROOT" bash "$BUILD/run_fwof38_compat.sh" | tee "$BUILD/fwof38.out"
grep -Fq 'F_WOF_PP03_FWO34_CURRENT_MASS_CONTRACT_ADAPTED=PASS' "$BUILD/fwof38.out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' "$BUILD/fwof38.out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fwof38.out"
echo 'F_WOF_PP03_FWO38_CURRENT_CONTRACT_PRESERVATION=PASS'

# F-WOF39 deliberately derives from the exact immutable F-WOF38 donor and
# verifies its hash. Keep that mechanism intact; adapt only its generated
# derived runtime copy using exactly the same compatibility transformer.
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
grep -Fq 'F_WOF_PP03_FWO34_CURRENT_MASS_CONTRACT_ADAPTED=PASS' "$BUILD/fwof39.out"
grep -Fq 'FWOF39_LIFECYCLE_RETIREMENT_GATE PASS' "$BUILD/fwof39.out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fwof39.out"
echo 'F_WOF_PP03_FWO39_CURRENT_CONTRACT_PRESERVATION=PASS'
echo 'F_WOF_PP03_FWO38_FWO39_CURRENT_CONTRACT_PRESERVATION_GATE PASS'
