"""Analytic lateral surface gradient; physical boundtop statements unchanged."""
from donor_sources import replace

def render(source):
 source=source.replace('\r\n','\n')
 source=replace(source,'\n   implicit none\n','''
   implicit none
   real(8),save::macro_lat_dh=0d0,macro_lat_q=0d0,macro_lat_h=0d0,macro_lat_t=0d0,macro_lat_dt=0d0
   logical,save::macro_lat_ready=.false.
''')
 source=replace(source,'public :: boundtop','public :: macro_top_lateral_gradient\npublic :: boundtop')
 source=replace(source,'pondm1, dt, fluseksatexm','pondm1, dt, t1900, fluseksatexm')
 source=replace(source,'real(8)              :: h0,hcomean,k1Atm,p1,p2,p2Mp,q1,RsRoMp','real(8)              :: h0,hcomean,k1Atm,p1,p2,p2Mp,q1,RsRoMp,lat_a,lat_beta,lat_den,lat_raw')
 source=replace(source,'      FlRunoff = .FALSE.','      macro_lat_ready=.false.\n      FlRunoff = .FALSE.')
 anchor='''      return
      end subroutine boundtop'''
 extra='''      ! Scratch derivative only: saturated top conductivity and constant evaporation branch.
      ! Qlat = beta*s*(h0max-PndmxMp)/(s*(h0max+a)+beta), s=1+p1.
      if(swmacro==1.and.ArMpSs>0d0.and.h(1)>0d0.and.FlRunoff.and.ftoph)then
       if(pondm1>1d-10.or.Emax>max(peva,empreva))then
        if(h0max>PndmxMp.and.KsMpSs>0d0.and.QMpLatSs>=1d-7)then
         lat_a=(nraidt+nird+melt)*ArMpSs*dt
         lat_beta=dt*KsMpSs;lat_den=(1d0+p1)*(h0max+lat_a)+lat_beta
         lat_raw=lat_beta*(1d0+p1)*(h0max-PndmxMp)/lat_den
         if(lat_raw<h0max)then
          macro_lat_dh=lat_beta*p1*((1d0+p1)*(lat_a+PndmxMp)+lat_beta)/lat_den**2
         else if(lat_raw>h0max)then
          macro_lat_dh=p1/(1d0+p1)
         else
          return
         end if
         macro_lat_q=QMpLatSs;macro_lat_h=h(1);macro_lat_t=t1900;macro_lat_dt=dt
         macro_lat_ready=.true.
        end if
       end if
      end if
'''
 source=replace(source,anchor,extra+anchor)
 getter='''
      subroutine macro_top_lateral_gradient(dq,qp,valid)
      use variables,only:h,t1900,dt
      use MOD_swap_mp,only:QMpLatSs
      implicit none
      real(8),intent(out)::dq,qp,valid
      dq=0d0;qp=macro_lat_q;valid=0d0
      if(.not.macro_lat_ready)return
      if(h(1)/=macro_lat_h.or.t1900/=macro_lat_t.or.dt/=macro_lat_dt.or.QMpLatSs/=macro_lat_q)return
      dq=macro_lat_dh;valid=1d0
      end subroutine
'''
 return replace(source,'      end subroutine boundtop','      end subroutine boundtop\n'+getter)
