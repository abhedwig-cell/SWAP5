subroutine jac37_terms(n,uu,vv,bl,bd,meta,eligible)
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,QInMtxSatDmCp,QInIntSatDmCp,QOutMtxSatDmCp,QOutMtxUnsDmCp,FrReduQ
use MOD_swap_mp,only:swmbf,IcTopMp,IDecMpRat,GwlFlCpZo
use variables,only:h,theta,thetas,pegwl
implicit none
integer,intent(in)::n
real(8),intent(out)::uu(macp,2),vv(macp,2),bl,bd,meta(16)
logical,intent(out)::eligible
real(8)::cm(24,madm),pot(macp,2),valid,den,g,g0,g1,depth,hm,delta,doo,rhoslope,cg,ci,fr
integer::d,k,i
uu=0d0;vv=0d0;bl=0d0;bd=0d0;meta=0d0;eligible=.false.
meta(1)=-1
if(n/=numnod.or.n<58.or.NumDm/=5.or.swmbf/=1.or.IcTopMp/=1.or.IDecMpRat/=0.or.FrReduQ/=1d0) return
call macro_rank2_data(cm,pot,valid)
meta(15)=valid;meta(1)=-2
if(valid/=1d0) return
meta(1)=-3
if(ICpTpSatZon/=51.or.ICpTpPerZon/=51.or.ICpBtPerZon/=51) return
if(h(50)>=0d0.or.h(51)<=0d0.or.h(51)>=1d0) return
if(abs(pegwl-GwlFlCpZo)>1d-9) return
den=h(51)-h(50)
g=z(51)+h(51)/den*(z(50)-z(51))
if(abs(g-GwlFlCpZo)>1d-9) return
g0=(z(50)-z(51))*h(51)/den**2
g1=-(z(50)-z(51))*h(50)/den**2
meta(13)=g;meta(16)=theta(50)-thetas(50)
meta(1)=-4
if(any(cm(8,1:5)/=1d0).or.any(cm(22,1:5)/=0d0)) return
if(cm(16,1)/=1d0.or.any(cm(16,4:5)/=1d0)) return
meta(1)=-5
if(any(QInIntSatDmCp(1,1:50)/=0d0).or.any(QInIntSatDmCp(1,52:n)/=0d0)) return
if(QInIntSatDmCp(1,51)<=0d0.or.QInMtxSatDmCp(1,51)<=0d0) return
if(QOutMtxSatDmCp(1,51)/=0d0.or.QOutMtxUnsDmCp(1,51)/=0d0) return
hm=cm(24,1)-z(51)
if(hm>=1d-8) return
hm=0d0
depth=g-(z(51)-.5d0*dz(51))
if(depth<=0d0.or.depth>=dz(51)) return
cg=(QInMtxSatDmCp(1,51)+QInIntSatDmCp(1,51))/depth
ci=QInIntSatDmCp(1,51)/(h(51)-hm)
bl=cg*g0;bd=cg*g1+ci
meta(11)=cg;meta(12)=ci
meta(1)=-6
! New and old correction regions do not overlap: positive top-only inflow here.
do k=1,2
 d=k+1
 if(cm(5,d)<=0d0.or.cm(5,d)/=cm(9,d).or.any(cm(10:12,d)/=0d0)) return
 if(any(cm(14:15,d)/=0d0).or.cm(6,d)<=0d0) return
 if(cm(2,d)/=min(cm(4,d),cm(1,d))) return
 fr=cm(16,d);meta(2+k)=fr
 if(fr<0d0.or.fr>1d0) return
 if(cm(4,d)<cm(1,d)) then
  rhoslope=cm(18,d);meta(4+k)=1d0
 else
  rhoslope=0d0;meta(4+k)=0d0
 end if
 if(cm(4,d)==cm(1,d)) meta(6+k)=1d0
 ! Unlimited and fully cut-off flows retain their native piecewise-zero factor derivative.
 if(fr==0d0.or.fr==1d0) cycle
 if(cm(17,d)/cm(21,d)<=1d-7.or.cm(6,d)<=cm(17,d)) return
 do i=1,n
  if(pot(i,k)>0d0) then
   if(i<51.or.h(i)<=0d0) return
   delta=max(0d0,cm(24,d)-z(i))-h(i)
   if(delta<=0d0) return
   doo=-pot(i,k)/delta
   uu(i,k)=-pot(i,k)/cm(21,d)
   vv(i,k)=-fr*doo/cm(6,d)
  end if
 end do
 vv(50,k)=vv(50,k)-rhoslope*g0/cm(6,d)
 vv(51,k)=vv(51,k)-rhoslope*g1/cm(6,d)
 meta(2)=meta(2)+1d0
end do
meta(1)=1d0;eligible=.true.
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
integer::k,i,e
logical,save::opened=.false.
integer,save::tu,systems_unit=0,active_count=0
call jac37_terms(n,uu,vv,bl,bd,meta,handled)
M=0d0;M(1,1)=1d0;M(2,2)=1d0;lam=0d0;det=1d0;res=-1d0
if(handled) then
 aa=a;bb=b;aa(51)=aa(51)+bl;bb(51)=bb(51)+bd
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
if(handled)write(tu,*) t1900,dt,numbit,meta,bl,bd,M(1,1),M(1,2),M(2,1),M(2,2),det,lam, &
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

