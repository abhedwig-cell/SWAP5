! Native current-cell saturated stock and main inflow geometry derivatives.
subroutine jac37_terms(n,uu,vv,bl,bd,meta,eligible)
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon, &
 QInMtxSatDmCp,QInIntSatDmCp,QOutMtxSatDmCp,QOutMtxUnsDmCp,FrReduQ
use MOD_swap_mp,only:swmbf,IcTopMp,IDecMpRat,GwlFlCpZo
use variables,only:h,theta,thetas,pegwl,dt,t1900,numbit
implicit none
integer,intent(in)::n
real(8),intent(out)::uu(macp,2),vv(macp,2),bl,bd,meta(16)
logical,intent(out)::eligible
real(8)::cm(24,madm),pot(macp,2),valid,den,g,g0,g1,depth,hm,delta,doo,rhoslope,cg,fr,dI(macp),proof_base(macp),proof_meta(24)
integer::d,k,i,cell,upper
integer,save::proof_count=0,proof_unit
uu=0d0;vv=0d0;bl=0d0;bd=0d0;meta=0d0;eligible=.false.;meta(1)=-1
if(n/=numnod.or.n<2.or.NumDm<3.or.swmbf/=1.or.IcTopMp/=1.or.IDecMpRat/=0.or.FrReduQ/=1d0)return
call macro_rank2_data(cm,pot,valid);meta(15)=valid;meta(1)=-2
if(valid/=1d0)return
cell=ICpTpSatZon;upper=cell-1
meta(1)=-3
if(cell<2.or.cell>n.or.ICpTpPerZon/=cell.or.ICpBtPerZon/=-1.or.pegwl<990d0)return
if(h(upper)>=0d0.or.any(h(cell:n)<=0d0).or.any(theta(cell:n)/=thetas(cell:n)))return
den=h(cell)-h(upper)
g=z(cell)+h(cell)/den*(z(upper)-z(cell))
if(abs(g-GwlFlCpZo)>1d-9)return
g0=(z(upper)-z(cell))*h(cell)/den**2;g1=-(z(upper)-z(cell))*h(upper)/den**2
meta(13)=g;meta(14)=dble(cell);meta(16)=theta(upper)-thetas(upper)
meta(1)=-4
if(any(cm(8,1:NumDm)/=1d0).or.any(cm(22,1:NumDm)/=0d0))return
if(cm(16,1)/=1d0)return
if(NumDm>3)then
 if(any(cm(16,4:NumDm)/=1d0))return
end if
meta(1)=-5
if(any(QInIntSatDmCp(1:NumDm,1:n)/=0d0))return
if(any(QOutMtxUnsDmCp(1:NumDm,cell)/=0d0))return
depth=g-(z(cell)-.5d0*dz(cell))
if(depth<=0d0.or.depth>=dz(cell))return
cg=sum(QInMtxSatDmCp(1:NumDm,cell))/depth
bl=cg*g0;bd=cg*g1
meta(11)=cg;meta(12)=0d0;meta(1)=-6
! Two existing stock normalizations, with no duplicate internal inflow.
do k=1,2
 d=k+1
 if(cm(5,d)<0d0.or.cm(5,d)/=cm(9,d)+cm(12,d).or.any(cm(10:11,d)/=0d0))return
 if(any(cm(14:15,d)/=0d0).or.cm(6,d)<0d0.or.dt<=0d0)return
 if(abs(sum(QInMtxSatDmCp(d,1:n))*dt-cm(12,d))>128d0*epsilon(1d0)*max(abs(cm(12,d)),tiny(1d0)))return
 if(abs(sum(pot(1:n,k))-cm(6,d))>128d0*epsilon(1d0)*max(abs(cm(6,d)),tiny(1d0)))return
 if(cm(2,d)/=min(cm(4,d),cm(1,d)))return
 fr=cm(16,d);meta(2+k)=fr
 if(fr<0d0.or.fr>1d0)return
 rhoslope=0d0
 if(cm(4,d)<cm(1,d))then
  rhoslope=cm(18,d);meta(4+k)=1d0
 end if
 if(cm(4,d)==cm(1,d))meta(6+k)=1d0
 if(fr==0d0.or.fr==1d0)cycle
 if(cm(6,d)<=0d0)return
 dI=0d0
 do i=cell,n
  if(QInMtxSatDmCp(d,i)>0d0)then
   hm=max(0d0,cm(24,d)-z(i))
   if(hm<1d-8)hm=0d0
   delta=h(i)-hm
   if(delta<=0d0)return
   dI(i)=dt*QInMtxSatDmCp(d,i)/delta
  end if
 end do
 dI(upper)=dI(upper)+dt*QInMtxSatDmCp(d,cell)/depth*g0
 dI(cell)=dI(cell)+dt*QInMtxSatDmCp(d,cell)/depth*g1
 vv(1:n,k)=dI(1:n)/cm(6,d)
 if(cm(17,d)/cm(21,d)<=1d-7.or.cm(6,d)<=cm(17,d))return
 do i=1,n
  if(pot(i,k)>0d0)then
   if(i<cell.or.h(i)<=0d0)return
   delta=max(0d0,cm(24,d)-z(i))-h(i)
   if(delta<=0d0)return
   doo=-pot(i,k)/delta;uu(i,k)=-pot(i,k)/cm(21,d);vv(i,k)=vv(i,k)-fr*doo/cm(6,d)
  end if
 end do
 vv(upper,k)=vv(upper,k)-rhoslope*g0/cm(6,d);vv(cell,k)=vv(cell,k)-rhoslope*g1/cm(6,d)
 meta(2)=meta(2)+1d0
