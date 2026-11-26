! Native current-cell saturated stock and main inflow geometry derivatives.
subroutine jac37_terms(n,uu,vv,bl,bd,meta,eligible)
use MOD_top,only:macro_top_lateral_gradient
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon, &
 QInMtxSatDmCp,QInIntSatDmCp,QOutMtxSatDmCp,QOutMtxUnsDmCp,FrReduQ
use MOD_swap_mp,only:swmbf,IcTopMp,IDecMpRat,GwlFlCpZo
use variables,only:h,theta,thetas,pegwl,dt,t1900,numbit
implicit none
integer,intent(in)::n
real(8),intent(out)::uu(macp,madm),vv(macp,madm),bl,bd,meta(16)
logical,intent(out)::eligible
real(8)::cm(24,madm),pot(macp,madm),pu(macp,madm),valid,den,g,g0,g1,depth,hm,delta,doo,rhoslope,cg,fr,dq,qp,latvalid,dI(macp),proof_base(macp),proof_meta(10),ct0(madm),ct1(madm),nativeU(madm),du0,du1,contact_valid,contactD1(2)
integer::d,k,i,cell,upper,lower
integer,save::proof_count=0,proof_unit
uu=0d0;vv=0d0;bl=0d0;bd=0d0;meta=0d0;eligible=.false.;meta(1)=-1
if(n/=numnod.or.n<2.or.NumDm<3.or.swmbf/=1.or.IcTopMp/=1.or.IDecMpRat/=0.or.FrReduQ/=1d0)return
call macro_saturated_data(cm,pot,pu,valid);meta(15)=valid;meta(1)=-2
if(valid/=1d0)return
cell=ICpTpSatZon;upper=cell-1
meta(1)=-3
if(cell<2.or.cell>n.or.ICpTpPerZon/=cell.or.ICpBtPerZon/=-1.or.pegwl<990d0)return
lower=cell
if(h(cell)<0d0)then
 upper=cell;lower=cell+1
end if
if(lower>n)return
if(h(upper)>=0d0.or.any(h(lower:n)<=0d0).or.any(theta(lower:n)/=thetas(lower:n)))return
den=h(lower)-h(upper)
g=z(lower)+h(lower)/den*(z(upper)-z(lower))
if(abs(g-GwlFlCpZo)>1d-9)return
g0=(z(upper)-z(lower))*h(lower)/den**2;g1=-(z(upper)-z(lower))*h(upper)/den**2
meta(13)=g;meta(14)=dble(cell);meta(16)=theta(upper)-thetas(upper)
meta(1)=-4
if(any(cm(8,1:NumDm)/=1d0).or.any(cm(22,1:NumDm)/=0d0))return
if(cm(16,1)/=1d0)return
meta(1)=-5
if(any(QInIntSatDmCp(1:NumDm,1:n)/=0d0))return
depth=g-(z(cell)-.5d0*dz(cell))
if(depth<=0d0.or.depth>=dz(cell))return
cg=sum(QInMtxSatDmCp(1:NumDm,cell))/depth
bl=0d0;bd=0d0
if(h(cell)>=0d0)then
 bl=cg*g0;bd=cg*g1
end if
meta(11)=cg;meta(12)=0d0;meta(1)=-6
ct0=0d0;ct1=0d0;nativeU=0d0;contactD1=0d0
! Complete current contact row, including unconstrained domains, exactly once.
if(h(cell)<0d0)then
 call macro_contact_cell_gradient(1,cell,g0,g1,QOutMtxUnsDmCp(1,cell)*dt,du0,du1,nativeU(1),contact_valid)
 if(contact_valid/=1d0)return
 contactD1=[-du0/dt-nativeU(1),-du1/dt]
 vv(upper,NumDm)=contactD1(1);vv(lower,NumDm)=contactD1(2)
 uu(cell,NumDm)=1d0
 do d=2,NumDm
  call macro_contact_cell_gradient(d,cell,g0,g1,pu(cell,d-1),du0,du1,nativeU(d),contact_valid)
  if(contact_valid/=1d0)return
  ct0(d)=-cm(16,d)*du0/dt-nativeU(d);ct1(d)=-cm(16,d)*du1/dt
  vv(upper,NumDm)=vv(upper,NumDm)+ct0(d);vv(lower,NumDm)=vv(lower,NumDm)+ct1(d)
 end do
