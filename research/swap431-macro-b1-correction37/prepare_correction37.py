from pathlib import Path
import json
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-domains36'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
(R/'DIAG_SELECTION.json').write_bytes((P/'DIAG_SELECTION.json').read_bytes())
s=(R/'diag_state.f90').read_text().replace('logical,save::probe_busy=.false.','logical,save::probe_busy=.false.,apply37=.false.');(R/'diag_state.f90').write_text(s)
s=(R/'soilwater_native.f90').read_text().replace('attempts,detail33,active_in_attempt','attempts,detail33,active_in_attempt,apply37',1)
s=s.replace(' detail33=.true.\n call inventory_dump(\'origin\')'," apply37=.true.\n call jac37_calibrate()\n detail33=.true.\n call inventory_dump('origin')",1)
(R/'soilwater_native.f90').write_text(s)
s=(R/'macrorate_node.f90').read_text().replace('point_delta,detail33','point_delta,detail33,apply37',1)
needle='      integer::n24,j24,l24';s=s.replace(needle,needle+'''
      real(8),save::canonical37(24,madm)=0d0,head37(macp)=0d0,time37=0d0,dt37=0d0
      integer,save::task37=-1,attempt37=-1,iteration37=-1
      logical,save::ready37=.false.
      real(8)::get37_meta(24,madm),get37_potential(macp,2),get37_valid
''',1)
# Each real provider evaluation invalidates and then refreshes the numerical workspace.
needle='      QMaPo                            = 0.d0';assert needle in s;s=s.replace(needle,'      if(apply37) ready37=.false.\n'+needle,1)
needle='            if(detail33) then\n             obs36_meta(:,id)=0d0';assert needle in s
canonical='''            if(apply37) then
             canonical37(:,id)=0d0
             canonical37(1:15,id)=[WaSrMpDm(id),WaSrMpDmMin,WaSrMpDmMax,VlMpUndrGwL,FlwInDmTot,FlwOutDmTot(id), &
              WaSrMpDmTmp,FrFlwIn,FlwInTopVrtDmPot(id),FlwInTopLatDmPot(id),FlwInIntSatDmPot(id),FlwInMtxSatDmPot(id), &
              FlwOutMtxSatDmPot(id),FlwOutMtxUnsDmPot(id),merge(FlwOutDrRapPot,0d0,id==1)]
             canonical37(18:24,id)=[VlMpDmCp(id,ICpTpSatZon)/dz(ICpTpSatZon),GwlFlCpZo,dble(ICpTpSatZon),dt,0d0,dble(IcTopMp),ZWaLevDm(id)]
            end if
'''
s=s.replace(needle,canonical+needle,1)
needle='            if(detail33) then\n             obs36_meta(16,id)=FrFlwOut';assert needle in s
s=s.replace(needle,'''            if(apply37) then
             canonical37(16,id)=FrFlwOut
             canonical37(17,id)=FlwOutDmExces(id)
             canonical37(22,id)=FlwInTopExcesTot
            end if
'''+needle,1)
needle='      if (ITask == 1) return';assert needle in s
s=s.replace(needle,'''      if(apply37) then
       head37(1:numnod)=h(1:numnod)
       time37=t1900;dt37=dt;task37=ITask;attempt37=attempts;iteration37=iter_index
       ready37=.true.
      end if
'''+needle,1)
needle='      entry diagnose36_get';pos=s.index(needle)
entry='''      entry jac37_get(get37_meta,get37_potential,get37_valid)
      get37_meta=canonical37
      get37_potential(:,1)=FlwOutMtxSatDmCpPot(2,:)
      get37_potential(:,2)=FlwOutMtxSatDmCpPot(3,:)
      get37_valid=0d0
      if(ready37.and.task37==2.and.time37==t1900.and.dt37==dt.and.attempt37==attempts.and.iteration37==iter_index) then
       if(all(head37(1:numnod)==h(1:numnod))) get37_valid=1d0
      end if
      return
      entry jac37_invalidate()
      ready37=.false.
      return
'''
s=s[:pos]+entry+s[pos:];(R/'macrorate_node.f90').write_text(s)
s=(R/'jac_update.f90').read_text().replace('active_in_attempt,active_total','active_in_attempt,active_total,apply37',1).replace('logical,save::opened=.false.','logical::handled37\nlogical,save::opened=.false.',1)
needle='call jac24_terms(n,uu,vv,d,meta)';assert needle in s
s=s.replace(needle,'''if(apply37) then
 call jac37_solve(n,a,b,c,r,x,ierror,handled37)
 if(handled37) return
end if
'''+needle,1);(R/'jac_update.f90').write_text(s)
runner=(P/'domains36.py').read_text().replace('swap431-domains36-work','swap431-correction37-work')
runner=runner.replace("('probe_state','probe23'),('jac_update','jac24'),","('probe_state','probe23'),('jac37_update','jac37'),('jac_update','jac24'),",1)
needle=" shutil.copy2(cal,c/'calibration_base.bin')";assert needle in runner
runner=runner.replace(needle,needle+"\n point=R.parent/'swap431-macro-b1-domains36/data'/opt/'TRIAL_PROBE/probe35_base.bin'\n assert m.sha(point)=='dcd762c36d16ec3dbd37117bbf22a2d658c5f33fb2460ba9ef369afbada45db6'\n shutil.copy2(point,c/'domains36_point.bin')",1)
(R/'correction37.py').write_text(runner)
(R/'IMPLEMENTATION_CONTRACT.json').write_text(json.dumps(dict(anchor='DOMAINS36 CONTRACT.md fixed293point',activation='New correction ONLY selected293 and its retries. Original current-operator/rank1 prefix unchanged. Other unsupported states return to exact oldjac24_solve; no double correction.',provider='Numerical canonical workspace separate from obs36diagnosticcache, refreshed in realMACRORATE evaluation, task2/currentfullheads/clock/dt/attempt/iteration validated. Scratch only, not new nativephysicalstate. No readingdiagnosticfiles for live solve.',stock_piecewise='For domains2,3: activeoutlimiter df=(-dL-f*dO)/O; dL=rho*dG iff Vunder<W, otherwise0. ExactVunder=W chooses stockcap derivative0 (generalized branch choice toqualify by actualhead), recordtie. Unlimited/cutoffoutflow df0. Existing localpotential derivatives retained.',band='Actual incomingmatrix+internal atpartialcell51 givesGWLgeometry correction to lower51 anddiag51, plusmissinglocalinternaldiag. NativePe/top/bottom51,GWLinterpolation50/51,HMp1=0 andFrs1 guarded.',linear='OriginalTRIDAG for adjustedbandF and twoU, then2x2Woodbury; no denseJacobian or FDsolver. Originalrank1fallback preserved. Singular checks match existing1e-12research threshold, linear residual recorded.',calibration='Before actual selectedhead: save SENSE23 selectedprocess+IEEE, load retainedDOMAINS36point, realMACRORATE2refresh, output actualimplementedU/V/B, restorebyteexact preheadstate andIEEE, invalidate numericalworkspace. No perturb/no convergence forcing.',exclusions='Qualified4inputcolumns only, dynamicupper-soilshrinkcouplings notclaimed exact, branch/cap/tie correctness testedonly encounteredselectedhead; no newperiod/restart/campaign.'),indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps(dict(stage='IMPLEMENTED_PREREGISTERED',baseline='861d0bc866479918393443991ce05ac91a8604bf',remote_main='be481cfb40f953e337116ef4a6dc5bc3ef64d4f7',workstream='isolated SWAP431B1 research',scope='MinimalDOMAINS36correction on SAME large293 originalcurrentcandidateprefix. Exactly2TRIALroutesO0/O2 hard20seach; if true correctedrefusal followed unscaledretry then2DIRECTroutes only. No widercontexts/period/restart.',numerical_change='Two stock rank1s domains2/3 plusband51 corrections to existingJacobian, appliedonceviaWoodbury. Canonicalcurrentproviderdata, originalphysrates/forcing/tolerances/MAXIT/dt/reductionrules unchanged.',requirements='Exact292commitprefix andorigin, calibratedimplementationterms matchfrozenpointFDcontract, periterationlinearresidual; real freshV1acceptcriteria, hostcommit, independentinventory. Ifrefuses testrollback/direct, neverforcefailure.',official_promotion=False),indent=2)+'\n')
