program test_fahl45_direct_demand_screen
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  integer, parameter :: node_count=60, nvalid=200000, reps=300000
  integer, parameter :: nsets=4
  integer, parameter :: intervals(nsets)=[32,64,128,256]
  character(len=3), parameter :: mats(2)=[character(len=3)::'B01','O05']
  real(real64), allocatable :: table(:,:,:)
  real(real64) :: tr,ts,alpha,nvg,mvg,h(node_count),theta(node_count),theta2(node_count)
  real(real64) :: maxerr,normerr,span,seconds,checksum
  integer(int64)::c0,c1,rate
  integer::imat,is,k,r
  call system_clock(count_rate=rate)
  do imat=1,2
    call material(trim(mats(imat)),tr,ts,alpha,nvg)
    mvg=1.0_real64-1.0_real64/nvg
    span=ts-tr
    do is=1,nsets
      allocate(table(0:intervals(is),0:5,1))
      call build(table(:,:,1),intervals(is),tr,ts,alpha,nvg,mvg)
      call validate(table(:,:,1),intervals(is),tr,ts,alpha,nvg,mvg,maxerr)
      normerr=maxerr/span
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
      write(*,'(*(g0))') 'FAHL45_TIMING|M=',trim(mats(imat)),'|I=',intervals(is),'|MODE=ANALYTICAL|NS=', &
           1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum
      checksum=0.0_real64
      call system_clock(c0)
      do r=1,reps
        do k=1,node_count
          theta2(k)=theta_direct(h(k),table(:,:,1),intervals(is))
        end do
        checksum=checksum+theta2(1)+theta2(node_count)
      end do
      call system_clock(c1)
      seconds=real(c1-c0,real64)/real(rate,real64)
      write(*,'(*(g0))') 'FAHL45_TIMING|M=',trim(mats(imat)),'|I=',intervals(is),'|MODE=DIRECT|NS=', &
           1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum
      write(*,'(*(g0))') 'FAHL45_ERROR|M=',trim(mats(imat)),'|I=',intervals(is),'|MAX_ABS=',maxerr,'|NORM=',normerr
      deallocate(table)
    end do
  end do
  write(*,'(A)') 'FAHL45_DIRECT_DEMAND_SCREEN=PASS'
contains
  subroutine material(id,tr,ts,a,n)
    character(len=*),intent(in)::id
    real(real64),intent(out)::tr,ts,a,n
    select case(id)
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;a=0.021659_real64;n=1.734737_real64
    case('O05')
      tr=0.01_real64;ts=0.336701_real64;a=0.030304_real64;n=2.887502_real64
    case default
      error stop 'unknown material'
    end select
  end subroutine
  pure real(real64) function theta_analytic(head,tr,ts,a,n,m) result(theta)
    real(real64),intent(in)::head,tr,ts,a,n,m
    real(real64)::x
    if(head>=0.0_real64)then
      theta=ts
    else
      x=abs(a*head)**n
      theta=tr+(ts-tr)/(1.0_real64+x)**m
    end if
  end function
  subroutine build(t,nint,tr,ts,a,n,m)
    integer,intent(in)::nint
    real(real64),intent(out)::t(0:nint,0:5)
    real(real64),intent(in)::tr,ts,a,n,m
    integer::d,j
    real(real64)::lo,hi,x
    do d=0,5
      lo=10.0_real64**d;hi=10.0_real64**(d+1)
      do j=0,nint
        x=lo+(hi-lo)*real(j,real64)/real(nint,real64)
        t(j,d)=theta_analytic(-x,tr,ts,a,n,m)
      end do
    end do
  end subroutine
  pure real(real64) function theta_direct(head,t,nint) result(theta)
    integer,intent(in)::nint
    real(real64),intent(in)::head,t(0:nint,0:5)
    real(real64)::x,lo,hi,u
    integer::d,j
    if(head>=-1.0_real64)then
      theta=t(0,0);return
    end if
    x=-head
    if(x>=1.0e6_real64)then
      theta=t(nint,5);return
    end if
    if(x<10.0_real64)then
      d=0;lo=1.0_real64;hi=10.0_real64
    else if(x<100.0_real64)then
      d=1;lo=10.0_real64;hi=100.0_real64
    else if(x<1000.0_real64)then
      d=2;lo=100.0_real64;hi=1000.0_real64
    else if(x<10000.0_real64)then
      d=3;lo=1000.0_real64;hi=10000.0_real64
    else if(x<100000.0_real64)then
      d=4;lo=10000.0_real64;hi=100000.0_real64
    else
      d=5;lo=100000.0_real64;hi=1000000.0_real64
    end if
    u=(x-lo)*real(nint,real64)/(hi-lo)
    j=min(nint-1,max(0,int(u)))
    u=u-real(j,real64)
    theta=t(j,d)+u*(t(j+1,d)-t(j,d))
  end function
  subroutine validate(t,nint,tr,ts,a,n,m,maxerr)
    integer,intent(in)::nint
    real(real64),intent(in)::t(0:nint,0:5),tr,ts,a,n,m
    real(real64),intent(out)::maxerr
    integer::q
    real(real64)::lx,h,ref,cand
    maxerr=0.0_real64
    do q=0,nvalid-1
      lx=6.0_real64*real(q,real64)/real(nvalid-1,real64)
      h=-10.0_real64**lx
      ref=theta_analytic(h,tr,ts,a,n,m)
      cand=theta_direct(h,t,nint)
      maxerr=max(maxerr,abs(cand-ref))
    end do
  end subroutine
end program