end if
! One stock normalization per bounded domain, with no duplicate contact derivative.
do k=1,NumDm-1
 d=k+1
 if(cm(5,d)<0d0.or.abs(cm(5,d)-(cm(9,d)+cm(10,d)+cm(12,d)))>128d0*epsilon(1d0)*max(cm(5,d),tiny(1d0)).or.cm(11,d)/=0d0)return
 if(cm(6,d)<0d0.or.dt<=0d0)return
 if(abs(sum(QInMtxSatDmCp(d,1:n))*dt-cm(12,d))>128d0*epsilon(1d0)*max(abs(cm(12,d)),tiny(1d0)))return
 if(cm(2,d)/=min(cm(4,d),cm(1,d)))return
 fr=cm(16,d);if(k<=2)meta(2+k)=fr
 if(fr<0d0.or.fr>1d0)return
 rhoslope=0d0
 if(cm(4,d)<=cm(1,d)+128d0*epsilon(1d0)*max(abs(cm(4,d)),abs(cm(1,d)),tiny(1d0)))then
  rhoslope=cm(18,d);if(k<=2)meta(4+k)=1d0
 end if
 if(cm(4,d)==cm(1,d).and.k<=2)meta(6+k)=1d0
 if(fr==0d0.or.fr==1d0)cycle
 if(cm(6,d)<=0d0.or.cm(15,d)/=0d0)return
 if(any(pu(1:cell-1,k)/=0d0).or.any(pu(cell+1:n,k)/=0d0))return
 if(abs(sum(pot(1:n,k))+sum(pu(1:n,k))-cm(6,d))>128d0*epsilon(1d0)*max(abs(cm(6,d)),tiny(1d0)))return
 dI=0d0
 if(cm(10,d)>0d0)then
  call macro_top_lateral_gradient(dq,qp,latvalid)
  if(latvalid/=1d0.or.qp<=0d0)return
  dI(1)=cm(10,d)/qp*dq
 end if
 do i=lower,n
  if(QInMtxSatDmCp(d,i)>0d0)then
   hm=max(0d0,cm(24,d)-z(i))
   if(hm<1d-8)hm=0d0
   delta=h(i)-hm
   if(delta<=0d0)return
   dI(i)=dt*QInMtxSatDmCp(d,i)/delta
  end if
 end do
 dI(upper)=dI(upper)+dt*QInMtxSatDmCp(d,cell)/depth*g0
 dI(lower)=dI(lower)+dt*QInMtxSatDmCp(d,cell)/depth*g1
 if(h(cell)<0d0)then
  call macro_contact_cell_gradient(d,cell,g0,g1,pu(cell,k),du0,du1,nativeU(d),contact_valid)
  if(contact_valid/=1d0)return
  dI(upper)=dI(upper)-fr*du0;dI(lower)=dI(lower)-fr*du1
 end if
 vv(1:n,k)=dI(1:n)/cm(6,d)
 if(cm(17,d)/cm(21,d)<=1d-7.or.cm(6,d)<=cm(17,d))return
 do i=1,n
  if(pot(i,k)>0d0)then
   if(i<lower.or.h(i)<=0d0)return
   delta=max(0d0,cm(24,d)-z(i))-h(i)
   if(delta<=0d0)return
   doo=-pot(i,k)/delta;vv(i,k)=vv(i,k)-fr*doo/cm(6,d)
  end if
 end do
 uu(1:n,k)=-(pot(1:n,k)+pu(1:n,k))/dt
 vv(upper,k)=vv(upper,k)-rhoslope*g0/cm(6,d);vv(lower,k)=vv(lower,k)-rhoslope*g1/cm(6,d)
 meta(2)=meta(2)+1d0
