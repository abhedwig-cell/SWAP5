from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-outside32'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R/'diag_state.f90').read_text().replace('logical,save::target=.false.,qualification_active=.false.','logical,save::target=.false.,qualification_active=.true.,detail33=.false.\ninteger,save::active_in_attempt=0,active_total=0')
s=s.replace('iter_index=0;macro_seq=0','iter_index=0;macro_seq=0;active_in_attempt=0')
s=s.replace('if(target) then','if(detail33) then')
s=s.replace('done=steps>=42.or.elapsed>=16d0','done=steps>=512.or.elapsed>=16d0.or.t1900>=35797.125d0')
a=s.index('if(done) then',s.index('logical function commit()'));b=s.index('spanhead=0;',a)
s=s[:a]+s[b:]
(R/'diag_state.f90').write_text(s)
s=(R/'head_diag.f90').read_text().replace('worst=0','worst=0')
s=s.replace('use DIAG19,only:nvec,njac,nrate,nderiv,nback,nfresh,outcome,target,attempts,iter_index,node_u,op_u','use DIAG19,only:nvec,njac,nrate,nderiv,nback,nfresh,outcome,target,attempts,iter_index,node_u,op_u,detail33')
assert s.count('if(.not.target) return')==2;s=s.replace('if(.not.target) return','if(.not.detail33) return')
s=s.replace('if(target) active=.true.','if(detail33) active=.true.')
(R/'head_diag.f90').write_text(s)
s=(R/'macrorate_node.f90').read_text().replace('point_delta\n','point_delta,detail33\n',1)
assert 'point_delta,detail33' in s
s=s.replace('integer,intent(in)::stage\n      real(8)::outfac','integer,intent(in)::stage\n      real(8)::outfac\n      if(.not.detail33) return')
s=s.replace('use DIAG19,only:target,attempts,iter_index,nvec,raw_u','use DIAG19,only:target,attempts,iter_index,nvec,raw_u,detail33')
s=s.replace('if(target.and.ic==52) then','if(detail33.and.ic==52) then')
(R/'macrorate_node.f90').write_text(s)
s=(R/'jac_update.f90').read_text().replace('use DIAG19,only:attempts,iter_index','use DIAG19,only:attempts,iter_index,active_in_attempt,active_total')
s=s.replace('if(meta(1)==1d0) then\n call tridag','if(meta(1)==1d0) then\n active_in_attempt=active_in_attempt+1;active_total=active_total+1\n call tridag')
s=s.replace('flush(trace_u)','if(mod(iter_index,16)==0) flush(trace_u)')
(R/'jac_update.f90').write_text(s)
s=(R/'soilwater_native.f90').read_text().replace('module MOD_SoilWater\n','module MOD_SoilWater\n   use MOD_arrays,only:macp,madm\n',1)
s=s.replace('   contains','   real(8),save::pre_theta(macp),pre_domain(madm),pre_pond,pre_canopy\n   integer,save::inventory_unit\n\n   contains',1)
a=s.index('subroutine prefix14_start()');b=s.index('subroutine day11_boundary()',a)
s=s[:a]+'''subroutine prefix14_start()
 use DIAG19,only:start,qualification_active
 use CONTRACT06_CONTROL,only:use_patch
 implicit none
 use_patch=.true.;qualification_active=.true.
 call start()
 open(newunit=budget_unit,file='step_budget.txt',status='replace')
 open(newunit=inventory_unit,file='inventory_trace.txt',status='replace')
 budget_open=.true.;budget_count=0
 call inventory_dump('initial')
 call native09_dump('context_initial')
 call ledger12_dump('ledger_initial')
end subroutine

subroutine capture33()
 use MOD_grid,only:numnod
 use MOD_macropore,only:NumDm,WaUnMpDm
 use variables,only:theta,pond,dt
 use plant_interface,only:sicact
 pre_theta(1:numnod)=theta(1:numnod)
 pre_domain(1:NumDm)=WaUnMpDm(1:NumDm)
 pre_pond=pond;pre_canopy=sicact;accepted_dt=dt
end subroutine

logical function retry07_driver() result(handled)
 use DIAG19,only:head_start,head_end,attempts,detail33,active_in_attempt
 use variables,only:t1900,dt,fldecdt
 use MOD_swap_mp,only:IDecMpRat,FlDecMpRat
 use MOD_macropore,only:MacroStateVar
 use MOD_drain,only:drain
 implicit none
 character(24)::mode
 character(80)::text
 character(60)::label
 integer::i,target_attempt,u
 handled=.true.
 call get_environment_variable('DAY10_MODE',mode)
 target_attempt=-1
 if(trim(mode)/='TRAJ') then
  call get_environment_variable('TRAJECTORY33_ATTEMPT',text)
  read(text,*) target_attempt
 end if
 if(attempts+1/=target_attempt) then
  detail33=.false.
  call capture33()
  call head_start()
  call headcalc
  call head_end()
  if(fldecdt.or.FlDecMpRat) then
   if(active_in_attempt>0) then
    call inventory_dump('refused')
    call native09_dump('context_refused')
    call ledger12_dump('ledger_refused')
    open(newunit=u,file='event33.txt',status='replace')
    write(u,*) attempts,t1900,dt,active_in_attempt,IDecMpRat,merge(1,0,fldecdt),merge(1,0,FlDecMpRat)
    close(u)
    call SoilWaterStateVar(2)
    call MacroStateVar(2)
    call inventory_dump('rollback')
    call native09_dump('context_rollback')
    call ledger12_dump('ledger_rollback')
    call finish33('FIRST_ACTIVE_REFUSAL')
   else if(FlDecMpRat.or.IDecMpRat/=0) then
    call finish33('SCALED_REQUEST_BEFORE_ACTIVE_REFUSAL')
   end if
  end if
  return
 end if
 if(IDecMpRat/=0) error stop 'TRAJECTORY33 scaled replay excluded'
 detail33=.true.
 call inventory_dump('origin')
 call native09_dump('context_origin')
 call ledger12_dump('ledger_origin')
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
  call capture33()
  call head_start()
  call headcalc
  call head_end()
  write(label,'(a,i0)') 'returned_',i
  call inventory_dump(trim(label))
  call native09_dump('context_'//trim(label))
  call ledger12_dump('ledger_'//trim(label))
  if(.not.fldecdt.and..not.FlDecMpRat) then
   if(IDecMpRat/=0) error stop 'TRAJECTORY33 scaled retry excluded'
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
  if(FlDecMpRat.or.IDecMpRat/=0.or.i==4) call finish33('NO_UNSCALED_RETRY_WITHIN_BOUND')
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
end function

subroutine retry07_checkpoint()
 use DIAG19,only:log_start,log_end,commit,attempts,steps,residual,active_in_attempt
 use variables,only:t1900,dt,qbot,qrot,runon,epd,reva,runots,theta,pond
 use MOD_meteo,only:graidt,nraidt
 use MOD_irrigation,only:gird,nird,qssdi
 use MOD_drain,only:qdra,nrlevs
 use MOD_macropore,only:QOutDrRapCp,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,FrReduQ,NumDm,WaUnMpDm
 use MOD_swap_mp,only:FrArMtrx
 use MOD_grid,only:numnod,dz
 use plant_interface,only:crsflx_out,sicact
 implicit none
 real(8)::dm,dp,dc,dx,external,domain_error(5)
 integer::j
 call log_start()
 write(budget_unit,*) t1900,accepted_dt,graidt,gird,runon,crsflx_out,epd,reva,sum(qrot(1:numnod)),qbot,sum(qdra(1:nrlevs,1:numnod)),sum(qssdi(1:numnod)),sum(QOutDrRapCp(1:numnod)),runots,nraidt,nird,FrReduQ, &
  QInTopLatDm(1:NumDm),QInTopVrtDm(1:NumDm),sum(QExcMtxDmCp(1:NumDm,1:numnod),dim=2)
 budget_count=budget_count+1
 dm=sum((theta(1:numnod)-pre_theta(1:numnod))*dz(1:numnod)*FrArMtrx(1:numnod))
 dx=sum(WaUnMpDm(1:NumDm)-pre_domain(1:NumDm));dp=pond-pre_pond;dc=sicact-pre_canopy
 external=accepted_dt*(graidt+gird+runon-crsflx_out-epd-reva-sum(qrot(1:numnod))+qbot-sum(qdra(1:nrlevs,1:numnod))+sum(qssdi(1:numnod))-sum(QOutDrRapCp(1:numnod)))-runots
 do j=1,NumDm
  domain_error(j)=WaUnMpDm(j)-pre_domain(j)-accepted_dt*(QInTopLatDm(j)+QInTopVrtDm(j)-sum(QExcMtxDmCp(j,1:numnod)))
  if(j==1) domain_error(j)=domain_error(j)+accepted_dt*sum(QOutDrRapCp(1:numnod))
 end do
 write(inventory_unit,*) budget_count,attempts,t1900,accepted_dt,dm,dx,dp,dc,external,dm+dx+dp+dc-external,residual*accepted_dt,FrReduQ,active_in_attempt,domain_error(1:NumDm)
 if(mod(budget_count,128)==0) then
  flush(budget_unit);flush(inventory_unit)
 end if
 call log_end()
 if(reject26_pending) then
  call inventory_dump('committed')
  call native09_dump('context_committed')
  call ledger12_dump('ledger_committed')
  call finish33('TARGET_RETRY_HOST_COMMITTED')
 end if
 if(commit()) call finish33('BOUNDED_CANDIDATE_TRAJECTORY')
end subroutine

subroutine finish33(reason)
 use DIAG19,only:attempts,steps,active_total,finish_target
 use variables,only:t1900,dt
 implicit none
 character(*),intent(in)::reason
 integer::u
 call inventory_dump('final')
 call native09_dump('context_final')
 call ledger12_dump('ledger_final')
 close(budget_unit);close(inventory_unit)
 call finish_target()
 open(newunit=u,file='outcome.txt',status='replace')
 write(u,*) trim(reason),steps,attempts,t1900,dt,active_total
 close(u)
 stop 0
end subroutine
''' +s[b:]
(R/'soilwater_native.f90').write_text(s)
runner=(P/'outside32.py').read_text().replace('swap431-outside32-work','swap431-trajectory33-work')
runner=runner.replace("['TRIAL','DIRECT']","['TRAJ','TRIAL','DIRECT']")
a=runner.index("env=os.environ.copy();");b=runner.index(' try:',a)
runner=runner[:a]+"env=os.environ.copy();env['DAY10_MODE']=mode;env['LEDGER12_REQUIRE']='1'\n if mode!='TRAJ':env['TRAJECTORY33_ATTEMPT']=str(json.loads((R/'EVENT_SELECTION.json').read_text())['attempt'])\n t=time.perf_counter()\n"+runner[b:]
(R/'trajectory33.py').write_text(runner)
patch=''
for p in P.glob('*.f90'):
 if p.read_bytes()!=(R/p.name).read_bytes():patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),(R/p.name).read_text().splitlines(True),fromfile='OUTSIDE32/'+p.name,tofile='TRAJECTORY33/'+p.name))
