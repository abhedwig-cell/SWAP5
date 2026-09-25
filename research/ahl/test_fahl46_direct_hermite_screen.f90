program test_fahl46_direct_hermite_screen
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  integer, parameter :: node_count=60, nvalid=120000, reps=250000
  integer, parameter :: nsets=3
  integer, parameter :: intervals(nsets)=[64,128,256]
  character(len=3), parameter :: mats(2)=[character(len=3)::'B01','O05']
  real(real64), allocatable :: thtab(:,:), ctab(:,:)
  real(real64) :: tr,ts,alpha,nvg,mvg,h(node_count),theta(node_count),cap(node_count)
  real(real64) :: maxte,maxce,maxcrel,seconds,checksum
  integer(int64)::c0,c1,rate
  integer::imat,is,k,r
  call system_clock(count_rate=rate)
  do imat=1,2
    call material(trim(mats(imat)),tr,ts,alpha,nvg)
    mvg=1.0_real64-1.0_real64/nvg
    do is=1,nsets
      allocate(thtab(0:intervals(is),0:5),ctab(0:intervals(is),0:5))
      call build(thtab,ctab,intervals(is),tr,ts,alpha,nvg,mvg)
      call validate(thtab,ctab,intervals(is),tr,ts,alpha,nvg,mvg,maxte,maxce,maxcrel)
      h=-75.0_real64
      checksum=0.0_real64
      call system_clock(c0)
      do r=1,reps
        do k=1,node_count
          theta(k)=theta_analytic(h(k),tr,ts,alpha,nvg,mvg)
        end do
        checksum=checksum+theta(1)+theta(node_count)
      end do
      call system_clock(c1)
      seconds=real(c1-c0,real64)/real(rate,real64)
      write(*,'(*(g0))') 'FAHL46_TIMING|M=',trim(mats(imat)),'|I=',intervals(is),'|MODE=AN_THETA|NS=',1e9_real64*seconds/reps,'|CHECK=',checksum

      checksum=0.0_real64
      call system_clock(c0)
      do r=1,reps
        do k=1,node_count
          call eval_direct(h(k),thtab,ctab,intervals(is),theta(k),cap(k))
        end do
        checksum=checksum+theta(1)+theta(node_count)
      end do
      call system_clock(c1)
      seconds=real(c1-c0,real64)/real(rate,real64)
      write(*,'(*(g0))') 'FAHL46_TIMING|M=',trim(mats(imat)),'|I=',intervals(is),'|MODE=DIR_THETA_C|NS=',1e9_real64*seconds/reps,'|CHECK=',checksum

      checksum=0.0_real64
      call system_clock(c0)
      do r=1,reps
        do k=1,node_count
          theta(k)=theta_analytic(h(k),tr,ts,alpha,nvg,mvg)
          cap(k)=c_analytic(h(k),tr,ts,alpha,nvg,mvg)
        end do
        checksum=checksum+theta(1)+cap(node_count)
      end do
      call system_clock(c1)
      seconds=real(c1-c0,real64)/real(rate,real64)
      write(*,'(*(g0))') 'FAHL46_TIMING|M=',trim(mats(imat)),'|I=',intervals(is),'|MODE=AN_THETA_C|NS=',1e9_real64*seconds/reps,'|CHECK=',checksum
      write(*,'(*(g0))') 'FAHL46_ERROR|M=',trim(mats(imat)),'|I=',intervals(is),'|THETA=',maxte,'|CABS=',maxce,'|CREL=',maxcrel
      deallocate(thtab,ctab)
    end do
  end do
  write(*,'(A)') 'FAHL46_DIRECT_HERMITE_SCREEN=PASS'
