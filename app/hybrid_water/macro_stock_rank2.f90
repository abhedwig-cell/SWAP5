! Native current-cell saturated stock and main inflow geometry derivatives.
subroutine jac37_terms(n,uu,vv,bl,bd,diag_extra,meta,eligible)
use MOD_top,only:macro_top_lateral_gradient
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon, &
 QInMtxSatDmCp,QInIntSatDmCp,QOutMtxSatDmCp,QOutMtxUnsDmCp,FrReduQ
use MOD_swap_mp,only:swmbf,IcTopMp,IDecMpRat,GwlFlCpZo
use variables,only:h,theta,thetas,pegwl,dt,t1900,numbit
implicit none
integer,intent(in)::n
real(8),intent(out)::uu(macp,madm+1),vv(macp,madm+1),bl,bd,diag_extra(macp),meta(16)
logical,intent(out)::eligible
logical,external::macro_geometry_frozen_cell
real(8)::cm(24,madm),pot(macp,madm),pu(macp,madm),valid,den,g,g0,g1,depth,hm,delta,doo,rhoslope,cg,fr,dq,qp,latvalid,dI(macp),proof_base(macp),proof_meta(10),ct0(madm),ct1(madm),nativeU(madm),du0,du1,contact_valid,contactD1(2),upperIn(macp),dUpperIn(macp),upperValid,frIn1,upperG0,upperG1,upperBase(macp),dUpperOut(macp),upperContact(macp),lowerPS(macp),lowerPU(macp),lowerDL(macp),lowerL,lowerO,lowerF
real(8)::ordinary_base(macp,madm),ordinary_native
integer::d,k,i,cell,upper,lower
integer,save::proof_count=0,proof_unit,upper_count=0,upper_unit,lower_count=0,lower_unit
uu=0d0;vv=0d0;bl=0d0;bd=0d0;diag_extra=0d0;ordinary_base=0d0;meta=0d0;eligible=.false.;meta(1)=-1
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
if(any(cm(8,2:NumDm)/=1d0).or.any(cm(22,1:NumDm)/=0d0))return
frIn1=cm(8,1);meta(9)=frIn1
if(frIn1<0d0.or.frIn1>1d0)return
meta(10)=cm(16,1)
if(cm(16,1)<0d0.or.cm(16,1)>1d0)return
if(frIn1/=1d0.and.cm(16,1)/=1d0)return
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
 if(cm(16,1)>0d0)then
  call macro_contact_cell_gradient(1,cell,g0,g1,QOutMtxUnsDmCp(1,cell)*dt/cm(16,1),du0,du1,nativeU(1),contact_valid)
  if(contact_valid/=1d0)return
  contactD1=[-cm(16,1)*du0/dt-nativeU(1),-cm(16,1)*du1/dt]
 end if
 vv(upper,NumDm+1)=contactD1(1);vv(lower,NumDm+1)=contactD1(2)
 uu(cell,NumDm+1)=1d0
 do d=2,NumDm
  if(cm(16,d)==0d0)cycle
  call macro_contact_cell_gradient(d,cell,g0,g1,pu(cell,d-1),du0,du1,nativeU(d),contact_valid)
  if(contact_valid/=1d0)return
  ct0(d)=-cm(16,d)*du0/dt-nativeU(d);ct1(d)=-cm(16,d)*du1/dt
  vv(upper,NumDm+1)=vv(upper,NumDm+1)+ct0(d);vv(lower,NumDm+1)=vv(lower,NumDm+1)+ct1(d)
 end do
