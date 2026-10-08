#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/fwof/.run_swap431_potential_shadow_tx_$$.sh"
OUT="${TMPDIR:-/tmp}/swap431-potential-shadow-tx-$$.out"
trap 'rm -f "$TMP" "$OUT"' EXIT

cp "$ROOT/tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh" "$TMP"

# Reconcile F-WOF38's frozen source compilation list with the current
# canonical directional-publication dependency, without editing its owner runner.
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
anchor="  src/transaction/mod_transaction_reference.f90\n  src/runtime/mod_canonical_contracts.f90\n"
replacement=("  src/transaction/mod_transaction_reference.f90\n"
 "  src/solver/mod_soil_water_accepted_step_direction_contract.f90\n"
 "  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90\n"
 "  src/transaction/mod_accepted_trajectory_directional_publication.f90\n"
 "  src/runtime/mod_canonical_contracts.f90\n")
if s.count(anchor)!=1:
    raise SystemExit("F-WOF38 dependency anchor changed")
s=s.replace(anchor,replacement,1)
# The legacy runner redirects assertions into a temporary file and deletes it
# on exit; retain failure diagnostics by printing them before exit.
output_anchor="./test > output.txt 2>&1"
if s.count(output_anchor)!=1:
    raise SystemExit("F-WOF38 test-output anchor changed")
s=s.replace(output_anchor,"./test > output.txt 2>&1 || { cat output.txt >&2; exit 1; }",1)
old="-Wall -Wextra -Werror -fcheck=all"
if s.count(old)!=1:
    raise SystemExit("F-WOF38 compiler flags changed")
s=s.replace(old,"-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all",1)
# Resolve the transitive modules in the frozen F-WOF38 source list. The
# legacy script predated several new canonical state/crop modules.
start=s.index("SOURCES=(\n")
end=s.index("\n)\n",start)+3
if start<0 or end<3:
    raise SystemExit("F-WOF38 source-list boundary changed")
import re
root=p.resolve().parents[2]
module_paths={}
for source in sorted((root/"src").rglob("*.f90")):
    for name in re.findall(r"^\s*module\s+(?!procedure\b)(\w+)",source.read_text(),re.M|re.I):
        if name.lower() in module_paths:
            raise SystemExit("duplicate module "+name)
        module_paths[name.lower()]=source
original=[root/line.strip() for line in s[start:end].splitlines()[1:-1]]
ordered=[]
visited=set()
active=set()
intrinsic={"iso_fortran_env","iso_c_binding","ieee_arithmetic","omp_lib"}
def visit(path):
    path=Path(path)
    if path in visited: return
    if path in active: raise SystemExit("cycle "+str(path))
    active.add(path)
    for name in re.findall(r"^\s*use\s*(?:,\s*(?:non_intrinsic|intrinsic)\s*)?(?:::)?\s*(\w+)",path.read_text(),re.M|re.I):
        key=name.lower()
        if key in module_paths: visit(module_paths[key])
        elif key not in intrinsic: raise SystemExit("unresolved "+name+" in "+str(path))
    active.remove(path)
    visited.add(path)
    ordered.append(path.relative_to(root).as_posix())
for source in original: visit(source)
s=s[:start]+"SOURCES=(\n"+"\n".join("  "+name for name in ordered)+"\n)\n"+s[end:]
p.write_text(s)
PY


python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

# The frozen F-WOF38 generated program does not import this newer
# optional potential-shadow type, even though the implementation is compiled.
use_anchor="  use mod_fmr_wofost_crop_transaction\n"
use_insert=use_anchor+"  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t\n"
if s.count(use_anchor)!=1:
    raise SystemExit(f'potential-shadow type import anchor count={s.count(use_anchor)}')
s=s.replace(use_anchor,use_insert,1)

# Attribute failure of the historical physical donor before the shadow
# candidate: do not alter numerical tolerances or completion assertions.
physical_anchor="    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-WOF38 physical trial completes')"
physical_probe=("    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) then\\n"
 "      print *, 'SW431_PHYSICAL_DONOR_STATUS=',result%status,' COMPLETED=',result%completed\\n"
 "    end if\\n"+physical_anchor)
if s.count(physical_anchor)!=1:
    raise SystemExit("F-WOF38 physical donor assert anchor changed")
s=s.replace(physical_anchor,physical_probe,1)