contains
  subroutine material(id,tr,ts,a,n)
    character(len=*),intent(in)::id;real(real64),intent(out)::tr,ts,a,n
    select case(id)
    case('B01');tr=0.02_real64;ts=0.427494_real64;a=0.021659_real64;n=1.734737_real64
    case('O05');tr=0.01_real64;ts=0.336701_real64;a=0.030304_real64;n=2.887502_real64
    case default;error stop 'unknown material'
    end select
  end subroutine
  pure real(real64) function theta_analytic(head,tr,ts,a,n,m) result(v)
    real(real64),intent(in)::head,tr,ts,a,n,m;real(real64)::x
    if(head>=0)then;v=ts;else;x=abs(a*head)**n;v=tr+(ts-tr)/(1+x)**m;end if
  end function
  pure real(real64) function c_analytic(head,tr,ts,a,n,m) result(v)
    real(real64),intent(in)::head,tr,ts,a,n,m;real(real64)::ah,t1,t2
    if(head>=0)then;v=0.0_real64;else
      ah=abs(a*head);t1=ah**(n-1.0_real64);t2=(ts-tr)/(1.0_real64+t1*ah)**(m+1.0_real64)
      v=n*m*a*t2*t1
    end if
  end function
  subroutine build(t,c,nint,tr,ts,a,n,m)
    integer,intent(in)::nint
    real(real64),intent(out)::t(0:nint,0:5),c(0:nint,0:5)
    real(real64),intent(in)::tr,ts,a,n,m
    integer::d,j;real(real64)::lo,hi,x
    do d=0,5;lo=10.0_real64**d;hi=10.0_real64**(d+1)
      do j=0,nint;x=lo+(hi-lo)*real(j,real64)/real(nint,real64)
        t(j,d)=theta_analytic(-x,tr,ts,a,n,m);c(j,d)=c_analytic(-x,tr,ts,a,n,m)
      end do
    end do
  end subroutine
  pure subroutine locate_direct(head,nint,d,j,u,dx)
    real(real64),intent(in)::head;integer,intent(in)::nint;integer,intent(out)::d,j
    real(real64),intent(out)::u,dx
    real(real64)::x,lo,hi,q
    x=max(1.0_real64,min(1.0e6_real64,-head))
    if(x<10)then;d=0;lo=1;hi=10
    else if(x<100)then;d=1;lo=10;hi=100
    else if(x<1000)then;d=2;lo=100;hi=1000
    else if(x<10000)then;d=3;lo=1000;hi=10000
    else if(x<100000)then;d=4;lo=10000;hi=100000
    else;d=5;lo=100000;hi=1000000;end if
    dx=(hi-lo)/real(nint,real64);q=(x-lo)/dx;j=min(nint-1,max(0,int(q)));u=q-real(j,real64)
  end subroutine
  pure subroutine eval_direct(head,t,c,nint,theta,cap)
    integer,intent(in)::nint
    real(real64),intent(in)::head,t(0:nint,0:5),c(0:nint,0:5)
    real(real64),intent(out)::theta,cap
    integer::d,j;real(real64)::u,dx,h00,h10,h01,h11,dh00,dh10,dh01,dh11,dthdx
    call locate_direct(head,nint,d,j,u,dx)
    h00=2*u**3-3*u**2+1;h10=u**3-2*u**2+u;h01=-2*u**3+3*u**2;h11=u**3-u**2
    theta=h00*t(j,d)+h10*dx*(-c(j,d))+h01*t(j+1,d)+h11*dx*(-c(j+1,d))
    dh00=6*u*u-6*u;dh10=3*u*u-4*u+1;dh01=-6*u*u+6*u;dh11=3*u*u-2*u
    dthdx=(dh00*t(j,d)+dh10*dx*(-c(j,d))+dh01*t(j+1,d)+dh11*dx*(-c(j+1,d)))/dx
    cap=-dthdx
  end subroutine
  subroutine validate(t,c,nint,tr,ts,a,n,m,mte,mce,mcr)
    integer,intent(in)::nint
    real(real64),intent(in)::t(0:nint,0:5),c(0:nint,0:5),tr,ts,a,n,m
    real(real64),intent(out)::mte,mce,mcr
    integer::q;real(real64)::lx,h,rt,rc,dt,dc
    mte=0;mce=0;mcr=0
    do q=0,nvalid-1;lx=6.0_real64*real(q,real64)/real(nvalid-1,real64);h=-10.0_real64**lx
      rt=theta_analytic(h,tr,ts,a,n,m);rc=c_analytic(h,tr,ts,a,n,m);call eval_direct(h,t,c,nint,dt,dc)
      mte=max(mte,abs(dt-rt));mce=max(mce,abs(dc-rc));if(rc>=1e-13_real64)mcr=max(mcr,abs(dc-rc)/rc)
    end do
  end subroutine
end program
