"""Live pre-derivative D3 payload for the complete source-derived correction."""
from donor_sources import replace

def render_rate(source):
    decl='''      real(8),save::complete_sat(macp)=0d0,complete_uns(macp)=0d0
      real(8)::complete_cm(24,madm),complete_ps(macp),complete_pu(macp),complete_valid
'''
    i=source.index('      implicit NONE');source=source[:i]+source[i:].replace('      implicit NONE','      implicit NONE\n'+decl,1)
    source=replace(source,'      call capture_stock_gradient()', '''      if(swmbf==1.and.NumDm==5)then
         complete_sat=FlwOutMtxSatDmCpPot(3,:);complete_uns=FlwOutMtxUnsDmCpPot(3,:)
      end if
      call capture_stock_gradient()''')
    source=replace(source,'      entry macro_rank2_data(','''      entry macro_d3_data(complete_cm,complete_ps,complete_pu,complete_valid)
      complete_cm=rank2_cm;complete_ps=complete_sat;complete_pu=complete_uns;complete_valid=0d0
      if(rank2_ready.and.rank2_task==2.and.rank2_seq==stock_seq)then
         if(rank2_t==t1900.and.rank2_dt==dt.and.all(rank2_head(1:numnod)==h(1:numnod)))complete_valid=1d0
      end if
      return
      entry macro_rank2_data(''')
    return source

def render_head(source):
    old='      call jac37_solve(NN,dFdhU(1:NN),dFdhM(1:NN),dFdhL(1:NN),F(1:NN),difh(1:NN),ierror,rank2_handled)'
    new='''      call jac63_solve(NN,dFdhU(1:NN),dFdhM(1:NN),dFdhL(1:NN),F(1:NN),difh(1:NN),ierror,rank2_handled)
      if(rank2_handled)return
'''+old
    return replace(source,old,new)