end if
! One stock normalization per bounded domain, with no duplicate contact derivative.
do d=2,NumDm
 k=d
 if(cm(5,d)<0d0.or.abs(cm(5,d)-(cm(9,d)+cm(10,d)+cm(12,d)))>128d0*epsilon(1d0)*max(cm(5,d),tiny(1d0)).or.cm(11,d)/=0d0)return
 if(cm(6,d)<0d0.or.dt<=0d0)return
 if(abs(sum(QInMtxSatDmCp(d,1:n))*dt-cm(12,d))>128d0*epsilon(1d0)*max(abs(cm(12,d)),tiny(1d0)))return
 if(cm(2,d)/=min(cm(4,d),cm(1,d)))return
 fr=cm(16,d);if(d<=3)meta(d+1)=fr
 if(fr<0d0.or.fr>1d0)return
 rhoslope=0d0
 if(cm(4,d)<=cm(1,d)+128d0*epsilon(1d0)*max(abs(cm(4,d)),abs(cm(1,d)),tiny(1d0)))then
  rhoslope=cm(18,d);if(d<=3)meta(d+3)=1d0
 end if
 if(cm(4,d)==cm(1,d).and.d<=3)meta(d+5)=1d0
 if(fr==0d0.or.fr==1d0)cycle
 if(cm(6,d)<=0d0.or.cm(15,d)/=0d0)return
 if(any(pu(cell+1:n,d-1)/=0d0))return
 if(abs(sum(pot(1:n,d-1))+sum(pu(1:n,d-1))-cm(6,d))>128d0*epsilon(1d0)*max(abs(cm(6,d)),tiny(1d0)))return
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
  call macro_contact_cell_gradient(d,cell,g0,g1,pu(cell,d-1),du0,du1,nativeU(d),contact_valid)
  if(contact_valid/=1d0)return
  dI(upper)=dI(upper)-fr*du0;dI(lower)=dI(lower)-fr*du1
 end if
 do i=1,cell-1
  if(pu(i,d-1)<=0d0)cycle
  call macro_contact_cell_gradient(d,i,0d0,0d0,pu(i,d-1),du0,du1,ordinary_native,contact_valid)
  if(contact_valid/=1d0.or.du1/=0d0)return
  dI(i)=dI(i)-fr*du0
  ordinary_base(i,d)=-fr*du0/dt
  diag_extra(i)=diag_extra(i)+ordinary_base(i,d)-ordinary_native
 end do
 vv(1:n,k)=dI(1:n)/cm(6,d)
 if(cm(17,d)/cm(21,d)<=1d-7.or.cm(6,d)<=cm(17,d))return
 do i=1,n
  if(pot(i,d-1)>0d0)then
   if(i<lower.or.h(i)<=0d0)return
   delta=max(0d0,cm(24,d)-z(i))-h(i)
   if(delta<=0d0)return
   doo=-pot(i,d-1)/delta;vv(i,k)=vv(i,k)-fr*doo/cm(6,d)
  end if
 end do
 uu(1:n,k)=-(pot(1:n,d-1)+pu(1:n,d-1))/dt
 vv(upper,k)=vv(upper,k)-rhoslope*g0/cm(6,d);vv(lower,k)=vv(lower,k)-rhoslope*g1/cm(6,d)
 meta(2)=meta(2)+1d0
end do
! D1 upper inventory projector: incoming matrix, outgoing Darcy/contact and fixed rapid drainage.
! Slot1 belongs toD1; every other lower constraint has its domain slot.
if(frIn1>0d0.and.frIn1<1d0)then
 if(cm(5,1)<=0d0.or.cm(3,1)/=cm(4,1).or.any(cm(9:11,1)/=0d0))return
 if(abs(cm(6,1)-sum(cm(13:15,1)))>128d0*epsilon(1d0)*max(cm(6,1),tiny(1d0)))return
 if(any(QOutMtxUnsDmCp(1,cell+1:n)/=0d0))return
 if(cm(5,1)/=cm(12,1).or.cm(5,1)/dt<=1d-7)return
 if(cm(7,1)<=cm(3,1)+1d-7)return
 if(abs(frIn1-(cm(3,1)-cm(1,1)+cm(6,1))/cm(5,1))>256d0*epsilon(1d0)* &
  max(1d0,abs(cm(3,1)/cm(5,1))))return
 if(.not.macro_geometry_frozen_cell(cell))return
 call macro_upper1_data(upperIn,upperValid)
 if(upperValid/=1d0)return
 if(abs(sum(upperIn(1:n))-cm(5,1))>128d0*epsilon(1d0)*max(cm(5,1),tiny(1d0)))return
 dUpperIn=0d0;upperBase=0d0;dUpperOut=0d0;upperContact=0d0
 do i=lower,n
  if(upperIn(i)>0d0)then
   hm=max(0d0,cm(24,1)-z(i))
   if(hm<1d-8)hm=0d0
   delta=h(i)-hm
   if(delta<=0d0)return
   dUpperIn(i)=upperIn(i)/delta
   upperBase(i)=QInMtxSatDmCp(1,i)/delta
  end if
  if(QOutMtxSatDmCp(1,i)>0d0)then
   hm=max(0d0,cm(24,1)-z(i));delta=hm-h(i)
   if(delta<=1d-8)return
   dUpperOut(i)=-dt*QOutMtxSatDmCp(1,i)/delta
   upperBase(i)=upperBase(i)+QOutMtxSatDmCp(1,i)/delta
  end if
 end do
 if(h(cell)<0d0)then
  call macro_contact_cell_gradient(1,cell,g0,g1,dt*QOutMtxUnsDmCp(1,cell),du0,du1,nativeU(1),contact_valid)
  if(contact_valid/=1d0)return
  dUpperOut(upper)=dUpperOut(upper)+du0;dUpperOut(lower)=dUpperOut(lower)+du1
  upperBase(cell)=upperBase(cell)+nativeU(1)
  upperContact(upper)=contactD1(1);upperContact(lower)=contactD1(2)
 end if
 if(h(cell)>=0d0)then
  dUpperIn(upper)=dUpperIn(upper)+upperIn(cell)/depth*g0
  dUpperIn(lower)=dUpperIn(lower)+upperIn(cell)/depth*g1
 end if
 do i=1,cell-1
  if(QOutMtxUnsDmCp(1,i)<=0d0)cycle
  call macro_contact_cell_gradient(1,i,0d0,0d0,dt*QOutMtxUnsDmCp(1,i),du0,du1,ordinary_native,contact_valid)
  if(contact_valid/=1d0.or.du1/=0d0)return
  dUpperOut(i)=dUpperOut(i)+du0
  upperBase(i)=upperBase(i)-du0/dt
  diag_extra(i)=diag_extra(i)-du0/dt-ordinary_native
 end do
 uu(1:n,1)=upperIn(1:n)/dt
 vv(1:n,1)=(dUpperOut(1:n)-frIn1*dUpperIn(1:n))/cm(5,1)
 vv(upper,1)=vv(upper,1)+cm(18,1)*g0/cm(5,1)
 vv(lower,1)=vv(lower,1)+cm(18,1)*g1/cm(5,1)
 meta(2)=meta(2)+1d0
 upper_count=upper_count+1
 if(upper_count<=64)then
  if(upper_count==1)open(newunit=upper_unit,file='macro_upper1_complete_inventory_terms.txt',status='replace')
  write(upper_unit,*)n,t1900,dt,numbit,cell,upper,lower,frIn1,cm(5,1),cm(6,1),cm(1,1),cm(3,1),cm(18,1),g0,g1,depth
  write(upper_unit,*)upperIn(1:n),upperBase(1:n),uu(1:n,1),vv(1:n,1),QInMtxSatDmCp(1,1:n),upperContact(1:n)
 end if
