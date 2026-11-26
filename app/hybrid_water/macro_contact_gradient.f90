
! Original ABSORPTION derivative: partial main-GWL contact or full-contact ordinary cell.
subroutine macro_contact_cell_gradient(d,cell,g0,g1,pu,du0,du1,native,valid)
use MOD_grid,only:z,dz,layer
use MOD_macropore,only:ICpTpWaSrDm,ZWaLevDm,TimAbsCumDmCp,ThtSrpRefDmCp, &
 SorpMax,SorpAlfa,PpDmCp,AwlCorFac,DiPoCp,FrMpWalWet,SwAbs,SwDarcy,ShapeFacMp,SorpFacParl,QOutMtxUnsDmCp,VlMpDyCp,SubsidCp
use MOD_swap_mp,only:GwlFlCpZo,FrArMtrx
use MOD_MvG,only:moiscap,dhconduc
use MOD_frost,only:rfcp
use variables,only:h,theta,thetas,thetar,k,dt,swkimpl
implicit none
integer,intent(in)::d,cell
real(8),intent(in)::g0,g1,pu
real(8),intent(out)::du0,du1,native,valid
real(8)::ztop,span,overlap,deficit,active,age,power,C,rawS,rawD,ds,dd,wet,amp,ratio,sfac,dsfac,hm,delta,raw,der,dk
integer::lay
du0=0d0;du1=0d0;native=0d0;valid=0d0
if(h(cell)>=0d0)then
 if(pu==0d0)valid=1d0
 return
end if
if(VlMpDyCp(cell)/=0d0.or.SubsidCp(cell)/=0d0.or.thetas(cell)-theta(cell)>1d-6)return
ztop=min(z(cell)+.5d0*dz(cell),ZWaLevDm(d));span=max(0d0,ztop-(z(cell)-.5d0*dz(cell)))
overlap=max(0d0,ztop-max(z(cell)-.5d0*dz(cell),GwlFlCpZo))
if(span<=0d0.or.overlap<=0d0.or.cell<ICpTpWaSrDm(d))then
 if(pu==0d0)valid=1d0
 return
end if
if(SwAbs/=1)return
lay=layer(cell);C=moiscap(cell,h(cell));power=SorpAlfa(lay)
deficit=max(0d0,thetas(cell)-theta(cell));active=ThtSrpRefDmCp(d,cell)-theta(cell);age=TimAbsCumDmCp(d,cell)
rawS=0d0;ds=0d0;rawD=0d0;dd=0d0
if(deficit>=1d-8.and.active>1d-8.and.age>=0d0)then
 wet=1d0
 if(cell==ICpTpWaSrDm(d))wet=FrMpWalWet(d,cell)
 rawS=4d0*AwlCorFac(cell)*PpDmCp(d,cell)*dz(cell)/DiPoCp(cell)*wet*SorpMax(lay) &
  *(active/(thetas(cell)-thetar(cell)))**power*(sqrt(age+dt)-sqrt(age))
 ds=-rawS*power*C/active
 if(rawS==1d3*dt*dz(cell))return
 if(rawS>1d3*dt*dz(cell))then
  rawS=1d3*dt*dz(cell);ds=0d0
 end if
end if
if(SwDarcy>0.and.cell>ICpTpWaSrDm(d))then
 hm=max(0d0,ZWaLevDm(d)-z(cell));delta=max(0d0,hm-h(cell))
 if(hm>1d-8.and.delta>0d0)then
  if(k(cell)<=0d0.or.DiPoCp(cell)<=0d0)return
  ratio=deficit/(thetas(cell)-thetar(cell))
  sfac=1d0-(1d0-SorpFacParl(lay))*ratio**power
  dsfac=0d0
  if(deficit>0d0)dsfac=(1d0-SorpFacParl(lay))*power*ratio**(power-1d0)*C/(thetas(cell)-thetar(cell))
  amp=ShapeFacMp*8d0*PpDmCp(d,cell)*dz(cell)/DiPoCp(cell)**2*k(cell)*delta*dt
  dk=0d0
  if(SwKimpl==1)dk=FrArMtrx(cell)*dhconduc(cell,h(cell),theta(cell),C,rfcp(cell))
  rawD=sfac*amp;dd=amp*(dsfac+sfac*(dk/k(cell)-1d0/delta))
 end if
end if
if(rawS==rawD.and.rawS>0d0)return
if(rawS>rawD)then
 raw=rawS;der=ds
 if(QOutMtxUnsDmCp(d,cell)>1d-7)native=QOutMtxUnsDmCp(d,cell)*power*C/active
else
 raw=rawD;der=dd
 if(QOutMtxUnsDmCp(d,cell)>1d-7)native=QOutMtxUnsDmCp(d,cell)*(1d0/delta-dsfac/sfac-dk/k(cell))
end if
if(abs(pu-raw*overlap/span)>256d0*epsilon(1d0)*max(abs(pu),abs(raw*overlap/span),tiny(1d0)))return
if(overlap>=span)then
 du0=der;du1=0d0
else
 du0=der*overlap/span-raw/span*g0;du1=-raw/span*g1
end if
valid=1d0
end subroutine
