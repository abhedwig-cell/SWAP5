"""Select existing original B; no forced refusal, no search over contexts."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-commit25'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
patch=[]
def put(n,s,old):
 (R/n).write_text(s);patch.append(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='COMMIT25/'+n,tofile='REJECT26/'+n)))
s=(R/'diag_state.f90').read_text();old=s
s=s.replace('logical,save::target=.false.','logical,save::target=.false.,qualification_active=.false.',1)
s=s.replace('target=attempts==38','target=qualification_active',1)
put('diag_state.f90',s,old)
s=(R/'head_diag.f90').read_text();old=s
s=s.replace('      if(target.and.numbit==1) call jac24_calibrate()','! REJECT26 retains the qualified analytic update; no repeated calibration replay.',1)
put('head_diag.f90',s,old)
s=(R/'soilwater_native.f90').read_text();old=s
s=s.replace("   logical,save :: budget_open=.false.,period_begin_done=.false.","   logical,save :: budget_open=.false.,period_begin_done=.false.,reject26_pending=.false.",1)
a=s.index('subroutine prefix14_start()');b=s.index('subroutine day11_boundary()',a)
driver='''subroutine prefix14_start()
 use DIAG19,only:start
 use CONTRACT06_CONTROL,only:use_patch
 use variables,only:t1900
 implicit none
 use_patch=.false.
 call start()
 open(newunit=budget_unit,file='step_budget.txt',status='replace')
 budget_open=.true.;budget_count=0
end subroutine

logical function retry07_driver() result(handled)
 use DIAG19,only:head_start,head_end,qualification_active
 use CONTRACT06_CONTROL,only:use_patch
 use variables,only:t1900,dt,fldecdt
 use MOD_swap_mp,only:IDecMpRat,FlDecMpRat
 use MOD_macropore,only:MacroStateVar
 use MOD_drain,only:drain
 implicit none
 character(24)::mode
 character(60)::label
 integer::i,u
 handled=.true.
 if(abs(t1900-35796.9513533331d0)>1d-9.or.abs(dt-2d-5)>1d-14) then
  call headcalc
  return
 end if
 if(IDecMpRat/=0) error stop 'REJECT26 original B scope mismatch'
 call get_environment_variable('DAY10_MODE',mode)
 call inventory_dump('origin')
 call native09_dump('context_origin')
 call ledger12_dump('ledger_origin')
 use_patch=.true.;qualification_active=.true.
 if(trim(mode)=='DIRECT') then
  fldecdt=.true.
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end if
 do i=1,4
  write(label,'(a,i0)') 'begin_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  accepted_dt=dt
  call head_start()
  call headcalc
  call head_end()
  write(label,'(a,i0)') 'returned_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  if(.not.fldecdt.and..not.FlDecMpRat) then
   if(IDecMpRat/=0) error stop 'REJECT26 scaled acceptance excluded'
   call inventory_dump('accepted_return')
   call native09_dump('context_accepted_return')
   call ledger12_dump('ledger_accepted_return')
   reject26_pending=.true.
   return
  end if
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
  write(label,'(a,i0)') 'rollback_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  if(FlDecMpRat.or.IDecMpRat/=0.or.i==4) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'REJECT26_NO_UNSCALED_ACCEPT_WITHIN_BOUND',i,dt
   close(u);stop 0
  end if
  if(.not.fldecdt) error stop 'REJECT26 unclassified refusal'
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
end function

subroutine retry07_checkpoint()
 use DIAG19,only:attempts,finish_target
 use variables,only:t1900,dt,qbot,qrot,runon,epd,reva,runots
 use MOD_meteo,only:graidt,nraidt
 use MOD_irrigation,only:gird,nird,qssdi
 use MOD_drain,only:qdra,nrlevs
 use MOD_macropore,only:QOutDrRapCp,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,FrReduQ,NumDm
 use MOD_grid,only:numnod
 use plant_interface,only:crsflx_out
 implicit none
 integer::u
 if(.not.reject26_pending) return
 write(budget_unit,*) t1900,accepted_dt,graidt,gird,runon,crsflx_out,epd,reva,sum(qrot(1:numnod)),qbot,sum(qdra(1:nrlevs,1:numnod)),sum(qssdi(1:numnod)),sum(QOutDrRapCp(1:numnod)),runots,nraidt,nird,FrReduQ, &
  QInTopLatDm(1:NumDm),QInTopVrtDm(1:NumDm),sum(QExcMtxDmCp(1:NumDm,1:numnod),dim=2)
 call inventory_dump('committed')
 call native09_dump('context_committed')
 call ledger12_dump('ledger_committed')
 call finish_target()
 close(budget_unit)
 open(newunit=u,file='outcome.txt',status='replace')
 write(u,*) 'REJECT26_HOST_COMMITTED',attempts,t1900,accepted_dt,dt
 close(u)
 stop 0
end subroutine
'''
s=s[:a]+driver+s[b:]
put('soilwater_native.f90',s,old)
s=(P/'commit25.py').read_text().replace('swap431-commit25-work','swap431-reject26-work')
(R/'reject26.py').write_text(s)
(R/'scope_and_driver.patch').write_text('\n'.join(patch))
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='870ffbb3f78ddb51b0128be8779169dc8a4da318',selection='Existing original RETRY07 B35796.9513533331 dt2e-5; unchanged original prefix, Darcy/currentJac candidate on only at B',routes='O2 TRIAL first; if genuine rejection compare DIRECT and O0 counterparts',candidate='Same current macro/rank1 solver, qualified activation guards; no forced refusal or tolerance change',bounds='Up to4 actual original retries, stop on scaled request, otherwise first accepted hostcommit; timeout20 perroute',no_campaign=True),indent=2)+'\n')