end if
! D1 lower inventory projection, including fixed rapid outflow in total O.
lowerF=cm(16,1)
if(frIn1==1d0.and.lowerF>0d0.and.lowerF<1d0)then
 lowerL=cm(2,1);lowerO=cm(6,1)
 if(lowerO<=0d0.or.cm(17,1)/dt<=1d-7.or.lowerO<=cm(17,1))return
 if(cm(11,1)/=0d0.or.any(QInIntSatDmCp(1,1:n)/=0d0))return
 if(abs(cm(5,1)-sum(cm(9:12,1)))>128d0*epsilon(1d0)*max(cm(5,1),tiny(1d0)))return
 if(abs(lowerO-sum(cm(13:15,1)))>128d0*epsilon(1d0)*max(lowerO,tiny(1d0)))return
 if(any(QOutMtxUnsDmCp(1,cell+1:n)/=0d0))return
 if(.not.macro_geometry_frozen_cell(cell))return
 call macro_upper1_data(upperIn,upperValid)
 if(upperValid/=1d0)return
 if(abs(sum(upperIn(1:n))-cm(12,1))>128d0*epsilon(1d0)*max(cm(12,1),tiny(1d0)))return
 dUpperIn=0d0;dUpperOut=0d0;upperBase=0d0;lowerPS=0d0;lowerPU=0d0;lowerDL=0d0;upperContact=0d0
 lowerPS(1:n)=dt*QOutMtxSatDmCp(1,1:n)/lowerF
 lowerPU(1:n)=dt*QOutMtxUnsDmCp(1,1:n)/lowerF
 if(abs(sum(lowerPS(1:n))-cm(13,1))>256d0*epsilon(1d0)*max(cm(13,1),tiny(1d0)))return
 if(abs(sum(lowerPU(1:n))-cm(14,1))>256d0*epsilon(1d0)*max(cm(14,1),tiny(1d0)))return
 if(cm(10,1)>0d0)then
  call macro_top_lateral_gradient(dq,qp,latvalid)
  if(latvalid/=1d0.or.qp<=0d0)return
  dUpperIn(1)=cm(10,1)/qp*dq
 end if
 do i=lower,n
  hm=max(0d0,cm(24,1)-z(i))
  if(hm<1d-8)hm=0d0
  if(upperIn(i)>0d0)then
   delta=h(i)-hm
   if(delta<=0d0)return
   dUpperIn(i)=upperIn(i)/delta
   upperBase(i)=QInMtxSatDmCp(1,i)/delta
  end if
  if(lowerPS(i)>0d0)then
   delta=hm-h(i)
   if(delta<=1d-8)return
   dUpperOut(i)=-lowerPS(i)/delta
   upperBase(i)=upperBase(i)+QOutMtxSatDmCp(1,i)/delta
  end if
 end do
 if(h(cell)>=0d0)then
  dUpperIn(upper)=dUpperIn(upper)+upperIn(cell)/depth*g0
  dUpperIn(lower)=dUpperIn(lower)+upperIn(cell)/depth*g1
 end if
 if(h(cell)<0d0)then
  call macro_contact_cell_gradient(1,cell,g0,g1,lowerPU(cell),du0,du1,nativeU(1),contact_valid)
  if(contact_valid/=1d0)return
  dUpperOut(upper)=dUpperOut(upper)+du0;dUpperOut(lower)=dUpperOut(lower)+du1
  upperBase(cell)=upperBase(cell)+nativeU(1)
  upperContact(upper)=contactD1(1);upperContact(lower)=contactD1(2)
 end if
 do i=1,cell-1
  if(lowerPU(i)<=0d0)cycle
  call macro_contact_cell_gradient(1,i,0d0,0d0,lowerPU(i),du0,du1,ordinary_native,contact_valid)
  if(contact_valid/=1d0.or.du1/=0d0)return
  dUpperOut(i)=dUpperOut(i)+du0
  upperBase(i)=upperBase(i)-lowerF*du0/dt
  diag_extra(i)=diag_extra(i)-lowerF*du0/dt-ordinary_native
 end do
 if(lowerL==cm(4,1).and.cm(4,1)<=cm(1,1)+128d0*epsilon(1d0)*max(abs(cm(4,1)),abs(cm(1,1)),tiny(1d0)))then
  lowerDL(upper)=cm(18,1)*g0;lowerDL(lower)=cm(18,1)*g1
 else if(lowerL/=cm(1,1).and.lowerL>=min(cm(4,1),cm(1,1)))then
  return
 end if
 uu(1:n,1)=-(lowerPS(1:n)+lowerPU(1:n))/dt
 vv(1:n,1)=(dUpperIn(1:n)-lowerDL(1:n)-lowerF*dUpperOut(1:n))/lowerO
 meta(2)=meta(2)+1d0
 lower_count=lower_count+1
 if(lower_count<=64)then
  if(lower_count==1)open(newunit=lower_unit,file='macro_lower1_inventory_terms.txt',status='replace')
  write(lower_unit,*)n,t1900,dt,numbit,cell,upper,lower,lowerF,cm(5,1),lowerO,cm(1,1),lowerL,cm(4,1),cm(18,1),g0,g1,cm(15,1),depth
  write(lower_unit,*)upperIn(1:n),lowerPS(1:n)+lowerPU(1:n),upperBase(1:n),uu(1:n,1),vv(1:n,1),QInMtxSatDmCp(1,1:n),upperContact(1:n)
 end if
