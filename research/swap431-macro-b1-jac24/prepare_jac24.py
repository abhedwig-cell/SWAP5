"""One bounded analytic rank-one factor correction for original target head38."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-sense23'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
patch=[]
def put(n,s,old):
 (R/n).write_text(s);patch.append(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='SENSE23/'+n,tofile='JAC24/'+n)))
s=(R/'macrorate_node.f90').read_text();old=s
needle='      integer::snap23_unit,snap23_mode'
assert needle in s
s=s.replace(needle,needle+'''
      integer::n24,j24,l24
      real(8)::u24(macp),v24(macp),d24(macp),meta24(12)
      real(8)::f24,rho24,g24,den24,dh24,hm24
''',1)
needle='      entry sense23_rate_io'
pos=s.index(needle)
code='''      entry jac24_terms(n24,u24,v24,d24,meta24)
      u24=0d0;v24=0d0;d24=0d0;meta24=0d0
      if(n24/=numnod.or.swmbf/=1) return
      if(lim_in/=0d0.or.lim_frin/=1d0.or.FlwInTopExcesTot/=0d0) return
      if(FlwOutMtxUnsDmPot(3)/=0d0.or.FlwOutDmTot(3)<=0d0) return
      if(lim_min>=WaSrMpDm(3)) return
      if(FlwOutDmExces(3)/dt<=1d-7.or.FlwOutDmTot(3)<=FlwOutDmExces(3)) return
      j24=numnod
      do while(j24>1)
       if(h(j24)<0d0) exit
       j24=j24-1
      end do
      if(j24/=50.or.h(j24+1)<=0d0.or.ICpTpSatZon/=50) return
      den24=h(j24+1)-h(j24)
      g24=z(j24+1)+h(j24+1)/den24*(z(j24)-z(j24+1))
      if(abs(g24-GwlFlCpZo)>1d-9) error stop 'JAC24 outside selected GWL interpolation'
      f24=max(0d0,1d0-FlwOutDmExces(3)/FlwOutDmTot(3))
      rho24=VlMpDmCp(3,ICpTpSatZon)/dz(ICpTpSatZon)
      do l24=1,numnod
       u24(l24)=-FlwOutMtxSatDmCpPot(3,l24)/dt
       if(FlwOutMtxSatDmCpPot(3,l24)>0d0) then
        hm24=max(0d0,ZWaLevDm(3)-z(l24))
        dh24=hm24-h(l24)
        if(dh24<=0d0) error stop 'JAC24 outgoing potential head contract'
        d24(l24)=-FlwOutMtxSatDmCpPot(3,l24)/dh24
       end if
      end do
      v24=-f24*d24/FlwOutDmTot(3)
      v24(j24)=v24(j24)-rho24/FlwOutDmTot(3)*(z(j24)-z(j24+1))*h(j24+1)/den24**2
      v24(j24+1)=v24(j24+1)+rho24/FlwOutDmTot(3)*(z(j24)-z(j24+1))*h(j24)/den24**2
      d24=f24*d24/dt
      meta24=[1d0,FlwOutDmTot(3),FlwOutDmExces(3),f24,rho24,GwlFlCpZo,lim_min, &
              WaSrMpDm(3),dble(j24),h(j24),h(j24+1),dt]
      return
'''
s=s[:pos]+code+s[pos:]
put('macrorate_node.f90',s,old)
s=(R/'head_diag.f90').read_text();old=s
s=s.replace('      if(target.and.numbit==30) call sense23_probe()','      if(target.and.numbit==1) call jac24_calibrate()',1)
needle='      call tridag(NN, dFdhU, dFdhM, dFdhL, F, difh, ierror)'
assert needle in s;s=s.replace(needle,'''      if(target) then
       call jac24_solve(NN,dFdhU,dFdhM,dFdhL,F,difh,ierror)
      else
'''+needle+'''
      end if''',1)
put('head_diag.f90',s,old)
s=(P/'sense23.py').read_text().replace('swap431-sense23-work','swap431-jac24-work')
needle="('probe_state','probe23'),('ledger_state','ledger12'),"
assert needle in s;s=s.replace(needle,"('probe_state','probe23'),('jac_update','jac24'),('ledger_state','ledger12'),",1)
needle=" if mode=='RESUME':shutil.copy2("
pos=s.index(needle)
s=s[:pos]+''' cal=R.parent/'swap431-macro-b1-sense23/data'/opt/'RESUME_IEEE/trial23_base.bin'
 assert m.sha(cal)=='aec5d4383614499853fe809018b53844d54d852a205a77f45c28ea28378f62c3'
 shutil.copy2(cal,c/'calibration_base.bin')
'''+s[pos:]
(R/'jac24.py').write_text(s)
(R/'candidate.patch').write_text('\n'.join(patch))
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='340a19b4f0ff09115ceafc39a39777ba1ca1250a',routes=['O0 same native target38','O2 same native target38'],candidate='One analytic rank1 domain3 outflow factor derivative with GWL/minimum and total potential outflow dependence, only selected partial zero-inflow branch; current operator retained',linear_solve='Original tridiagonal inverse plus Sherman Morrison, no dense Jacobian',stop='After target38 head return, before next host retry/commit; timeout20s',unchanged='Physical providers, branch thresholds, residual criteria, maxit30, dt, reduction policy and native input',no_campaign=True),indent=2)+'\n')
