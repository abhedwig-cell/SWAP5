"""Source-bound JAC24 rank-one derivative for the qualified field branch.

Numerical scratch only; physical fluxes and native layout are unchanged.
"""
from donor_sources import replace

def render_rate(source):
    source=source.replace('\r\n','\n')
    decl='''      integer :: stock_n,stock_j,stock_l
      integer, save :: stock_task=0
      integer, save :: stock_seq=0,stock_stamp_seq=-1
      real(8) :: stock_u(*),stock_v(*),stock_meta(12)
      real(8), save :: stock_cached_u(macp),stock_cached_v(macp),stock_cached_meta(12)
      real(8), save :: stock_h(macp),stock_t,stock_dt,stock_in,stock_frin,stock_min
      real(8) :: stock_f,stock_rho,stock_g,stock_den,stock_dh,stock_hm,stock_der(macp)
      logical, save :: stock_ready=.false.,stock_d3=.false.
'''
    # Only the parent MACRORATE declaration, never its later process routines.
    i=source.index('      implicit NONE');source=source[:i]+source[i:].replace('      implicit NONE','      implicit NONE\n'+decl,1)
    source=replace(source,'      t1900 = t1900','''      stock_seq=stock_seq+1
      stock_ready=.false.;stock_d3=.false.
      t1900 = t1900''')
    needle='            if (WaSrMpDmTmp < WaSrMpDmMin) FlwOutDmExces(id) = WaSrMpDmMin - WaSrMpDmTmp'
    source=replace(source,needle,needle+'''
            if(id==3)then
               stock_d3=.true.;stock_in=FlwInDmTot;stock_frin=FrFlwIn;stock_min=WaSrMpDmMin
            end if''')
    source=replace(source,'      if (ITask == 1) return','''      call capture_stock_gradient()
      if (ITask == 1) return''')
    entry='''      entry macro_stock_terms(stock_n,stock_u,stock_v,stock_meta)
      stock_u(1:stock_n)=0d0;stock_v(1:stock_n)=0d0;stock_meta=0d0
      if(.not.stock_ready)return
      if(stock_n/=numnod.or.stock_task/=2.or.stock_stamp_seq/=stock_seq) &
         error stop 'Stale stock gradient task or sequence'
      if(t1900/=stock_t.or.dt/=stock_dt.or.any(h(1:numnod)/=stock_h(1:numnod))) &
         error stop 'Stale stock gradient physical point'
      stock_u(1:stock_n)=stock_cached_u(1:stock_n)
      stock_v(1:stock_n)=stock_cached_v(1:stock_n);stock_meta=stock_cached_meta
      return
      contains
      subroutine capture_stock_gradient()
      stock_ready=.false.;stock_cached_u=0d0;stock_cached_v=0d0;stock_cached_meta=0d0
      if(.not.stock_d3.or.NumDm<3.or.swmbf/=1.or.dt<=0d0.or.FrReduQ/=1d0)return
      if(stock_in/=0d0.or.stock_frin/=1d0.or.FlwInTopExcesTot/=0d0)return
      if(FlwOutMtxUnsDmPot(3)/=0d0.or.FlwOutDmTot(3)<=0d0)return
      if(stock_min>=WaSrMpDm(3))return
      if(FlwOutDmExces(3)/dt<=1d-7.or.FlwOutDmTot(3)<=FlwOutDmExces(3))return
      stock_j=numnod
      do while(stock_j>1)
         if(h(stock_j)<0d0)exit
         stock_j=stock_j-1
      end do
      ! Scope inherited from JAC24's qualified interpolation/volume-cell branch.
      if(stock_j/=50.or.h(stock_j+1)<=0d0.or.ICpTpSatZon/=50)return
      stock_den=h(stock_j+1)-h(stock_j)
      stock_g=z(stock_j+1)+h(stock_j+1)/stock_den*(z(stock_j)-z(stock_j+1))
      if(abs(stock_g-GwlFlCpZo)>1d-9)return
      stock_f=1d0-FlwOutDmExces(3)/FlwOutDmTot(3)
      stock_rho=VlMpDmCp(3,ICpTpSatZon)/dz(ICpTpSatZon)
      stock_der=0d0
      do stock_l=1,numnod
         stock_cached_u(stock_l)=-FlwOutMtxSatDmCpPot(3,stock_l)/dt
         if(FlwOutMtxSatDmCpPot(3,stock_l)>0d0)then
            stock_hm=max(0d0,ZWaLevDm(3)-z(stock_l));stock_dh=stock_hm-h(stock_l)
            if(stock_dh<=0d0)error stop 'Stock outgoing potential head contract'
            stock_der(stock_l)=-FlwOutMtxSatDmCpPot(3,stock_l)/stock_dh
         end if
      end do
      stock_cached_v=-stock_f*stock_der/FlwOutDmTot(3)
      stock_cached_v(stock_j)=stock_cached_v(stock_j)-stock_rho/FlwOutDmTot(3)* &
         (z(stock_j)-z(stock_j+1))*h(stock_j+1)/stock_den**2
      stock_cached_v(stock_j+1)=stock_cached_v(stock_j+1)+stock_rho/FlwOutDmTot(3)* &
         (z(stock_j)-z(stock_j+1))*h(stock_j)/stock_den**2
      stock_cached_meta=[1d0,FlwOutDmTot(3),FlwOutDmExces(3),stock_f,stock_rho,GwlFlCpZo, &
         stock_min,WaSrMpDm(3),dble(stock_j),h(stock_j),h(stock_j+1),dt]
      stock_h(1:numnod)=h(1:numnod);stock_t=t1900;stock_dt=dt
      stock_stamp_seq=stock_seq;stock_task=ITask;stock_ready=.true.
      end subroutine capture_stock_gradient
'''
    source=replace(source,'      end subroutine MacroRate',entry+'      end subroutine MacroRate')
    return source

