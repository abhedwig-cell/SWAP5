from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-inactive35'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R/'macrorate_node.f90').read_text();needle='      real(8)::pot35(macp),info35(12)';assert needle in s
s=s.replace(needle,needle+'''
      real(8),save::obs36_meta(24,madm),obs36_in(macp,madm),obs36_outsat(macp,madm),obs36_outuns(macp,madm),obs36_rapid(macp,madm)
      real(8)::get36_meta(24,madm),get36_in(macp,madm),get36_outsat(macp,madm),get36_outuns(macp,madm),get36_rapid(macp,madm)
''',1)
needle='            if(target.and.id==3) then';assert s.count(needle)==1
s=s.replace(needle,'''            if(detail33) then
             obs36_meta(:,id)=0d0
             obs36_meta(1:15,id)=[WaSrMpDm(id),WaSrMpDmMin,WaSrMpDmMax,VlMpUndrGwL,FlwInDmTot,FlwOutDmTot(id), &
              WaSrMpDmTmp,FrFlwIn,FlwInTopVrtDmPot(id),FlwInTopLatDmPot(id),FlwInIntSatDmPot(id),FlwInMtxSatDmPot(id), &
              FlwOutMtxSatDmPot(id),FlwOutMtxUnsDmPot(id),merge(FlwOutDrRapPot,0d0,id==1)]
             obs36_meta(18:24,id)=[VlMpDmCp(id,ICpTpSatZon)/dz(ICpTpSatZon),GwlFlCpZo,dble(ICpTpSatZon),dt,0d0,dble(IcTopMp),ZWaLevDm(id)]
             obs36_in(:,id)=FlwInMtxSatCpPot+FlwInIntSatCpPot
             obs36_outsat(:,id)=FlwOutMtxSatDmCpPot(id,:)
             obs36_outuns(:,id)=FlwOutMtxUnsDmCpPot(id,:)
             obs36_rapid(:,id)=0d0
             if(id==1) obs36_rapid(:,id)=FlwOutDrRapCpPot
            end if
'''+needle,1)
needle='            if(target.and.id==3) call limit21_trace(3)';assert s.count(needle)==1
s=s.replace(needle,needle+'''
            if(detail33) then
             obs36_meta(16,id)=FrFlwOut
             obs36_meta(17,id)=FlwOutDmExces(id)
             obs36_meta(22,id)=FlwInTopExcesTot
            end if
''',1)
needle='      entry diagnose35_get(pot35,info35)';assert s.count(needle)==1
s=s.replace(needle,'''      entry diagnose36_get(get36_meta,get36_in,get36_outsat,get36_outuns,get36_rapid)
      get36_meta=obs36_meta
      get36_in=obs36_in
      get36_outsat=obs36_outsat
      get36_outuns=obs36_outuns
      get36_rapid=obs36_rapid
      return
'''+needle,1)
(R/'macrorate_node.f90').write_text(s)
s=(R/'probe_state.f90').read_text();a=s.index('subroutine probe35_maybe()');pre=s[:a];s=s[a:]
s=s.replace('use MOD_arrays,only:macp','use MOD_arrays,only:macp,madm',1).replace('use MOD_macropore,only:QExcMtxDmCp','use MOD_macropore,only:QExcMtxDmCp,NumDm',1)
s=s.replace('integer::u,ru,fu,cu,node,lev,sgn,j,nbytes,partid','integer::u,ru,fu,cu,node,lev,sgn,j,nbytes,partid,dom36,unit36,base36',1)
s=s.replace('real(8)::eps,pot(macp),meta(12)','real(8)::eps,pot(macp),meta(12)\nreal(8)::meta36(24,madm),in36(macp,madm),out36(macp,madm),uns36(macp,madm),rapid36(macp,madm)',1)
s=s.replace("open(newunit=ru,file='probe35_restore.txt',status='replace')","""call diagnose36_get(meta36,in36,out36,uns36,rapid36)
open(newunit=base36,file='probe36_base.txt',status='replace')
do dom36=1,NumDm
 write(base36,*) dom36,meta36(:,dom36),QExcMtxDmCp(dom36,1:numnod),in36(1:numnod,dom36),out36(1:numnod,dom36), &
  uns36(1:numnod,dom36),rapid36(1:numnod,dom36)
end do
close(base36)
open(newunit=unit36,file='probe36_domains.txt',status='replace')
open(newunit=ru,file='probe35_restore.txt',status='replace')""",1)
s=s.replace('close(probe_u);close(fu);close(ru)','close(probe_u);close(fu);close(ru);close(unit36)',1)
needle='write(fu,*) partid,ic,delta,meta,h(50:52),QExcMtxDmCp(3,1:numnod),QExcMpMtx(1:numnod),pot(1:numnod)';assert needle in s
s=s.replace(needle,needle+'''
call diagnose36_get(meta36,in36,out36,uns36,rapid36)
do dom36=1,NumDm
 write(unit36,*) partid,ic,delta,dom36,meta36(:,dom36),QExcMtxDmCp(dom36,1:numnod),in36(1:numnod,dom36), &
  out36(1:numnod,dom36),uns36(1:numnod,dom36),rapid36(1:numnod,dom36)
end do
''',1)
(R/'probe_state.f90').write_text(pre+s)
(R/'domains36.py').write_text((P/'inactive35.py').read_text().replace('swap431-inactive35-work','swap431-domains36-work'))
(R/'DIAG_SELECTION.json').write_bytes((P/'DIAG_SELECTION.json').read_bytes())
(R/'PROBE_CONTRACT.json').write_bytes((P/'PROBE_CONTRACT.json').read_bytes())
patch=''
for p in P.glob('*.f90'):
 if p.read_bytes()!=(R/p.name).read_bytes():patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),(R/p.name).read_text().splitlines(True),fromfile='INACTIVE35/'+p.name,tofile='DOMAINS36/'+p.name))
(R/'observation_only.patch').write_text(patch)
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='7bc419d2d27696e0125ee2767e3d45326dca3c82',remote_main='be481cfb40f953e337116ef4a6dc5bc3ef64d4f7',workstream='isolated SWAP431 B1 research',scope='Only same own-candidate293 iteration30 point. Two TRIAL_PROBE routes O0/O2 hard20s; same18realprovider evaluations and19restores. No newstate/epsilon/node/horizon or solvervariant.',changes='Two observation-only files: cacheperdomain B1stocks/potentials/actual factors; readonlyENTRY and per-pointall5domain output. Caches diagnostic only, never read by physics or solver, refreshed eachprovider evaluation; original SENSE23 physical scope unchanged.',candidate_physics_guards_MAXIT_tolerances_dt_reduction_unchanged=True,qualification='Exact oldINACTIVE35 snapshot/points/restores/continuation; sumperdomainFDtotal equalsoldmissingresponse; identify activebound branches and analytic chain for minimalcorrection contract. Do NOT infer soleconvergencecause or implement solvercorrection inthisround.',routes=2,bounds='max20s each, samecontext only, no period/restart/campaign. Bothrealbinaryclosures kept for thisbuild; oldclosures inheritedINACTIVE35.',protected='B0/B1.12/canonical/no-macrorelease unchanged',official_promotion=False),indent=2)+'\n')