end do
meta(1)=1d0;eligible=.true.
! Current local derivatives and primitive geometry for independent column sums.
proof_count=proof_count+1
if(proof_count<=64)then
 if(proof_count==1)open(newunit=proof_unit,file='macro_saturated_mass_base.txt',status='replace')
 proof_meta=[dble(cell),h(upper),h(cell),z(upper),z(cell),depth,cm(16,2),cm(16,3), &
  cm(18,2),cm(18,3),merge(1d0,0d0,cm(4,2)<cm(1,2)),merge(1d0,0d0,cm(4,3)<cm(1,3)), &
  QInMtxSatDmCp(2,cell),QInMtxSatDmCp(3,cell),cm(5,2),cm(5,3),cm(6,2),cm(6,3), &
  cm(2,2),cm(2,3),cm(4,2),cm(4,3),cm(1,2),cm(1,3)]
 write(proof_unit,*)n,t1900,dt,numbit
 write(proof_unit,*)proof_meta
 do d=2,3
  proof_base=0d0
  do i=1,n
   hm=max(0d0,cm(24,d)-z(i))
   if(hm<1d-8)hm=0d0
   delta=hm-h(i)
   if(abs(delta)>1d-14)proof_base(i)=(QOutMtxSatDmCp(d,i)-QInMtxSatDmCp(d,i))/delta
  end do
  write(proof_unit,*)proof_base(1:n)
 end do
end if
end subroutine

subroutine jac37_solve(n,a,b,c,r,x,ierror,handled)
use MOD_arrays,only:macp
use,intrinsic::ieee_arithmetic,only:ieee_is_finite
use variables,only:t1900,dt,numbit
implicit none
integer,intent(in)::n
real(8),intent(in)::a(n),b(n),c(n),r(n)
real(8),intent(out)::x(n)
integer,intent(out)::ierror
logical,intent(out)::handled
real(8)::uu(macp,2),vv(macp,2),meta(16),bl,bd,aa(n),bb(n),zz(n,2),M(2,2),rhs(2),lam(2),det,res(n)
integer::k,i,e,cell
logical,save::opened=.false.
integer,save::tu,systems_unit=0,active_count=0
call jac37_terms(n,uu,vv,bl,bd,meta,handled)
M=0d0;M(1,1)=1d0;M(2,2)=1d0;lam=0d0;det=1d0;res=-1d0
if(handled) then
 cell=int(meta(14))
 aa=a;bb=b;aa(cell)=aa(cell)+bl;bb(cell)=bb(cell)+bd
 call tridag(n,aa,bb,c,r,x,ierror)
 if(ierror/=0) error stop 'JAC37 active base solve failed'
 zz=0d0
 do k=1,2
  if(all(uu(1:n,k)==0d0)) cycle
  call tridag(n,aa,bb,c,uu(1:n,k),zz(:,k),e)
  if(e/=0) error stop 'JAC37 update solve failed'
 end do
 do k=1,2
  do i=1,2
   M(k,i)=M(k,i)+dot_product(vv(1:n,k),zz(:,i))
  end do
  rhs(k)=dot_product(vv(1:n,k),x)
 end do
 det=M(1,1)*M(2,2)-M(1,2)*M(2,1)
 if(.not.ieee_is_finite(det).or.abs(det)<1d-12) error stop 'JAC37 rank2 update singular'
 lam(1)=(rhs(1)*M(2,2)-M(1,2)*rhs(2))/det
 lam(2)=(M(1,1)*rhs(2)-rhs(1)*M(2,1))/det
 x=x-zz(:,1)*lam(1)-zz(:,2)*lam(2)
 res=bb*x-r
 do i=2,n
  res(i)=res(i)+aa(i)*x(i-1)
 end do
 do i=1,n-1
  res(i)=res(i)+c(i)*x(i+1)
 end do
 do k=1,2
  res=res+uu(1:n,k)*dot_product(vv(1:n,k),x)
 end do
 if(any(.not.ieee_is_finite(x)))error stop 'Nonfinite rank2 correction'
end if
if(.not.opened) then
 open(newunit=tu,file='jac37_trace.txt',status='replace');opened=.true.
end if
write(tu,*) t1900,dt,numbit,meta,bl,bd,M(1,1),M(1,2),M(2,1),M(2,2),det,lam, &
 merge(maxval(abs(res)),-1d0,handled)
if(handled)then
 active_count=active_count+1
 if(active_count<=64)then
  if(systems_unit==0)open(newunit=systems_unit,file='macro_rank2_systems.txt',status='replace')
  write(systems_unit,*)n,t1900,dt,numbit
  write(systems_unit,*)aa,bb,c,r,uu(1:n,1),uu(1:n,2),vv(1:n,1),vv(1:n,2),x
 end if
end if
! Buffered diagnostic trace; does not participate in physical state.
end subroutine

