"""DOMAINS36/CORRECTION37 live current-provider scratch, no calendar gates."""
from donor_sources import replace

def render_rate(source):
    decl='''      real(8),save::rank2_cm(24,madm)=0d0,rank2_pot(macp,2)=0d0
      real(8),save::rank2_head(macp),rank2_t,rank2_dt
      integer,save::rank2_seq=-1,rank2_task=-1
      logical,save::rank2_ready=.false.
      real(8)::rank2_get_cm(24,madm),rank2_get_pot(macp,2),rank2_valid
'''
    i=source.index('      implicit NONE');source=source[:i]+source[i:].replace('      implicit NONE','      implicit NONE\n'+decl,1)
    source=replace(source,'      stock_seq=stock_seq+1','''      rank2_ready=.false.;rank2_cm=0d0
      stock_seq=stock_seq+1''')
    needle='            if (WaSrMpDmTmp < WaSrMpDmMin) FlwOutDmExces(id) = WaSrMpDmMin - WaSrMpDmTmp'
    source=replace(source,needle,needle+'''
            rank2_cm(1:15,id)=[WaSrMpDm(id),WaSrMpDmMin,WaSrMpDmMax,VlMpUndrGwL,FlwInDmTot,FlwOutDmTot(id), &
               WaSrMpDmTmp,FrFlwIn,FlwInTopVrtDmPot(id),FlwInTopLatDmPot(id),FlwInIntSatDmPot(id),FlwInMtxSatDmPot(id), &
               FlwOutMtxSatDmPot(id),FlwOutMtxUnsDmPot(id),merge(FlwOutDrRapPot,0d0,id==1)]
            rank2_cm(18:24,id)=[VlMpDmCp(id,ICpTpSatZon)/dz(ICpTpSatZon),GwlFlCpZo, &
               dble(ICpTpSatZon),dt,0d0,dble(IcTopMp),ZWaLevDm(id)]''')
    needle='            if (swmbf == 1 .OR. (swmbf == 2 .AND. id > 1)) then'
    source=replace(source,needle,'''            rank2_cm(16,id)=FrFlwOut;rank2_cm(17,id)=FlwOutDmExces(id)
            rank2_cm(22,id)=FlwInTopExcesTot
'''+needle)
    source=replace(source,'      call capture_stock_gradient()', '''      if(swmbf==1.and.NumDm>=3)then
         rank2_pot(:,1)=FlwOutMtxSatDmCpPot(2,:);rank2_pot(:,2)=FlwOutMtxSatDmCpPot(3,:)
         rank2_head(1:numnod)=h(1:numnod);rank2_t=t1900;rank2_dt=dt
         rank2_seq=stock_seq;rank2_task=ITask;rank2_ready=.true.
      end if
      call capture_stock_gradient()''')
    source=replace(source,'      entry macro_stock_terms(','''      entry macro_rank2_data(rank2_get_cm,rank2_get_pot,rank2_valid)
      rank2_get_cm=rank2_cm;rank2_get_pot=rank2_pot;rank2_valid=0d0
      if(rank2_ready.and.rank2_task==2.and.rank2_seq==stock_seq)then
         if(rank2_t==t1900.and.rank2_dt==dt.and.all(rank2_head(1:numnod)==h(1:numnod)))rank2_valid=1d0
      end if
      return
      entry macro_stock_terms(''')
    return source

def render_head(source):
    source=replace(source,'      integer::e,j','      integer::e,j\n      logical::rank2_handled')
    source=replace(source,'      call macro_stock_terms(NN,u,v,meta)', '''      call jac37_solve(NN,dFdhU(1:NN),dFdhM(1:NN),dFdhL(1:NN),F(1:NN),difh(1:NN),ierror,rank2_handled)
      if(rank2_handled)return
      call macro_stock_terms(NN,u,v,meta)''')
    return source