end do
meta(1)=1d0;eligible=.true.
! Primitive state and actual local derivatives for independent all-domain inventory.
proof_count=proof_count+1
if(proof_count<=64)then
 if(proof_count==1)open(newunit=proof_unit,file='macro_saturated_contact_mass_base.txt',status='replace')
 proof_meta=[dble(cell),dble(upper),dble(lower),h(upper),h(lower),z(upper),z(lower),depth,contactD1]
 write(proof_unit,*)n,NumDm,t1900,dt,numbit
 write(proof_unit,*)proof_meta
 do d=2,NumDm
  dq=0d0;qp=0d0;latvalid=0d0
  if(cm(10,d)>0d0)call macro_top_lateral_gradient(dq,qp,latvalid)
  if(qp>0d0)dq=cm(10,d)/qp*dq
  write(proof_unit,*)cm(16,d),cm(18,d),merge(1d0,0d0,cm(4,d)<=cm(1,d)+128d0*epsilon(1d0)*max(abs(cm(4,d)),abs(cm(1,d)),tiny(1d0))),QInMtxSatDmCp(d,cell),dq,ct0(d),ct1(d)
  proof_base=0d0
  do i=1,n
   hm=max(0d0,cm(24,d)-z(i))
   if(hm<1d-8)hm=0d0
   delta=hm-h(i)
   if(abs(delta)>1d-14)proof_base(i)=(QOutMtxSatDmCp(d,i)-QInMtxSatDmCp(d,i))/delta
  end do
  proof_base(cell)=proof_base(cell)+nativeU(d)
  write(proof_unit,*)proof_base(1:n)
 end do
end if
end subroutine

subroutine jac37_solve(n,a,b,c,r,x,ierror,handled)
use MOD_arrays,only:macp,madm
use MOD_macropore,only:NumDm
use,intrinsic::ieee_arithmetic,only:ieee_is_finite
use variables,only:t1900,dt,numbit
implicit none
integer,intent(in)::n
real(8),intent(in)::a(n),b(n),c(n),r(n)
real(8),intent(out)::x(n)
integer,intent(out)::ierror
logical,intent(out)::handled
real(8)::uu(macp,madm),vv(macp,madm),meta(16),bl,bd,aa(n),bb(n),zz(n,madm),M(madm,madm),rhs(madm),lam(madm),res(n)
real(8)::aug(madm,madm+1),row(madm+1),pivot,factor
integer::k,i,e,cell,nr,j,ip
logical,save::opened=.false.
integer,save::tu,systems_unit=0,active_count=0
call jac37_terms(n,uu,vv,bl,bd,meta,handled)
M=0d0;lam=0d0;res=-1d0;nr=NumDm
if(handled) then
 cell=int(meta(14));aa=a;bb=b;aa(cell)=aa(cell)+bl;bb(cell)=bb(cell)+bd
 call tridag(n,aa,bb,c,r,x,ierror)
 if(ierror/=0)error stop 'Saturated multi-domain base solve failed'
 zz=0d0
 do k=1,nr
  if(all(uu(1:n,k)==0d0))cycle
  call tridag(n,aa,bb,c,uu(1:n,k),zz(:,k),e)
  if(e/=0)error stop 'Saturated multi-domain update solve failed'
 end do
 do k=1,nr
  M(k,k)=1d0
  do i=1,nr
   M(k,i)=M(k,i)+dot_product(vv(1:n,k),zz(:,i))
  end do
  rhs(k)=dot_product(vv(1:n,k),x)
 end do
 aug=0d0;aug(1:nr,1:nr)=M(1:nr,1:nr);aug(1:nr,nr+1)=rhs(1:nr)
 do k=1,nr
  ip=k-1+maxloc(abs(aug(k:nr,k)),dim=1)
  pivot=aug(ip,k)
  if(.not.ieee_is_finite(pivot).or.abs(pivot)<1d-12)error stop 'Saturated multi-domain update singular'
  row=aug(k,:);aug(k,:)=aug(ip,:);aug(ip,:)=row
  do i=k+1,nr
   factor=aug(i,k)/aug(k,k)
   aug(i,k:nr+1)=aug(i,k:nr+1)-factor*aug(k,k:nr+1)
  end do
 end do
 do k=nr,1,-1
  lam(k)=(aug(k,nr+1)-dot_product(aug(k,k+1:nr),lam(k+1:nr)))/aug(k,k)
 end do
 do k=1,nr
  x=x-zz(:,k)*lam(k)
 end do
 res=bb*x-r
 do i=2,n
  res(i)=res(i)+aa(i)*x(i-1)
 end do
 do i=1,n-1
  res(i)=res(i)+c(i)*x(i+1)
 end do
 do k=1,nr
  res=res+uu(1:n,k)*dot_product(vv(1:n,k),x)
 end do
 if(any(.not.ieee_is_finite(x)))error stop 'Nonfinite saturated multi-domain correction'
