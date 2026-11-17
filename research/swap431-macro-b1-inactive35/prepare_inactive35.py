from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-period34'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
s=(R/'diag_state.f90').read_text().replace('integer,save::iter_index=0,node_u,op_u,raw_u,limit_u,macro_seq=0','integer,save::iter_index=0,node_u,op_u,raw_u,limit_u,macro_seq=0,op35_u,node35_u')
s=s.replace("open(newunit=limit_u,file='domain3_limit.txt',status='replace')","open(newunit=limit_u,file='domain3_limit.txt',status='replace')\nopen(newunit=op35_u,file='operator_nodes.txt',status='replace')\nopen(newunit=node35_u,file='iteration_nodes.txt',status='replace')")
s=s.replace('close(u);close(v);close(node_u);close(op_u);close(raw_u);close(limit_u)','close(u);close(v);close(node_u);close(op_u);close(raw_u);close(limit_u);close(op35_u);close(node35_u)')
(R/'diag_state.f90').write_text(s)
s=(R/'head_diag.f90').read_text().replace('node_u,op_u,detail33','node_u,op_u,detail33,op35_u,node35_u')
s=s.replace(' call node20_log(stage)',' call node20_log(stage)\n call node35_log(stage)',1)
s=s.replace('call node20_operator(iTask,hgrad)','call node20_operator(iTask,hgrad)\ncall node35_operator(iTask,hgrad)',1)
pos=s.index('subroutine unreduced_trace(kind)')
s=s[:pos]+'''subroutine node35_log(stage)
integer,intent(in)::stage
integer::ic,fc,fh
real(8)::hl,step,jl,jm,ju,mpd
if(.not.detail33) return
do ic=50,57
 hl=h(ic);step=0d0;jl=0d0;jm=0d0;ju=0d0;mpd=0d0;fc=0;fh=0
 if(stage/=0) hl=hold(ic)
 if(stage==3.or.stage==4.or.stage==5.or.stage==6) step=difh(ic)
 if(stage==2) then
  jl=dFdhU(ic);jm=dFdhM(ic);ju=dFdhL(ic);mpd=dFdhMp(ic)
 end if
 if(stage==4) then
  fc=merge(1,0,flnonconv1(ic));fh=merge(1,0,flnonconv2(ic))
 end if
 write(node35_u,*) attempts,iter_index,stage,nvec,ic,h(ic),hl,step,F(ic),jl,jm,ju,mpd,fc,fh
end do
end subroutine

subroutine node35_operator(task,grad)
use MOD_macropore,only:NumDm,QExcMtxDmCp,QOutMtxUnsDmCp,QOutMtxSatDmCp,QInMtxSatDmCp,QInIntSatDmCp,FrReduQ
integer,intent(in)::task
real(8),intent(in)::grad(macp+1)
integer::ic
if(.not.detail33) return
do ic=50,57
 write(op35_u,*) attempts,iter_index,nvec,task,t1900,dt,ic,h(ic),theta(ic),thetm1(ic),F(ic), &
  (theta(ic)-thetm1(ic))*FrArMtrx(ic)*dz(ic)/dt,sink(ic),-source(ic),qrot(ic), &
  -kmean(ic)*grad(ic),kmean(ic+1)*grad(ic+1),-QExcMpMtx(ic),FrReduQ, &
  QExcMtxDmCp(1:NumDm,ic),QOutMtxUnsDmCp(1:NumDm,ic),QOutMtxSatDmCp(1:NumDm,ic), &
  QInMtxSatDmCp(1:NumDm,ic),QInIntSatDmCp(1:NumDm,ic)
end do
end subroutine

''' + s[pos:]
(R/'head_diag.f90').write_text(s)
s=(R/'soilwater_native.f90').read_text()
s=s.replace(" if(IDecMpRat/=0) error stop 'TRAJECTORY33 scaled replay excluded'"," if(abs(t1900-35797.370324351359d0)>1d-10.or.abs(dt-0.0006875745394909628d0)>1d-16) error stop 'INACTIVE35 replay context mismatch'\n if(IDecMpRat/=0) error stop 'TRAJECTORY33 scaled replay excluded'",1)
s=s.replace(' real(8)::dm,dp,dc,dx,external,domain_error(5)',' real(8)::dm,dp,dc,dx,external,domain_error(5)\n logical::done35',1)
s=s.replace(" if(reject26_pending) then\n  call inventory_dump('committed')"," if(reject26_pending) then\n  done35=commit()\n  call inventory_dump('committed')",1)
(R/'soilwater_native.f90').write_text(s)
runner=(P/'period34.py').read_text().replace('swap431-period34-work','swap431-inactive35-work').replace("R/'EVENT_SELECTION.json'","R/'DIAG_SELECTION.json'")
(R/'inactive35.py').write_text(runner)
selection=json.loads((P/'INACTIVE_FAILURE_INDEX.json').read_text())['first_inactive_refusal'];assert selection['attempt']==293 and selection['rank1_active_iterations']==0
(R/'DIAG_SELECTION.json').write_text(json.dumps(selection,indent=2)+'\n')
patch=''
for p in P.glob('*.f90'):
 if p.read_bytes()!=(R/p.name).read_bytes():patch+=''.join(difflib.unified_diff(p.read_text().splitlines(True),(R/p.name).read_text().splitlines(True),fromfile='PERIOD34/'+p.name,tofile='INACTIVE35/'+p.name))
(R/'diagnostic_only.patch').write_text(patch)
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='04c3b4ae12ce4d7aefe912081c6769920ef54dbc',remote_main='be481cfb40f953e337116ef4a6dc5bc3ef64d4f7',workstream='isolated SWAP431 B1 research',scope='Only own-candidate firstinactive refusal293 plus original retry. Continuous candidateprefix fromnative35797, targett35797.370324351359 dt.0006875745394909628; notoriginalV1prefix. No periodcampaign.',routes='Two TRIAL O2/O0, hard20s each, max4targetattempts as inherited. If genuine inactive refusal followed unscaled accept, two DIRECT O2/O0 to test restoration/equality. At mosttwo extra transactional providerprobe routes onlyif a specific nonlocal derivative hypothesis follows from firstdiagnostics; predeclare exactprobe then. No new contexts or numericalvariant.',changes='Only three diagnostic/driverfiles: detailnode50..57 traces, exacttargetcheck, targetcommitcounter. All physical/solver/Jacobian/sourceformulas and guards/MAXIT/tolerances/dt/reduction/nativeformats unchanged.',qualification='Match originalcandidateprefix and actualtargetfailure/acceptedretry, sumoperatorcontributions, recordguardexclusions and iteratorhistory. Separate inactiverollback from stillmissingactivefailure proof. Nofixwithoutdemonstrateddefect.',protected='B0/B1.12/canonical/no-macrorelease unchanged',official_promotion=False),indent=2)+'\n')
