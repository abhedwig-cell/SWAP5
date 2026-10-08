#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Keep the immutable F-WOF38 donor untouched. Add only the new optional
# lifecycle dependency and independent owner persistence assertions.
python3 - "$ROOT/tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh" "$BUILD/runner.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
original='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
replacement='ROOT="${CROP_FKT_ROOT:?}"'
assert s.count(original)==1
s=s.replace(original,replacement,1)
anchor='  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90\n  src/runtime/mod_fmr_wofost_crop_transaction.f90'
extra='''  src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
  src/crop/mod_crop_preparation_sowing_preflight.f90
  src/crop/mod_crop_germination_preflight.f90
  src/crop/mod_crop_lifecycle_daily_composition.f90
  src/crop/mod_crop_lifecycle_continuation.f90
  src/runtime/mod_fmr_wofost_crop_transaction.f90'''
assert s.count(anchor)==1
s=s.replace(anchor,extra,1)
# The generated F-WOF38 test fixture is modified only in this temporary
# wrapper. The frozen historical test and original runner remain unchanged.
hook=r"""python3 - "$BUILD/fwof38_atomic.f90" <<'PY_LIFE'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
def replace_one(a,b):
    global s
    assert s.count(a)==1, (a[:80],s.count(a))
    s=s.replace(a,b,1)
replace_one('  use mod_fmr_wofost_crop_transaction\\n',
            '  use mod_fmr_wofost_crop_transaction\\n  use mod_crop_lifecycle_continuation\\n')
replace_one('  integer(kind=8) :: crop_revision_before\\n',
'''  integer(kind=8) :: crop_revision_before
  type(crop_lifecycle_continuation_t) :: lifecycle_seed, lifecycle_replayed
  type(fmr_wofost_crop_transaction_state_t) :: lifecycle_state, lifecycle_restored
  type(fmr_wofost_crop_transaction_persistence_t) :: lifecycle_view
  logical :: lifecycle_available, lifecycle_exported, lifecycle_reconstructed
  integer :: lifecycle_persistence_status
''')
anchor="  call require(crop_initial_state%ready(), 'F-WOF38 crop transaction state ready')\\n"
replacement="""  call require(crop_initial_state%ready(), 'F-WOF38 crop transaction state ready')
  ! Independent opt-in lifecycle state exercises physical F-KT owner
  ! persistence, without mutating the primary frozen crop fixture.
  lifecycle_seed%valid=.true.
  lifecycle_seed%crop_identity=71
  lifecycle_seed%revision=4
  lifecycle_seed%prepared=.true.
  lifecycle_seed%sown=.true.
  lifecycle_seed%germinated=.true.
  lifecycle_seed%germination_temperature_sum=12.5_real64
  call initialize_fmr_wofost_crop_transaction_state(seed, lifecycle_state, crop_status, &
       lifecycle_initial=lifecycle_seed)
  call require(crop_status == FMR_WOF38_OK .and. lifecycle_state%ready(), &
       'lifecycle owner init')
  call export_fmr_wofost_crop_transaction_persistence(lifecycle_state,lifecycle_view, &
       lifecycle_exported,lifecycle_persistence_status)
  call require(lifecycle_exported .and. lifecycle_persistence_status == FMR_WOFOST_CROP_PERSISTENCE_OK, &
       'lifecycle owner persistence export')
  call require(lifecycle_view%lifecycle_present .and. lifecycle_view%lifecycle%ready(), &
       'lifecycle continuation in persistence view')
  call reconstruct_fmr_wofost_crop_transaction_from_persistence(lifecycle_view,lifecycle_restored, &
       lifecycle_reconstructed,lifecycle_persistence_status)
  call require(lifecycle_reconstructed .and. lifecycle_persistence_status == FMR_WOFOST_CROP_PERSISTENCE_OK, &
       'lifecycle owner persistence reconstruction')
  call lifecycle_restored%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)
  call require(lifecycle_available .and. lifecycle_replayed%revision==lifecycle_seed%revision &
       .and. lifecycle_replayed%crop_identity==lifecycle_seed%crop_identity &
       .and. lifecycle_replayed%germination_temperature_sum==lifecycle_seed%germination_temperature_sum, &
       'lifecycle owner persisted restart equivalence')
  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_PERSISTENCE_REPLAY=PASS'
"""
replace_one(anchor,replacement)
p.write_text(s)
PY_LIFE
"""
assert s.count('COMMON=(-std=f2008')==1
s=s.replace('COMMON=(-std=f2008',hook+'\nCOMMON=(-std=f2008',1)
Path(sys.argv[2]).write_text(s)
PY
CROP_FKT_ROOT="$ROOT" bash "$BUILD/runner.sh" > "$BUILD/out"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' "$BUILD/out"
grep -Fq 'SW431_CROP_FKT_LIFECYCLE_PERSISTENCE_REPLAY=PASS' "$BUILD/out"
echo 'SW431_CROP_LIFECYCLE_FKT_OWNER_PRESERVATION=PASS'