(R/'diagnostic_driver.patch').write_text(patch)
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='ac673db870237c576299ab9e0c7efaa3f1cf934b',remote_main='be481cfb40f953e337116ef4a6dc5bc3ef64d4f7',workstream='isolated SWAP431 B1 research',scope='ONE own candidate trajectory from same original native35797 boundary. O2/O0 each hard20s, internal stop512commits/16s/t>=35797.125, firstactive-refusal or firstscaledrequest, whicheverfirst. No broad campaign.',candidate='Unchanged current operator and analytic rank1, active on ALL heads frombegin. Candidate trajectory not original V1 prefix. Numerical formulas/guards/tolerances/MAXIT/dt/reductionrules unchanged.',changes='Five diagnostic/driver sources: compact logging separated from targetactivation, countactualrank1; runoriginalhostcontinuous steps; perstepstockintegrals; observationalstop. No shared format/physics change.',failure_contract='First actual exhausted refusal with active rank1 stops after original physical rollback. Save failed/rollback state and exact nativeorigin+candidateprefix+attempt coordinates. Conditional TRIAL replay reconstructs full preheadcontext, DIRECT replays identical candidateprefix skippingonlyfailedlarge via originalTimeControl5. Four further routes max,20s each, max4targetattempts; noforcedrefusal, stopscaledrequest.',limits='No full period, admission, referencepromote, artificialdt/tolerance/MAXIT change. B0/B1.12/canonical/release protected.',qualification='Require realactivefailure and same untouched preheadcontext, rollback physicalcore, exactaccepted retry/direct solver/context/ledger/commit, independentwaterinventory. If no witness, preserve exclusion.'),indent=2)+'\n')
