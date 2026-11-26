"""Pure observation of the next original unscaled refusal; no provider probes."""
from donor_sources import replace

def render_head(source):
    source=source.replace('\r\n','\n')
    source=replace(source,'      call jacobian_F()','      call jacobian_F()\n      call observe_coupled_refusal(1)')
    source=replace(source,'   subroutine fresh_coupled_candidate_checks()','   subroutine fresh_coupled_candidate_checks()\n      call observe_coupled_refusal(2)')
    routine='''
   subroutine observe_coupled_refusal(stage)
      use MOD_macropore,only:NumDm,ICpTpSatZon,GwlFlCpZo,WaSrMpDm,ZWaLevDm, &
         QOutMtxSatDmCp,QOutMtxUnsDmCp,QInMtxSatDmCp,QInIntSatDmCp
      integer,intent(in)::stage
      integer,save::tu=0
      integer::worst,k
      real(8)::cm(24,madm),pot(macp,2),valid
      if(t1900<35797.504d0.or.t1900>35797.506d0)return
      if(tu==0)open(newunit=tu,file='coupled_refusal_observer.txt',status='replace')
      worst=maxloc(abs(F(1:NN)),dim=1)
      call macro_rank2_data(cm,pot,valid)
      write(tu,*)stage,t1900,dt,numbit,NN,ICpTpSatZon,GwlFlCpZo,sum(F(1:NN)),maxval(abs(F(1:NN))),worst,flunsatok
      write(tu,*)h(1:NN),theta(1:NN),F(1:NN),QExcMpMtx(1:NN),dFdhMp(1:NN)
      write(tu,*)WaSrMpDm(1:NumDm),ZWaLevDm(1:NumDm),valid,cm(:,1:NumDm)
      write(tu,*)sink(worst),source(worst),qrot(worst),thetm1(worst),FrArMtrx(worst),dz(worst), &
         kmean(worst),hgrad(worst),kmean(worst+1),hgrad(worst+1)
      do k=1,NumDm
         write(tu,*)QOutMtxSatDmCp(k,worst),QOutMtxUnsDmCp(k,worst),QInMtxSatDmCp(k,worst),QInIntSatDmCp(k,worst)
      end do
   end subroutine observe_coupled_refusal
'''
    source=replace(source,'   subroutine solve_stock_gradient()',routine+'\n   subroutine solve_stock_gradient()')
    source=replace(source,'   use MOD_arrays,         only: macp, mabbc','   use MOD_arrays,         only: macp, mabbc,madm')
    return source
