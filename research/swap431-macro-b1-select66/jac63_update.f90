! COMBINED62 conditional D3 correction; no residual/physics changes.
subroutine jac63_terms(n,uu,vv,meta,eligible)
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz,layer
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,ICpBtDm,ICpTpWaSrDm, &
 QInMtxSatDmCp,QInIntSatDmCp,QOutMtxUnsDmCp,FrReduQ,CDarcy,TimAbsCumDmCp,SorpMax,SorpAlfa, &
 AwlCorFac,PpDmCp,DiPoCp,FrMpWalWet,swabs,SwDarcy
use MOD_swap_mp,only:swmbf,IcTopMp,IDecMpRat,GwlFlCpZo
use MOD_MvG,only:moiscap
use variables,only:h,theta,thetas,thetar,t1900,dt
use DIAG19,only:apply37,macro_seq
implicit none
integer,intent(in)::n
real(8),intent(out)::uu(macp,2),vv(macp,2),meta(24)
logical,intent(out)::eligible
real(8)::cm(24,madm),ps(macp),pu(macp),valid,f,O,I,L,V,W,gval,zm,den,g0,g1,overlap,span
real(8)::dO(macp),dL(macp),du0,du1,raw,B,Bprime,C50,deficit,power,rho
integer::j,lay
uu=0d0;vv=0d0;meta=0d0;eligible=.false.;meta(1)=-1
if(.not.apply37.or.n/=112.or.n/=numnod.or.NumDm/=5.or.swmbf/=1.or.IcTopMp/=1.or.IDecMpRat/=0.or.FrReduQ/=1d0) return
if(t1900/=35797.290431125148d0.or.dt<=0d0) return
call jac63_get(cm,ps,pu,valid);meta(2)=valid;meta(1)=-2
if(valid/=1d0) return
meta(21)=t1900;meta(22)=dt;meta(23)=dble(macro_seq)
meta(1)=-3
if(ICpTpSatZon/=50.or.ICpTpPerZon/=50.or.ICpBtPerZon/=-1.or.ICpBtDm(3)/=57.or.ICpTpWaSrDm(3)/=50) return
if(h(50)>=0d0.or.any(h(51:57)<=0d0).or.any(theta(51:57)/=thetas(51:57))) return
if(theta(50)<thetas(50)-1d-4) return
meta(24)=thetas(50)-theta(50)
meta(1)=-4
if(swabs/=1.or.SwDarcy/=1.or.TimAbsCumDmCp(3,50)/=0d0) return
if(any(QInMtxSatDmCp(3,1:n)/=0d0).or.any(QInIntSatDmCp(3,1:n)/=0d0)) return
if(cm(8,3)/=1d0.or.cm(22,3)/=0d0.or.cm(5,3)<=0d0.or.cm(5,3)/=cm(9,3).or.any(cm(10:12,3)/=0d0)) return
meta(1)=-5
if(any(ps(1:50)/=0d0).or.any(ps(58:n)/=0d0).or.any(ps(51:57)<=0d0)) return
if(any(pu(1:49)/=0d0).or.any(pu(51:n)/=0d0).or.pu(50)<0d0) return
! Current actual local unsaturated D3 derivative is absent under its original gate.
if(any(QOutMtxUnsDmCp(3,1:n)>1d-7)) return
f=cm(16,3);O=cm(6,3);I=cm(5,3);L=cm(2,3);V=cm(4,3);W=cm(1,3)
meta(4:9)=[f,I,O,L,V,W];meta(1)=-6
if(f<=0d0.or.f>=1d0.or.O<=0d0.or.cm(17,3)/dt<=1d-7.or.O<=cm(17,3)) return
if(L/=min(V,W).or.V==W.or.V>=cm(3,3)) return
meta(1)=-7
gval=GwlFlCpZo;zm=cm(24,3);meta(10)=gval;meta(11)=zm
if(gval<=z(50)-.5d0*dz(50).or.gval>=z(50)+.5d0*dz(50)) return
if(zm<=z(50)-.5d0*dz(50).or.zm>=z(50)+.5d0*dz(50).or.gval==zm) return
if((V<W).neqv.(gval<zm)) return
if(any(zm-z(51:57)-h(51:57)<=1d-8)) return
lay=layer(50);deficit=thetas(50)-theta(50);power=SorpAlfa(lay);meta(1)=-8
if(deficit<=1d-8.or.thetas(50)<=thetar(50).or.DiPoCp(50)<=0d0.or.power<=0d0) return
C50=moiscap(50,h(50))
raw=4d0*AwlCorFac(50)*PpDmCp(3,50)*dz(50)/DiPoCp(50)*FrMpWalWet(3,50) &
 *SorpMax(lay)*(deficit/(thetas(50)-thetar(50)))**power*sqrt(dt)
