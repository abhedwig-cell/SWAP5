"""Continue exactly the qualified JAC24 head to its real original host commit."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-jac24'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R/'soilwater_native.f90').read_text();old=s
s=s.replace("  call native09_dump('context_target_begin')","  call native09_dump('context_target_begin')\n  call ledger12_dump('ledger_target_begin')",1)
needle="  call native09_dump('context_target_return')\n  call finish_target()\n  if(budget_open) close(budget_unit)\n  stop 0"
assert needle in s;s=s.replace(needle,"  call native09_dump('context_target_return')\n  call ledger12_dump('ledger_target_return')\n  if(fldecdt.or.FlDecMpRat) error stop 'COMMIT25 selected head refused before commit'",1)
s=s.replace('use DIAG19,only:log_start,log_end,commit','use DIAG19,only:log_start,log_end,commit,attempts,finish_target',1)
needle='  if(budget_open) close(budget_unit)\n  stop 0\n end if\nend subroutine\nsubroutine day11_boundary()'
assert needle in s
s=s.replace(needle,'''  if(budget_open) close(budget_unit)
  stop 0
 end if
 if(attempts==38) then
  call inventory_dump('committed')
  call native09_dump('context_committed')
  call ledger12_dump('ledger_committed')
  call finish_target()
  if(budget_open) close(budget_unit)
  open(newunit=u,file='outcome.txt',status='replace')
  write(u,*) 'COMMIT25_HOST_COMMITTED',t1900,accepted_dt,dt,budget_count
  close(u)
  stop 0
 end if
end subroutine
subroutine day11_boundary()''',1)
(R/'soilwater_native.f90').write_text(s)
(R/'driver_only.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='JAC24/soilwater_native.f90',tofile='COMMIT25/soilwater_native.f90')))
s=(P/'jac24.py').read_text().replace('swap431-jac24-work','swap431-commit25-work')
(R/'commit25.py').write_text(s)
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='426b8d31a92a23b9f6b58dd58b96f67f220cd213',routes=['O0 same original native step to hostcommit','O2 same original native step to hostcommit'],scope='Target38 head, original SoilWater3/macrostate/integral3/TimeControl3, independent inventories and primitive accepted-step budget',stop='After target hostcommit, before next step; hard20s perroute',candidate_changes=False,driver_changes_only=True,no_campaign=True),indent=2)+'\n')
