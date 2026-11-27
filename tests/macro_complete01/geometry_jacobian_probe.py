"""Bounded live finite-difference discriminator of the current macro operator."""
from donor_sources import replace

def render_head(source):
 source=source.replace('\r\n','\n')
 source=replace(source,'         call solve_stock_gradient()','         call observe_current_macro_jacobian()\n         call solve_stock_gradient()')
 routine='''
   subroutine observe_current_macro_jacobian()
      use MOD_macropore,only:NumDm,ICpTpSatZon
      use variables,only:thetas
      integer,save::mask=0,tu=0
      integer::kind,cell,upper,lower,col,jj,side,e,cols(3),rep
      real(8)::uu(macp,madm+1),vv(macp,madm+1),meta(16),bl,bd,diag_extra(macp),hs(macp),ts(macp),ks(macp),kms(macp+1),gs(macp+1),fs(macp)
      real(8)::Jcol(macp),qplus(macp),qminus(macp),qplus2(macp),qminus2(macp),eps,pdelta,native(macp)
      logical::eligible
      character(40)::tag
      if(mask==1)return
      if(t1900<35836.018d0.or.t1900>35836.019d0)return
      call jac37_terms(NN,uu,vv,bl,bd,diag_extra,meta,eligible)
      if(.not.eligible)return
      cell=ICpTpSatZon;upper=cell-1;lower=cell
      if(h(cell)<0d0)then
         upper=cell;lower=cell+1
      end if
      if(thetas(upper)-theta(upper)<=1d-6.or.thetas(upper)-theta(upper)>=1d-4)return
      kind=1;mask=1
      if(tu==0)open(newunit=tu,file='macro_live_jacobian_fd.txt',status='replace')
      hs(1:NN)=h(1:NN);ts(1:NN)=theta(1:NN);ks(1:NN)=k(1:NN);kms=kmean;gs=hgrad;fs=F
      native(1:NN)=-dFdhMp(1:NN)
      write(tag,'(A,I1,A)')'fd_',kind,'_before'
      call macro_replay_dump(trim(tag),.true.)
      cols=[upper,lower,max(1,upper-1)]
      do jj=1,3
         col=cols(jj);eps=min(1d-5*max(1d0,abs(hs(col))),.1d0*abs(hs(col)))
         if(eps<=1d-12)cycle
         Jcol(1:NN)=0d0;Jcol(col)=native(col)+diag_extra(col)
         Jcol(1:NN)=Jcol(1:NN)+matmul(uu(1:NN,1:NumDm+1),vv(col,1:NumDm+1))
         if(col==cell-1)Jcol(cell)=Jcol(cell)+bl
         if(col==cell)Jcol(cell)=Jcol(cell)+bd
         do rep=1,2
          pdelta=eps/dble(rep)
          do side=-1,1,2
           h(1:NN)=hs(1:NN);theta(1:NN)=ts(1:NN);k(1:NN)=ks(1:NN);kmean=kms;hgrad=gs
           h(col)=hs(col)+dble(side)*pdelta
           theta(col)=watcon(col,h(col))
           if(SwKimpl==1)then
            k(col)=FrArMtrx(col)*hconduc(col,h(col),theta(col),rfcp(col))
           end if
           do j=2,NN
            hgrad(j)=(h(j-1)-h(j))/disnod(j)+1d0
           end do
           call vector_F(2,hgrad)
           if(rep==1)then
            if(side==1)qplus(1:NN)=-QExcMpMtx(1:NN)
            if(side==-1)qminus(1:NN)=-QExcMpMtx(1:NN)
           else
            if(side==1)qplus2(1:NN)=-QExcMpMtx(1:NN)
            if(side==-1)qminus2(1:NN)=-QExcMpMtx(1:NN)
           end if
          end do
         end do
         write(tu,*)NN,kind,col,eps,t1900,dt,numbit,SwKimpl,cell
         write(tu,*)hs(1:NN),ts(1:NN),Jcol(1:NN),qplus(1:NN),qminus(1:NN),qplus2(1:NN),qminus2(1:NN)
      end do
      h(1:NN)=hs(1:NN);theta(1:NN)=ts(1:NN);k(1:NN)=ks(1:NN);kmean=kms;hgrad=gs
      call vector_F(2,hgrad)
      if(any(F(1:NN)/=fs(1:NN)))error stop 'Macro finite-difference probe changed current residual'
      call jacobian_F()
      write(tag,'(A,I1,A)')'fd_',kind,'_after'
      call macro_replay_dump(trim(tag),.true.)
   end subroutine
'''
 source=replace(source,'   subroutine solve_stock_gradient()',routine+'\n   subroutine solve_stock_gradient()')
 return replace(source,'   use MOD_arrays,         only: macp, mabbc','   use MOD_arrays,         only: macp, mabbc,madm')
