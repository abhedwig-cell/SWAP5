"""Prepare additive instrumentation; no model runs."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-next18'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R.parent/'swap431-macro-b1-stagnation05/headcalc_inventory.f90').read_text()
old=s
s=s.replace('   implicit none','   use DIAG19,only:nvec,njac,nrate,nderiv,nback,nfresh,outcome\n   implicit none',1)
for needle,insert in [('   call vector_F(1, hgrad)','   nvec=nvec+1'),('      call jacobian_F()','      njac=njac+1'),('         iBackTr = iBackTr + 1','         nback=nback+1'),('         call vector_F(2, hgrad)','         nvec=nvec+1'),('         call vector_F(1,hgrad)','         nfresh=nfresh+1; nvec=nvec+1'),('         call MACROPORE(2)','         nrate=nrate+1'),('      call MACROPORE(3)','      nderiv=nderiv+1')]:
 assert needle in s;s=s.replace(needle,insert+'\n'+needle,1)
for kind in [0,4]:
 needle=f'   call unreduced_trace({kind})'
 assert needle in s
 s=s.replace(needle,f'   call outcome({kind},numbit,flnonconv,any(flnonconv1(1:NN)),any(flnonconv2(1:NN)),flnonconv3,fldecMPmbf,sum1,maxval(abs(F(1:NN))),maxloc(abs(F(1:NN)),dim=1))\n'+needle,1)
(R/'head_diag.f90').write_text(s)
(R/'head_instrumentation.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='STAGNATION05/headcalc_inventory.f90',tofile='DIAG19/head_diag.f90')))
p=R/'soilwater_native.f90';s=p.read_text();old=s
s=s.replace(' use variables,only:t1900\n',' use variables,only:t1900\n use DIAG19,only:start\n',1)
s=s.replace(' use_patch=true',' use_patch=true') # literal Fortran below
s=s.replace(' use_patch=.true.\n',' use_patch=.true.\n call start()\n',1)
s=s.replace('logical function retry07_driver() result(handled)','logical function retry07_driver() result(handled)\n use DIAG19,only:head_start,head_end')
s=s.replace('\n call headcalc\n','\n call head_start()\n call headcalc\n call head_end()\n',1)
s=s.replace('subroutine retry07_checkpoint()','subroutine retry07_checkpoint()\n use DIAG19,only:log_start,log_end,commit',1)
s=s.replace(' if(budget_open) then\n',' call log_start()\n if(budget_open) then\n',1)
needle='  if(mod(budget_count,128)==0) flush(budget_unit)\n end if\n'
assert needle in s;s=s.replace(needle,needle+' call log_end()\n if(commit()) then\n  if(budget_open) close(budget_unit)\n  stop 0\n end if\n',1)
p.write_text(s)
(R/'driver_instrumentation.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='NEXT18/soilwater_native.f90',tofile='DIAG19/soilwater_native.f90')))
s=(P/'next18.py').read_text().replace('swap431-next18-work','swap431-diag19-work')
s=s.replace("[('integral_canopy','integral'),","[('diag_state','diag19'),('head_diag','headcalc'),('integral_canopy','integral'),")
s=s.replace("R/'data'/opt/'PREFIX/midnight.end'","R.parent/'swap431-macro-b1-next18/data'/opt/'PREFIX/midnight.end'")
(R/'diag19.py').write_text(s)
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='1822cfd9e706379c4c62b2d802ea168e42e8a5ef',routes=['O0 native Jan3','O2 native Jan3'],stop='7000 committed steps or16 measured seconds, hard20s subprocess timeout',changes='Additive counters and clock calls only; same original contexts, physical code, acceptance and retry policy',no_campaign=True),indent=2)+'\n')
