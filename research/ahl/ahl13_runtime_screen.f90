program ahl13_runtime_screen
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: NHEAD=4096, NCYCLE=512, NREP=3
  real(real64), parameter :: LN10=log(10.0_real64)
  real(real64) :: p(6), heads(NHEAD), ta(NREP), tc(NREP), ca=0.0_real64, cc=0.0_real64
  real(real64), allocatable :: x(:),z(:),mz(:),lk(:)
  character(len=512) :: path,mid
  integer :: i,r
  call get_command_argument(1,path);call get_command_argument(2,mid)
  call read_table(trim(path),p,x,z,mz,lk)
  do i=1,NHEAD
    heads(i)=-10.0_real64**(0.0_real64+6.0_real64*real(i-1,real64)/real(NHEAD-1,real64))
  end do
  do r=1,NREP
    call time_analytic(heads,p,ta(r),ca)
    call time_candidate(heads,p,x,z,mz,lk,tc(r),cc)
  end do
  call sort3(ta);call sort3(tc)
  write(*,'(A,1X,A,1X,A,1X,ES18.10,1X,ES24.16)') 'RESULT',trim(mid),'analytical',ta(2)/real(NHEAD*NCYCLE,real64),ca
  write(*,'(A,1X,A,1X,A,1X,ES18.10,1X,ES24.16)') 'RESULT',trim(mid),'dc_exactK',tc(2)/real(NHEAD*NCYCLE,real64),cc
contains
  subroutine read_table(path,p,x,z,mz,lk)
    character(len=*),intent(in)::path
    real(real64),intent(out)::p(6)
    real(real64),allocatable,intent(out)::x(:),z(:),mz(:),lk(:)
    integer::u,ios,n,j
    open(newunit=u,file=path,status='old',action='read',iostat=ios);if(ios/=0)error stop 'open'
    read(u,*,iostat=ios)p;if(ios/=0)error stop 'params'
    read(u,*,iostat=ios)n;if(ios/=0.or.n<2)error stop 'size'
    allocate(x(n),z(n),mz(n),lk(n))
    do j=1,n
      read(u,*,iostat=ios)x(j),z(j),mz(j),lk(j);if(ios/=0)error stop 'row'
    end do
    close(u)
  end subroutine
  pure subroutine analytical(h,p,theta,c,k)
    real(real64),intent(in)::h,p(6)
    real(real64),intent(out)::theta,c,k
    real(real64)::tr,ts,a,n,ks,lam,m,span,ah,t1,se,term
    tr=p(1);ts=p(2);a=p(3);n=p(4);ks=p(5);lam=p(6);m=1-1/n;span=ts-tr
    ah=abs(a*h);theta=tr+span/(1+ah**n)**m
    t1=ah**(n-1);c=n*m*a*(span/(1+t1*ah)**(m+1))*t1
    se=(theta-tr)/span
    if(se>1-1e-6_real64)then;k=ks
    else;term=(1-se**(1/m))**m;k=min(ks*se**lam*(1-term)**2,ks);end if
  end subroutine
  pure subroutine locate(a,v,idx,f)
    real(real64),intent(in)::a(:),v
    integer,intent(out)::idx
    real(real64),intent(out)::f
    integer::lo,hi,mid,n
    n=size(a)
    if(v<=a(1))then;idx=1;f=0;return;end if
    if(v>=a(n))then;idx=n-1;f=1;return;end if
    lo=1;hi=n
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(a(mid)<=v)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;f=(v-a(lo))/(a(lo+1)-a(lo))
  end subroutine
  pure subroutine candidate(h,p,x,z,mz,lk,theta,c,k)
    real(real64),intent(in)::h,p(6),x(:),z(:),mz(:),lk(:)
    real(real64),intent(out)::theta,c,k
    real(real64)::xv,f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,zz,dzdx,se,span
    integer::idx
    xv=log10(-h);call locate(x,xv,idx,f);dx=x(idx+1)-x(idx);t=f
    h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
    zz=h00*z(idx)+h10*dx*mz(idx)+h01*z(idx+1)+h11*dx*mz(idx+1)
    dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
    dzdx=(dh00*z(idx)+dh10*dx*mz(idx)+dh01*z(idx+1)+dh11*dx*mz(idx+1))/dx
    if(zz>=0)then;se=1/(1+exp(-zz));else;se=exp(zz)/(1+exp(zz));end if
    span=p(2)-p(1);theta=p(1)+span*se
    c=(span*se*(1-se)*dzdx)/(h*LN10)
    if(se>1.0_real64-1.0e-6_real64)then
      k=p(5)
    else
      k=p(5)*se**p(6)*(1.0_real64-(1.0_real64-se**(1.0_real64/(1.0_real64-1.0_real64/p(4))))**(1.0_real64-1.0_real64/p(4)))**2
      k=min(k,p(5))
    end if
  end subroutine
  subroutine time_analytic(h,p,e,checksum)
    real(real64),intent(in)::h(:),p(6);real(real64),intent(out)::e;real(real64),intent(inout)::checksum
    real(real64)::a,b,th,c,k;integer::cy,j
    call cpu_time(a)
    do cy=1,NCYCLE;do j=1,size(h);call analytical(h(j),p,th,c,k);checksum=checksum+th+1e-6_real64*c+1e-9_real64*k;end do;end do
    call cpu_time(b);e=b-a
  end subroutine
  subroutine time_candidate(h,p,x,z,mz,lk,e,checksum)
    real(real64),intent(in)::h(:),p(6),x(:),z(:),mz(:),lk(:);real(real64),intent(out)::e;real(real64),intent(inout)::checksum
    real(real64)::a,b,th,c,k;integer::cy,j
    call cpu_time(a)
    do cy=1,NCYCLE;do j=1,size(h);call candidate(h(j),p,x,z,mz,lk,th,c,k);checksum=checksum+th+1e-6_real64*c+1e-9_real64*k;end do;end do
    call cpu_time(b);e=b-a
  end subroutine
  subroutine sort3(v)
    real(real64),intent(inout)::v(3);real(real64)::q
    if(v(1)>v(2))then;q=v(1);v(1)=v(2);v(2)=q;end if
    if(v(2)>v(3))then;q=v(2);v(2)=v(3);v(3)=q;end if
    if(v(1)>v(2))then;q=v(1);v(1)=v(2);v(2)=q;end if
  end subroutine
end program ahl13_runtime_screen
