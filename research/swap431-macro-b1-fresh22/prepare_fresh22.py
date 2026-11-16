"""One localized current-operator experiment; no tolerance or physical changes."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-limit21'
patch=[]
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
def put(name,s,old):
 (R/name).write_text(s)
 patch.append(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='LIMIT21/'+name,tofile='FRESH22/'+name)))
s=(R/'diag_state.f90').read_text();old=s
s=s.replace('target=attempts==38.or.(attempts>=50.and.attempts<=52)','target=attempts==38')
needle='end subroutine\nsubroutine outcome'
assert needle in s
s=s.replace(needle,'''end subroutine
subroutine finish_target()
integer::o
close(u);close(v);close(node_u);close(op_u);close(raw_u);close(limit_u)
open(newunit=o,file='outcome.txt',status='replace')
write(o,*) 'FRESH22_TARGET_HEAD_RETURN',attempts,kind,iterations,residual,maxres,worst
close(o)
end subroutine
subroutine outcome''',1)
put('diag_state.f90',s,old)
s=(R/'head_diag.f90').read_text();old=s
needle='      call diag_log(1)\n      njac=njac+1'
assert needle in s
s=s.replace(needle,'''! FRESH22 localized candidate: current operator for original target head only.
      if(target) flunsatok(1:3)=.false.
'''+needle,1)
needle=" inquire(file='active.marker',exist=active)"
assert needle in s;s=s.replace(needle,needle+'\n if(target) active=.true.',1)
put('head_diag.f90',s,old)
s=(R/'soilwater_native.f90').read_text();old=s
s=s.replace('use DIAG19,only:head_start,head_end','use DIAG19,only:head_start,head_end,attempts,finish_target',1)
needle=' call head_start()\n call headcalc\n call head_end()'
assert needle in s;s=s.replace(needle,''' call head_start()
 if(attempts==38) then
  call inventory_dump('target_begin')
  call native09_dump('context_target_begin')
 end if
 call headcalc
 call head_end()
 if(attempts==38) then
  call inventory_dump('target_return')
  call native09_dump('context_target_return')
  call finish_target()
  if(budget_open) close(budget_unit)
  stop 0
 end if''',1)
put('soilwater_native.f90',s,old)
s=(P/'limit21.py').read_text().replace('swap431-limit21-work','swap431-fresh22-work')
(R/'fresh22.py').write_text(s)
(R/'candidate_and_driver.patch').write_text('\n'.join(patch))
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='32daab024721a8b1f66b8417e771e809882beb0b',routes=['O0 native to original attempt38','O2 native to original attempt38'],selection='Only first node52 failure: begin35797.070666666681 dt0.0013333333333333333',candidate='Before every Jacobian in target head, reset freeze flags; current MACRORATE rates and existing derivatives. No exact constrained-Jacobian claim.',stop='After target head returns, before host commit or rollback; hard20s subprocess timeout',no_campaign=True,physical_equations_tolerances_dt_retry_policy_changes=False),indent=2)+'\n')