end if
if(.not.opened)then
 open(newunit=tu,file='jac37_trace.txt',status='replace');opened=.true.
end if
write(tu,*)t1900,dt,numbit,meta,bl,bd,merge(maxval(abs(res)),-1d0,handled)
if(handled)then
 active_count=active_count+1
 if(active_count<=64)then
  if(systems_unit==0)open(newunit=systems_unit,file='macro_saturated_contact_systems.txt',status='replace')
  write(systems_unit,*)n,nr,t1900,dt,numbit
  write(systems_unit,*)aa,bb,c,r,uu(1:n,1:nr),vv(1:n,1:nr),x
 end if
end if
end subroutine

! Stop an initial Newton line at the first current minimum-stock kink.
! Subsequent backtracking uses the original factor/3 and unchanged trial budget.
subroutine macro_stock_step_fraction(n,hold,difh,cap,factor)
use MOD_arrays,only:macp,madm
use MOD_grid,only:z,numnod
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,VlMpDyCp,SubsidCp,FrReduQ
use MOD_swap_mp,only:swmbf,IDecMpRat
use variables,only:t1900,dt,numbit,theta,thetas
use,intrinsic::ieee_arithmetic,only:ieee_is_finite
implicit none
integer,intent(in)::n
real(8),intent(in)::hold(n),difh(n),cap
real(8),intent(inout)::factor
real(8)::cm(24,madm),ps(macp,madm),pu(macp,madm),valid,zm,A,B,num,den,lambda,tie
integer::cell,upper,lower,d
integer,save::u=0
if(n/=numnod.or.cap<=0d0.or.swmbf/=1.or.IDecMpRat/=0.or.FrReduQ/=1d0)return
call macro_saturated_data(cm,ps,pu,valid)
if(valid/=1d0)return
cell=ICpTpSatZon;lower=cell;upper=cell-1
if(cell<2.or.cell>=n.or.ICpTpPerZon/=cell.or.ICpBtPerZon/=-1)return
if(hold(cell)<0d0)then
 upper=cell;lower=cell+1
end if
if(hold(upper)>=0d0.or.hold(lower)<=0d0)return
if(thetas(cell)-theta(cell)>1d-6.or.VlMpDyCp(cell)/=0d0.or.SubsidCp(cell)/=0d0)return
do d=2,NumDm
 if(cm(8,d)/=1d0.or.cm(22,d)/=0d0.or.cm(18,d)<=0d0.or.cm(2,d)/=min(cm(4,d),cm(1,d)))cycle
 tie=128d0*epsilon(1d0)*max(abs(cm(4,d)),abs(cm(1,d)),tiny(1d0))
 if(abs(cm(4,d)-cm(1,d))<=tie)cycle
 zm=cm(24,d)
 if(zm<=z(lower).or.zm>=z(upper))cycle
 A=z(lower)-zm;B=zm-z(upper)
 num=A*hold(upper)+B*hold(lower);den=cap*(A*difh(upper)+B*difh(lower))
 if(den==0d0)cycle
 lambda=num/den
 if(.not.ieee_is_finite(lambda).or.lambda<=0d0.or.lambda>=factor)cycle
 if(hold(upper)-lambda*cap*difh(upper)>=0d0.or.hold(lower)-lambda*cap*difh(lower)<=0d0)cycle
 factor=lambda
 if(u==0)open(newunit=u,file='macro_stock_kink_steps.txt',status='replace')
 write(u,*)t1900,dt,numbit,d,upper,lower,z(upper),z(lower),hold(upper),hold(lower),difh(upper),difh(lower),cap,lambda,zm,cm(4,d),cm(1,d)
end do
end subroutine