# Add observation variables to the generated Fortran declaration payload.
anchor="  integer(kind=8) :: crop_revision_before\n"
insert=anchor+"""  type(wofost_potential_shadow_state_t) :: shadow_snapshot, restored_shadow
  type(fmr_wofost_root_growth_carrier_t) :: root_growth_snapshot, restored_growth
  type(fmr_wofost_crop_transaction_persistence_t) :: potential_persistence
  type(fmr_wofost_crop_transaction_state_t) :: restored_potential_state
  type(wofost_crop_owner_state_t) :: restored_potential_owner
  logical :: shadow_available, growth_available, persistence_ok, reconstructed_ok, restored_available
  integer :: persistence_status
"""
if s.count(anchor)!=1:
    raise SystemExit(f'decl anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Enable the optional potential shadow for the exact same F-WOF38 transaction.
old="""  call construct_fmr_wofost_crop_transaction_parameters(bundle, update_parameters, 0.005_real64, 0.002_real64, &
       crop_parameters, crop_status)
"""
new="""  call construct_fmr_wofost_crop_transaction_parameters(bundle, update_parameters, 0.005_real64, 0.002_real64, &
       crop_parameters, crop_status, enable_potential_shadow=.true., potential_attainable_multiplier=0.5_real64)
"""
if s.count(old)!=1:
    raise SystemExit(f'parameter anchor count={s.count(old)}')
s=s.replace(old,new,1)

old="""  call initialize_fmr_wofost_crop_transaction_state(seed, crop_initial_state, crop_status)
"""
new="""  call initialize_fmr_wofost_crop_transaction_state(seed, crop_initial_state, crop_status, &
       enable_potential_shadow=.true.)
"""
if s.count(old)!=1:
    raise SystemExit(f'init anchor count={s.count(old)}')
s=s.replace(old,new,1)

# Precommit: shadow is present but root-growth carrier is intentionally unavailable.
anchor="""    call require(.not. tx%receipt_ready(), 'F-WOF38 no committed event receipt before publication')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 potential shadow enabled before publication')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 precommit shadow snapshot available')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(.not. growth_available, 'SW431 precommit root growth unavailable before accepted event')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'precommit anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Candidate from accepted event: receipt + shadow + actual/potential gross root growth are one candidate.
anchor="""    call require(tx%consumed_event(event_identity), 'F-WOF38 first candidate consumes matching event')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 candidate potential shadow enabled')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 candidate shadow snapshot available')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(growth_available .and. root_growth_snapshot%ready(), 'SW431 candidate GRRT/GRRTPOT carrier ready')
    call require(root_growth_snapshot%actual_gross_root_growth >= 0.0_real64, 'SW431 candidate GRRT nonnegative')
    call require(root_growth_snapshot%potential_gross_root_growth >= 0.0_real64, 'SW431 candidate GRRTPOT nonnegative')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'candidate anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Rollback must leave the committed shadow and carrier at pre-event state.
anchor="""    call require(.not. tx%receipt_ready(), 'F-WOF38 rollback leaves receipt uncommitted')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 rollback preserves enabled shadow')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 rollback preserves pre-event shadow')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(.not. growth_available, 'SW431 rollback leaves GRRT/GRRTPOT unpublished')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'rollback anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Commit publishes owner, shadow, carrier and receipt in the one existing revision.
anchor="""    call require(tx%consumed_event(event_identity), 'F-WOF38 committed receipt matches event')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 committed shadow enabled')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 committed shadow available')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(growth_available .and. root_growth_snapshot%ready(), 'SW431 committed GRRT/GRRTPOT carrier available')
    call export_fmr_wofost_crop_transaction_persistence(tx,potential_persistence,persistence_ok,persistence_status)
    call require(persistence_ok .and. persistence_status==FMR_WOFOST_CROP_PERSISTENCE_OK, &
         'SW431 post-event potential persistence export')
    call reconstruct_fmr_wofost_crop_transaction_from_persistence(potential_persistence,restored_potential_state, &
         reconstructed_ok,persistence_status)
    call require(reconstructed_ok .and. persistence_status==FMR_WOFOST_CROP_PERSISTENCE_OK, &
         'SW431 post-event potential persistence reconstruct')
    call restored_potential_state%snapshot_owner(restored_potential_owner,restored_available)
    call require(restored_available .and. same_owner(restored_potential_owner,crop_snapshot_owner), &
         'SW431 restored actual owner exact')
    call restored_potential_state%snapshot_potential_shadow(restored_shadow,restored_available)
    call require(restored_available .and. restored_shadow%active, 'SW431 restored potential shadow available')
    call restored_potential_state%snapshot_root_growth(restored_growth,restored_available)
    call require(restored_available .and. restored_growth%ready(), 'SW431 restored GRRT/GRRTPOT available')
    call require(bitwise_equal(restored_growth%actual_gross_root_growth,root_growth_snapshot%actual_gross_root_growth), &
         'SW431 restored GRRT exact')
    call require(bitwise_equal(restored_growth%potential_gross_root_growth,root_growth_snapshot%potential_gross_root_growth), &
         'SW431 restored GRRTPOT exact')
    call require(restored_potential_state%receipt_ready() .and. restored_potential_state%consumed_event(event_identity), &
         'SW431 restored receipt exact')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'commit anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Failed crop evolution must publish neither shadow nor root-growth observation.
anchor="""    call require(.not. tx%receipt_ready(), 'F-WOF38 crop failure receipt unchanged')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 failed trial keeps configured shadow')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 failed trial keeps pre-event shadow')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(.not. growth_available, 'SW431 failed trial publishes no GRRT/GRRTPOT')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'failure anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Add visible markers.
anchor="""  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'
"""
insert="""  print '(a)', 'SW431_POTENTIAL_SHADOW_POST_EVENT_RESTART=PASS'
  print '(a)', 'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS'
  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'
"""
if s.count(anchor)!=1:
    raise SystemExit(f'final marker anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

marker_anchor="""    'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' \
"""
if marker_anchor in s:
    s=s.replace(marker_anchor,"""    'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS' \
    'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' \
""",1)

p.write_text(s,encoding='utf-8')
PY

bash "$TMP" | tee "$OUT"
grep -Fq 'SW431_POTENTIAL_SHADOW_POST_EVENT_RESTART=PASS' "$OUT"
grep -Fq 'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O2=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$OUT"
echo 'SW431_POTENTIAL_SHADOW_TRANSACTION_GATE PASS'
