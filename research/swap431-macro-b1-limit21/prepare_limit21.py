"""Observe the original standard-domain water availability limiter, without mutation."""
from pathlib import Path
import difflib,json
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-node20'
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
patch=[]
def put(name,s,old):
 (R/name).write_text(s)
 patch.append(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='NODE20/'+name,tofile='LIMIT21/'+name)))
s=(R/'diag_state.f90').read_text();old=s
s=s.replace('integer,save::iter_index=0,node_u,op_u,raw_u','integer,save::iter_index=0,node_u,op_u,raw_u,limit_u,macro_seq=0')
s=s.replace("open(newunit=raw_u,file='node_absorption.txt',status='replace')","open(newunit=raw_u,file='node_absorption.txt',status='replace')\nopen(newunit=limit_u,file='domain3_limit.txt',status='replace')")
s=s.replace('iter_index=0\ntarget=', 'iter_index=0;macro_seq=0\ntarget=',1)
s=s.replace('flush(node_u);flush(op_u);flush(raw_u)','flush(node_u);flush(op_u);flush(raw_u);flush(limit_u)')
s=s.replace('close(op_u);close(raw_u)','close(op_u);close(raw_u);close(limit_u)').replace('NODE20_BOUNDED','LIMIT21_BOUNDED')
put('diag_state.f90',s,old)
s=(R/'macrorate_node.f90').read_text();old=s
s=s.replace('      implicit NONE','      use DIAG19,only:target,attempts,iter_index,nvec,limit_u,macro_seq\n      implicit NONE',1)
s=s.replace('      real(8) VOLUNDR','      real(8),save::lim_min,lim_max,lim_under,lim_in,lim_out,lim_tmp,lim_frin,lim_excess,lim_nodein\n      real(8) VOLUNDR',1)
s=s.replace('      t1900 = t1900','      macro_seq=macro_seq+1\n      t1900 = t1900',1)
needle='            if (WaSrMpDmTmp < WaSrMpDmMin) FlwOutDmExces(id) = WaSrMpDmMin - WaSrMpDmTmp'
assert needle in s
s=s.replace(needle,needle+'''
            if(target.and.id==3) then
             lim_min=WaSrMpDmMin;lim_max=WaSrMpDmMax;lim_under=VlMpUndrGwL
             lim_in=FlwInDmTot;lim_out=FlwOutDmTot(id);lim_tmp=WaSrMpDmTmp;lim_frin=FrFlwIn
             lim_excess=FlwOutDmExces(id);lim_nodein=FlwInMtxSatCpPot(52)
             call limit21_trace(1)
            end if
''',1)
needle='            if (swmbf == 1 .OR. (swmbf == 2 .AND. id > 1)) then\n               QOutMtxSatDmCp'
assert needle in s;s=s.replace(needle,'            if(target.and.id==3) call limit21_trace(2)\n'+needle,1)
needle='               if (id == 1) QOutDrRapCp(IcTopMp:NumNod) = FrFlwOut * FlwOutDrRapCpPot(IcTopMp:NumNod) / dt\n            end if'
assert needle in s;s=s.replace(needle,needle+'\n            if(target.and.id==3) call limit21_trace(3)',1)
needle='      end subroutine MacroRate'
helper='''      contains
      subroutine limit21_trace(stage)
      integer,intent(in)::stage
      real(8)::outfac
      outfac=-1d0
      if(stage/=1) outfac=FrFlwOut
      write(limit_u,*) attempts,iter_index,nvec,macro_seq,ITask,stage,dt,FrReduQ,h(52), &
       GwlFlCpZo,ICpTpSatZon,ZWaLevDm(3),WaSrMpDm(3),lim_min,lim_max,lim_under,VlMpDm(3), &
       lim_in,lim_out,lim_tmp,lim_frin,lim_excess,FlwOutDmExces(3),outfac, &
       FlwInTopVrtDmPot(3),FlwInTopLatDmPot(3),FlwInIntSatDmPot(3),FlwInMtxSatDmPot(3), &
       FlwOutMtxSatDmPot(3),FlwOutMtxUnsDmPot(3),FlwOutMtxSatDmCpPot(3,52), &
       QOutMtxSatDmCp(3,52),QInMtxSatDmCp(3,52),QInTopVrtDm(3)+QInTopLatDm(3), &
       FlwOutMtxSatDmCpPot(3,52)/dt,sum(QOutMtxSatDmCp(3,1:numnod))+sum(QOutMtxUnsDmCp(3,1:numnod)), &
       sum(QInMtxSatDmCp(3,1:numnod))+sum(QInIntSatDmCp(3,1:numnod))+QInTopVrtDm(3)+QInTopLatDm(3), &
       FlwInTopExcesTot,SatDefTot,merge(1,0,FlwOutDmExces(3)/dt>1d-7), &
       merge(1,0,FlwOutDmTot(3)>FlwOutDmExces(3)),WaSrMpDm(3)+lim_frin*lim_in-lim_min,lim_nodein
      end subroutine limit21_trace
'''
assert needle in s;s=s.replace(needle,helper+needle,1)
put('macrorate_node.f90',s,old)
s=(P/'node20.py').read_text().replace('swap431-node20-work','swap431-limit21-work')
(R/'limit21.py').write_text(s)
(R/'instrumentation.patch').write_text('\n'.join(patch))
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='2b1929461bebcd7bb8063a0542b17ef1f1c7e654',routes=['O0 native','O2 native'],selected_attempts=[38,50,51,52],scope='Same original node52 failure, domain3 standard storage/in-out limiter; potentials, storage bounds, excess redistribution and actual flux',stop='42 commits or16 measured seconds, hard20s process timeout',changes='Additive trace fields and writes only',no_campaign=True),indent=2)+'\n')
