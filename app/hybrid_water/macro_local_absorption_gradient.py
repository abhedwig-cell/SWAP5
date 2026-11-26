"""Differentiate the original moisture factor in the unsaturated Darcy branch."""
from donor_sources import replace

def render(source):
 source=source.replace('\r\n','\n');a=source.index('      subroutine ABSORPTION(');b=source.index('      end subroutine',a)
 body=source[a:b]
 body=replace(body,'only: moiscap, cofgen','only: moiscap, cofgen, dhconduc')
 body=replace(body,'only: thetas, theta, thetar, dt, h, k,t1900','only: thetas, theta, thetar, dt, h, k,t1900,swkimpl')
 body=replace(body,'      use MOD_swap_mp,only:GwlFlCpZo','      use MOD_swap_mp,only:GwlFlCpZo,FrArMtrx\n      use MOD_frost,only:rfcp')
 body=replace(body,'      real(8)                             :: Deriv, HMp, RecRes, SatDefMtx','      real(8)                             :: Deriv, HMp, RecRes, SatDefMtx\n      real(8)::absorbSF,absorbSFprime,absorbDef,absorbC,absorbDK')
 old='''                  if (abs(DelHDmCp(id,ic)) > 1.d-14) then
                     Deriv = - QOutMtxUnsDmCp(id,ic) / DelHDmCp(id,ic)
                  end if'''
 new=old+'''
                  ! The same active Darcy law also depends on its moisture factor.
                  Lay=Layer(ic);absorbDef=max(0d0,ThetaS(ic)-Theta(ic))
                  absorbC=moiscap(ic,H(ic));absorbSFprime=0d0
                  absorbSF=1d0-(1d0-SorpFacParl(Lay))*(absorbDef/(ThetaS(ic)-ThetaR(ic)))**SorpAlfa(Lay)
                  if(absorbDef>0d0)absorbSFprime=(1d0-SorpFacParl(Lay))*SorpAlfa(Lay)* &
                     (absorbDef/(ThetaS(ic)-ThetaR(ic)))**(SorpAlfa(Lay)-1d0)*absorbC/(ThetaS(ic)-ThetaR(ic))
                  if(absorbSF<=0d0)error stop 'Invalid active Darcy moisture factor'
                  Deriv=Deriv+QOutMtxUnsDmCp(id,ic)*absorbSFprime/absorbSF
                  ! Keep the original conductivity-update policy of the host iteration.
                  if(SwKimpl==1)then
                     if(K(ic)<=0d0)error stop 'Invalid active Darcy conductivity'
                     absorbDK=FrArMtrx(ic)*dhconduc(ic,H(ic),Theta(ic),absorbC,rfcp(ic))
                     Deriv=Deriv+QOutMtxUnsDmCp(id,ic)*absorbDK/K(ic)
                  end if'''
 return source[:a]+replace(body,old,new)+source[b:]