meta(12)=raw
if(raw<=0d0.or.raw>=1d3*dt*dz(50)) return
span=zm-(z(50)-.5d0*dz(50));overlap=max(0d0,zm-gval)
meta(13)=overlap;meta(15)=overlap/span
if(overlap>=span) return
if(overlap==0d0.and.pu(50)/=0d0) return
if(overlap>0d0.and.pu(50)<=0d0) return
den=h(51)-h(50);g0=(z(50)-z(51))*h(51)/den**2;g1=-(z(50)-z(51))*h(50)/den**2
B=raw/span;Bprime=-B*power*C50/deficit;meta(14)=Bprime
du0=0d0;du1=0d0
if(overlap>0d0) then
 du0=Bprime*overlap-B*g0
 du1=-B*g1
end if
dO=0d0;dL=0d0
do j=51,57
 dO(j)=-dt*CDarcy(3,j)
end do
dO(50)=dO(50)+du0;dO(51)=dO(51)+du1
meta(3)=1d0
if(V<W) then
 rho=cm(18,3);dL(50)=rho*g0;dL(51)=rho*g1;meta(3)=2d0
end if
uu(1:n,1)=-(ps(1:n)+pu(1:n))/dt
vv(1:n,1)=-(dL(1:n)+f*dO(1:n))/O
if(overlap>0d0) then
 uu(50,2)=1d0
 vv(50,2)=-f*du0/dt;vv(51,2)=-f*du1/dt
end if
meta(16:20)=[vv(50,2),vv(51,2),vv(50,1),vv(51,1),vv(52,1)]
meta(1)=1d0;eligible=.true.
end subroutine

subroutine jac63_solve(n,a,b,c,r,x,ierror,handled)
use MOD_arrays,only:macp
use DIAG19,only:attempts,iter_index,active_in_attempt,active_total,detail33
implicit none
integer,intent(in)::n
real(8),intent(in)::a(n),b(n),c(n),r(n)
real(8),intent(out)::x(n)
integer,intent(out)::ierror
logical,intent(out)::handled
real(8)::uu(macp,2),vv(macp,2),meta(24),zz(n,2),M(2,2),rhs(2),lam(2),det,res(n)
integer::k,j,e,u,su
logical,save::opened=.false.
integer,save::tu,sysu
call jac63_terms(n,uu,vv,meta,handled)
ierror=0;M=0d0;M(1,1)=1d0;M(2,2)=1d0;det=1d0;lam=0d0;res=-1d0
if(handled) then
 call tridag(n,a,b,c,r,x,ierror)
 if(ierror/=0) error stop 'JAC63 active base solve failed'
 zz=0d0
 do k=1,2
  if(all(uu(1:n,k)==0d0)) cycle
  call tridag(n,a,b,c,uu(1:n,k),zz(:,k),e)
  if(e/=0) error stop 'JAC63 update solve failed'
 end do
 do k=1,2
  do j=1,2
   M(k,j)=M(k,j)+dot_product(vv(1:n,k),zz(:,j))
  end do
  rhs(k)=dot_product(vv(1:n,k),x)
 end do
 det=M(1,1)*M(2,2)-M(1,2)*M(2,1)
 ! Same active rank2 singularity rule as the inherited JAC37 solver.
 if(abs(det)<1d-12) error stop 'JAC63 rank2 update singular'
 lam(1)=(rhs(1)*M(2,2)-M(1,2)*rhs(2))/det
 lam(2)=(M(1,1)*rhs(2)-M(2,1)*rhs(1))/det
 x=x-zz(:,1)*lam(1)-zz(:,2)*lam(2)
 res=b*x-r
 do j=2,n
  res(j)=res(j)+a(j)*x(j-1)
 end do
 do j=1,n-1
  res(j)=res(j)+c(j)*x(j+1)
 end do
 do k=1,2
  res=res+uu(1:n,k)*dot_product(vv(1:n,k),x)
 end do
 active_in_attempt=active_in_attempt+1;active_total=active_total+1
end if
if(detail33) then
 if(.not.opened) then
  open(newunit=tu,file='jac63_trace.txt',status='replace')
  open(newunit=sysu,file='jac63_systems.txt',status='replace');opened=.true.
 end if
 write(tu,*) attempts,iter_index,meta,merge(1,0,handled),det,merge(maxval(abs(res)),-1d0,handled)
 if(handled) then
  write(sysu,*) attempts,iter_index,n,meta(3),meta(21:23)
  write(sysu,*) a
  write(sysu,*) b
  write(sysu,*) c
  write(sysu,*) r
  write(sysu,*) x
  write(sysu,*) uu(1:n,1)
  write(sysu,*) vv(1:n,1)
  write(sysu,*) uu(1:n,2)
  write(sysu,*) vv(1:n,2)
 end if
 flush(tu);flush(sysu)
end if
end subroutine