def render_head(source):
    source=replace(source,'      if (iTask == 1 .OR. .NOT. flunsatok(3)) then ',
                          '      if (iTask == 1 .OR. iTask == 2) then ')
    source=replace(source,'   if (swmacro == 1 .AND. .NOT.flunsatok(3)) then','   if (swmacro == 1) then')
    source=replace(source,'      call tridag(NN, dFdhU, dFdhM, dFdhL, F, difh, ierror)',
'''      if(swmacro==1)then
         call solve_stock_gradient()
      else
         call tridag(NN,dFdhU,dFdhM,dFdhL,F,difh,ierror)
      end if''')
    sub='''
   subroutine solve_stock_gradient()
      real(8)::u(NN),v(NN),meta(12),work(NN),den,alpha,lin(NN)
      integer::e,j
      integer,save::trace_unit=0,systems_unit=0,active_count=0
      call macro_stock_terms(NN,u,v,meta)
      call tridag(NN,dFdhU,dFdhM,dFdhL,F,difh,ierror)
      if(ierror/=0)return
      if(meta(1)/=1d0)return
      call tridag(NN,dFdhU,dFdhM,dFdhL,u,work,e)
      if(e/=0)error stop 'Stock correction solve failed'
      den=1d0+dot_product(v,work)
      if(.not.ieee_is_finite(den).or.abs(den)<1d-12)error stop 'Stock rank correction singular'
      alpha=dot_product(v,difh)/den;difh=difh-alpha*work
      if(any(.not.ieee_is_finite(difh)))error stop 'Nonfinite stock correction'
      lin=dFdhM*difh-F
      do j=2,NN
         lin(j)=lin(j)+dFdhU(j)*difh(j-1)
      end do
      do j=1,NN-1
         lin(j)=lin(j)+dFdhL(j)*difh(j+1)
      end do
      lin=lin+u*dot_product(v,difh)
      if(trace_unit==0)open(newunit=trace_unit,file='macro_stock_trace.txt',status='replace')
      write(trace_unit,*)t1900,dt,numbit,meta,den,maxval(abs(lin))
      active_count=active_count+1
      if(active_count<=64)then
         if(systems_unit==0)open(newunit=systems_unit,file='macro_stock_systems.txt',status='replace')
         write(systems_unit,*)NN,t1900,dt,numbit
         write(systems_unit,*)dFdhU,dFdhM,dFdhL,F,u,v,difh
      end if
   end subroutine solve_stock_gradient
'''
    return replace(source,'   subroutine fresh_coupled_candidate_checks()',sub+'\n   subroutine fresh_coupled_candidate_checks()')