end if
meta(1)=1d0;eligible=.true.
! Primitive state and actual local derivatives for independent all-domain inventory.
proof_count=proof_count+1
if(proof_count<=64)then
 if(proof_count==1)open(newunit=proof_unit,file='macro_saturated_contact_mass_base.txt',status='replace')
 proof_meta=[dble(cell),dble(upper),dble(lower),h(upper),h(lower),z(upper),z(lower),depth,contactD1]
 write(proof_unit,*)n,NumDm+1,t1900,dt,numbit
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
  proof_base=proof_base+ordinary_base(:,d)
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
real(8)::uu(macp,madm+1),vv(macp,madm+1),meta(16),bl,bd,diag_extra(macp),aa(n),bb(n),zz(n,madm+1),M(madm+1,madm+1),rhs(madm+1),lam(madm+1),res(n)
real(8)::aug(madm+1,madm+2),row(madm+2),pivot,factor
integer::k,i,e,cell,nr,j,ip
logical,save::opened=.false.
integer,save::tu,systems_unit=0,active_count=0
call jac37_terms(n,uu,vv,bl,bd,diag_extra,meta,handled)
M=0d0;lam=0d0;res=-1d0;nr=NumDm+1
if(handled) then
 cell=int(meta(14));aa=a;bb=b+diag_extra(1:n);aa(cell)=aa(cell)+bl;bb(cell)=bb(cell)+bd
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
logical,external::macro_geometry_frozen_cell
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
if(.not.macro_geometry_frozen_cell(cell))return
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
