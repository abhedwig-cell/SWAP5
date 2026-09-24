program ahl04d_runtime_screen
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: NHEAD=4096, NCYCLE=512, NREP=3
  real(real64), parameter :: tr=0.032_real64, ts=0.423_real64, alpha=0.0135_real64
  real(real64), parameter :: nvg=1.455_real64, ksat=4.75_real64, lambda=0.365_real64
  real(real64), parameter :: mvg=1.0_real64-1.0_real64/nvg
  real(real64) :: heads(NHEAD), ta(NREP), tl(NREP), tsplit(NREP), ca=0,cl=0,cs=0
  real(real64), allocatable :: x(:),z(:),lc(:),lk(:)
  character(len=512)::path
  integer::i,r
  call get_command_argument(1,path)
  call read_table(trim(path),x,z,lc,lk)
  do i=1,NHEAD
    heads(i)=-10.0_real64**(8.0_real64*real(i-1,real64)/real(NHEAD-1,real64))
  end do
  do r=1,NREP
    call time_analytic(heads,ta(r),ca)
    call time_lookup(heads,x,z,lc,lk,tl(r),cl)
    call time_split(heads,x,lc,lk,tsplit(r),cs)
  end do
  call sort3(ta);call sort3(tl);call sort3(tsplit)
  write(*,'(A,1X,A,1X,ES18.10,1X,ES24.16)') 'AHL04D','analytical',ta(2)/real(NHEAD*NCYCLE,real64),ca
  write(*,'(A,1X,A,1X,ES18.10,1X,ES24.16)') 'AHL04D','lookup_all',tl(2)/real(NHEAD*NCYCLE,real64),cl
  write(*,'(A,1X,A,1X,ES18.10,1X,ES24.16)') 'AHL04D','exact_theta_lookup_C_K',tsplit(2)/real(NHEAD*NCYCLE,real64),cs
contains
  subroutine read_table(p,x,z,lc,lk)
    character(len=*),intent(in)::p
    real(real64),allocatable,intent(out)::x(:),z(:),lc(:),lk(:)
    integer::u,ios,nn,j
    open(newunit=u,file=p,status='old',action='read',iostat=ios);if(ios/=0)error stop 'open'
    read(u,*,iostat=ios)nn;if(ios/=0.or.nn<2)error stop 'n'
    allocate(x(nn),z(nn),lc(nn),lk(nn))
    do j=1,nn
      read(u,*,iostat=ios)x(j),z(j),lc(j),lk(j);if(ios/=0)error stop 'row'
    end do
    close(u)
  end subroutine
  pure subroutine theta_only(h,theta)
    real(real64),intent(in)::h
    real(real64),intent(out)::theta
    real(real64)::ah
    ah=abs(alpha*h)
    theta=tr+(ts-tr)/(1.0_real64+ah**nvg)**mvg
  end subroutine
  pure subroutine analytical(h,theta,cap,k)
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,cap,k
    real(real64)::ah,t1,rel,term
    ah=abs(alpha*h)
    theta=tr+(ts-tr)/(1.0_real64+ah**nvg)**mvg
    t1=ah**(nvg-1.0_real64)
    cap=nvg*mvg*alpha*((ts-tr)/(1.0_real64+t1*ah)**(mvg+1.0_real64))*t1
    rel=(theta-tr)/(ts-tr)
    if(rel>1.0_real64-1.0e-6_real64)then
      k=ksat
    else
      term=(1.0_real64-rel**(1.0_real64/mvg))**mvg
      k=min(ksat*rel**lambda*(1.0_real64-term)**2,ksat)
    end if
  end subroutine
  pure subroutine locate(x,v,idx,f)
    real(real64),intent(in)::x(:),v
    integer,intent(out)::idx
    real(real64),intent(out)::f
    integer::lo,hi,mid,nn
    nn=size(x)
    if(v<=x(1))then;idx=1;f=0;return
    else if(v>=x(nn))then;idx=nn-1;f=1;return
    end if
    lo=1;hi=nn
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(x(mid)<=v)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;f=(v-x(lo))/(x(lo+1)-x(lo))
  end subroutine
  subroutine time_analytic(h,elapsed,checksum)
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::elapsed
    real(real64),intent(inout)::checksum
    real(real64)::t0,t1,th,c,k
    integer::cy,j
    call cpu_time(t0)
    do cy=1,NCYCLE;do j=1,size(h)
      call analytical(h(j),th,c,k);checksum=checksum+th+1e-6_real64*c+1e-9_real64*k
    end do;end do
    call cpu_time(t1);elapsed=t1-t0
  end subroutine
  subroutine time_lookup(h,x,z,lc,lk,elapsed,checksum)
    real(real64),intent(in)::h(:),x(:),z(:),lc(:),lk(:)
    real(real64),intent(out)::elapsed
    real(real64),intent(inout)::checksum
    real(real64)::t0,t1,v,f,zz,se,th,c,k
    integer::cy,j,idx
    call cpu_time(t0)
    do cy=1,NCYCLE;do j=1,size(h)
      v=log10(-h(j));call locate(x,v,idx,f)
      zz=z(idx)+f*(z(idx+1)-z(idx))
      if(zz>=0)then;se=1/(1+exp(-zz));else;se=exp(zz)/(1+exp(zz));end if
      th=tr+(ts-tr)*se
      c=exp(lc(idx)+f*(lc(idx+1)-lc(idx)));k=exp(lk(idx)+f*(lk(idx+1)-lk(idx)))
      checksum=checksum+th+1e-6_real64*c+1e-9_real64*k
    end do;end do
    call cpu_time(t1);elapsed=t1-t0
  end subroutine
  subroutine time_split(h,x,lc,lk,elapsed,checksum)
    real(real64),intent(in)::h(:),x(:),lc(:),lk(:)
    real(real64),intent(out)::elapsed
    real(real64),intent(inout)::checksum
    real(real64)::t0,t1,v,f,th,c,k
    integer::cy,j,idx
    call cpu_time(t0)
    do cy=1,NCYCLE;do j=1,size(h)
      call theta_only(h(j),th)
      v=log10(-h(j));call locate(x,v,idx,f)
      c=exp(lc(idx)+f*(lc(idx+1)-lc(idx)));k=exp(lk(idx)+f*(lk(idx+1)-lk(idx)))
      checksum=checksum+th+1e-6_real64*c+1e-9_real64*k
    end do;end do
    call cpu_time(t1);elapsed=t1-t0
  end subroutine
  subroutine sort3(v)
    real(real64),intent(inout)::v(3);real(real64)::t
    if(v(1)>v(2))then;t=v(1);v(1)=v(2);v(2)=t;end if
    if(v(2)>v(3))then;t=v(2);v(2)=v(3);v(3)=t;end if
    if(v(1)>v(2))then;t=v(1);v(1)=v(2);v(2)=t;end if
  end subroutine
end program ahl04d_runtime_screen
