"""Add observational node52 traces to the sealed DIAG19 path."""
from pathlib import Path
import json,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-diag19'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
patches=[]
def put(name,s,old):
 (R/name).write_text(s)
 patches.append(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='baseline/'+name,tofile='NODE20/'+name)))
s=(R/'diag_state.f90').read_text();old=s
s=s.replace('integer,save::kind=', 'logical,save::target=.false.\ninteger,save::iter_index=0,node_u,op_u,raw_u\ninteger,save::kind=',1)
s=s.replace("open(newunit=v,file='cost_trace.txt',status='replace')", "open(newunit=v,file='cost_trace.txt',status='replace')\nopen(newunit=node_u,file='node_iterations.txt',status='replace')\nopen(newunit=op_u,file='node_operator.txt',status='replace')\nopen(newunit=raw_u,file='node_absorption.txt',status='replace')")
s=s.replace('attempts=attempts+1','attempts=attempts+1\niter_index=0\ntarget=attempts==38.or.(attempts>=50.and.attempts<=52)',1)
s=s.replace('if(mod(attempts,128)==0) flush(u)','if(target) then\n flush(node_u);flush(op_u);flush(raw_u)\nend if\nif(mod(attempts,128)==0) flush(u)',1)
s=s.replace('steps>=7000','steps>=42').replace(' close(u);close(v)',' close(u);close(v);close(node_u);close(op_u);close(raw_u)').replace('DIAG19_BOUNDED','NODE20_BOUNDED')
put('diag_state.f90',s,old)
s=(R/'head_diag.f90').read_text();old=s
s=s.replace('nfresh,outcome','nfresh,outcome,target,attempts,iter_index,node_u,op_u',1)
s=s.replace('   do numbit = 1, MaxIt1','   do numbit = 1, MaxIt1\n      iter_index=numbit',1)
s=s.replace(' if(.not.diag_active) return\n write(diag_u,*) stage',' call node20_log(stage)\n if(.not.diag_active) return\n write(diag_u,*) stage',1)
needle='end subroutine diag_log\n'
logger='''
subroutine node20_log(stage)
integer,intent(in)::stage
integer::tr,ff(5)
real(8)::fac,hh,dh,jl,jm,ju,mpd
if(.not.target) return
tr=0;fac=0;hh=h(52);dh=0;ff=0;jl=0;jm=0;ju=0;mpd=0
if(stage/=0) then
 hh=hold(52)
 if(stage==3.or.stage==4.or.stage==5.or.stage==6) then
  tr=itry;fac=factor;dh=difh(52)
 end if
end if
if(stage==2) then
 jl=dFdhU(52);jm=dFdhM(52);ju=dFdhL(52);mpd=dFdhMp(52)
end if
if(stage==4) ff=[merge(1,0,flnonconv),merge(1,0,flnonconv1(52)),merge(1,0,flnonconv2(52)),merge(1,0,flnonconv3),merge(1,0,fldecMPmbf)]
write(node_u,*) attempts,iter_index,stage,tr,t1900,dt,IDecMpRat,fac,h(51:53),hh,dh,F(52), &
 sum(F(1:NN)),maxval(abs(F(1:NN))),.5d0*dot_product(F(1:NN),F(1:NN)),sumold, &
 merge(1,0,flunsatok(3)),ff,jl,jm,ju,mpd
end subroutine node20_log

subroutine node20_operator(task,grad)
use MOD_macropore,only:NumDm,QExcMtxDmCp,QOutMtxUnsDmCp,QOutMtxSatDmCp,QInMtxSatDmCp,QInIntSatDmCp, &
 FrMpWalWet,TimAbsCumDmCp,FlEndSrpEvt,FrReduQ,ICpTpWaSrDm,ZWaLevDm
integer,intent(in)::task
real(8),intent(in)::grad(macp+1)
if(.not.target) return
write(op_u,*) attempts,iter_index,nvec,task,t1900,dt,h(51:53),theta(52),thetm1(52),FrArMtrx(52),dz(52), &
 (theta(52)-thetm1(52))*FrArMtrx(52)*dz(52)/dt,sink(52),-source(52),qrot(52), &
 -kmean(52)*grad(52),kmean(53)*grad(53),-QExcMpMtx(52),F(52),merge(1,0,flunsatok(3)), &
 FrReduQ,QExcMtxDmCp(1:NumDm,52),QOutMtxUnsDmCp(1:NumDm,52),QOutMtxSatDmCp(1:NumDm,52), &
 QInMtxSatDmCp(1:NumDm,52),QInIntSatDmCp(1:NumDm,52),FrMpWalWet(1:NumDm,52), &
 TimAbsCumDmCp(1:NumDm,52),merge(1,0,FlEndSrpEvt(1:NumDm,52)),ICpTpWaSrDm(1:NumDm),ZWaLevDm(1:NumDm)
end subroutine node20_operator
'''
assert needle in s;s=s.replace(needle,needle+logger,1)
s=s.replace('end subroutine vector_F','call node20_operator(iTask,hgrad)\nend subroutine vector_F',1)
put('head_diag.f90',s,old)
s=(R.parent/'swap431-macro-b1-contract06/macrorate_contract.f90').read_text();old=s
# Existing CONTRACT06 implementation remains unchanged; add only a guarded write.
pos=s.lower().index('      subroutine absorption')
left=s[:pos];part=s[pos:]
part=part.replace('      implicit none','      use DIAG19,only:target,attempts,iter_index,nvec,raw_u\n      implicit none',1)
needle='            FlwOutMtxUnsDmPot(id) = FlwOutMtxUnsDmPot(id) + FlwOutMtxUnsDmCpPot(id,ic)'
addition='''            if(target.and.ic==52) then
             block
             real(8)::hm_log,del_log,rec_log,sf_log
             hm_log=0;del_log=0;rec_log=0;sf_log=0
             if(SwDarcy>0.and.ic>ICpTpWaSrDm(id)) then
              hm_log=HMp;del_log=DelH;rec_log=RecRes;sf_log=SorpFac
             end if
             write(raw_u,*) attempts,iter_index,nvec,id,ic,H(ic),theta(ic),dt,FrReduQ, &
              raw_sorp,raw_darcy,FlwOutMtxUnsDmCpPot(id,ic),merge(1,0,FlSorp(id,ic)), &
              hm_log,del_log,rec_log,sf_log,FrMpWalWet(id,ic),TimAbsCumDmCp(id,ic),ICpTpWaSrDm(id)
             end block
            end if
'''
assert needle in part;part=part.replace(needle,addition+needle,1)
put('macrorate_node.f90',left+part,old)
s=(P/'diag19.py').read_text().replace('swap431-diag19-work','swap431-node20-work')
s=s.replace("('head_diag','headcalc'),","('head_diag','headcalc'),('macrorate_node','macrorate'),")
(R/'node20.py').write_text(s)
(R/'instrumentation.patch').write_text('\n'.join(patches))
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='2242ff1836016339e023337a16fd6a8861e00c4c',routes=['O0 native','O2 native'],selected_attempts=[38,50,51,52],selection='First node52 rejection plus original first minimum-step rejection and its actual reduced retry',stop='42 committed steps or16 measured seconds, hard20s subprocess timeout',changes='Read-only operator arithmetic and trace writes; physical code/policy preserved',no_campaign=True),indent=2)+'\n')
