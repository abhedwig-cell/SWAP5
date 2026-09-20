program test_lare_bc2_c4t_lare_compiled
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic
  implicit none
  integer, parameter :: MAXN=12, NHIST=4, NSTEPS=64, NBINS=200, IBASE=100, J0=101, J1=199
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64, ALPHA=0.021659_real64
  real(real64), parameter :: NN=1.734737_real64, MM=1.0_real64-1.0_real64/NN
  real(real64), parameter :: KS=31.225016_real64, ELL=0.98087_real64
  real(real64), parameter :: DEPTH=160.0_real64, OBS_DT=0.001_real64, DT=0.0001_real64
  integer, parameter :: SUBSTEPS=10, MAXCOR=50
  real(real64), parameter :: COR_TOL=1.0e-13_real64, LEDGER_GATE=1.0e-10_real64
  real(real64), parameter :: DTH=(TS-TR)/real(NBINS,real64)
  real(real64), parameter :: THETA_I=TR+real(IBASE,real64)*DTH

  character(len=32) :: route,mode,arg
  integer :: n,repeats,rep
  real(real64) :: dz(MAXN),checksum,total_checksum,t0,t1

  route='';mode='validate';arg=''
  call get_command_argument(1,route)
  call get_command_argument(2,mode)
  call setup_route(trim(route),n,dz)
  if(len_trim(mode)==0)mode='validate'

  if(trim(mode)=='bench')then
    call get_command_argument(3,arg);read(arg,*)repeats
    call require(repeats>=1,'positive repeats')
    total_checksum=0.0_real64
    call cpu_time(t0)
    do rep=1,repeats
      call run_all(n,dz,.false.,checksum)
      total_checksum=total_checksum+checksum
    end do
    call cpu_time(t1)
    write(*,'(*(g0))') 'LARE_BC2_C4T_BENCH|ROUTE=',trim(route),'|REPEATS=',repeats, &
         '|CPU_SECONDS=',t1-t0,'|CHECKSUM=',total_checksum
  else
    call run_all(n,dz,.true.,checksum)
    write(*,'(*(g0))') 'LARE_BC2_C4T_LARE_VALIDATE_COMPLETE=PASS|ROUTE=',trim(route),'|CHECKSUM=',checksum
  end if

contains

  subroutine setup_route(r,n,dz)
    character(len=*),intent(in)::r
    integer,intent(out)::n
    real(real64),intent(out)::dz(MAXN)
    dz=0.0_real64
    select case(trim(r))
    case('LARE_R3');n=3;dz(1:3)=[140.0_real64,10.0_real64,10.0_real64]
    case('LARE_R4');n=4;dz(1:4)=[130.0_real64,10.0_real64,10.0_real64,10.0_real64]
    case('LARE_R5');n=5;dz(1:5)=[120.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64]
    case('LARE_R6');n=6;dz(1:6)=[110.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64]
    case('LARE_R8');n=8;dz(1:8)=[90.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64]
    case('LARE_R12');n=12;dz(1:12)=[50.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64, &
         10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64]
    case default
      call require(.false.,'unknown LARE route')
    end select
    call require(abs(sum(dz(1:n))-DEPTH)<=1.0e-12_real64,'route depth')
  end subroutine setup_route

  subroutine run_all(n,dz,emit,checksum)
    integer,intent(in)::n
    real(real64),intent(in)::dz(MAXN)
    logical,intent(in)::emit
    real(real64),intent(out)::checksum
    integer::ih
    checksum=0.0_real64
    do ih=1,NHIST
      call run_history(ih,n,dz,emit,checksum)
    end do
  end subroutine run_all

  subroutine run_history(ih,n,dz,emit,checksum)
    integer,intent(in)::ih,n
    real(real64),intent(in)::dz(MAXN)
    logical,intent(in)::emit
    real(real64),intent(inout)::checksum
    real(real64)::y(MAXN+2),yn(MAXN+2),theta(MAXN),mapped(16),initial_total
    real(real64)::total,cumb,qb,ledger
    integer::step,sub,it,maxit,cell
    call initial_state(history_lambda(ih),n,dz,y)
    initial_total=sum(y(1:n));maxit=0
    if(emit)write(*,'(*(g0))') 'LARE_BC2_C4T_INITIAL|ROUTE=',trim(route),'|HISTORY=',trim(history_label(ih)), &
         '|LAMBDA=',history_lambda(ih),'|TOTAL_STORAGE=',initial_total
    do step=1,NSTEPS
      do sub=1,SUBSTEPS
        call heun_step(y,DT,n,dz,yn,it)
        y=yn;maxit=max(maxit,it)
      end do
      theta(1:n)=y(1:n)/dz(1:n)
      call constitutive_guard(theta,n)
      total=sum(y(1:n));cumb=y(n+2)
      qb=qbottom(theta,n,dz)
      ledger=total-initial_total+cumb
      call require(abs(ledger)<=LEDGER_GATE,'water ledger')
      call map_theta16(theta,n,dz,mapped)
      if(emit)then
        write(*,'(*(g0))') 'LARE_BC2_C4T_STATE|ROUTE=',trim(route),'|HISTORY=',trim(history_label(ih)), &
             '|STEP=',step,'|TOTAL_STORAGE=',total,'|CUM_BOTTOM=',cumb,'|BOTTOM_FLUX=',qb,'|LEDGER=',ledger
        do cell=1,16
          write(*,'(*(g0))') 'LARE_BC2_C4T_CELL|ROUTE=',trim(route),'|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|CELL=',cell,'|THETA=',mapped(cell)
        end do
      end if
    end do
    checksum=checksum+sum(y(1:n))+y(n+2)+qb+sum(mapped)+real(maxit,real64)
  end subroutine run_history

  subroutine initial_state(lam,n,dz,y)
    real(real64),intent(in)::lam,dz(MAXN)
    integer,intent(in)::n
    real(real64),intent(out)::y(MAXN+2)
    real(real64)::front(J0:J1),theta(MAXN),ztop,zbot,ylow,yhigh,overlap,tj
    integer::j,i
    do j=J0,J1
      tj=theta_bin(j);front(j)=lam*psi_of_theta(tj)
      call require(front(j)>0.0_real64.and.front(j)<=DEPTH,'initial front bounds')
    end do
    ztop=0.0_real64
    do i=1,n
      zbot=ztop+dz(i);ylow=DEPTH-zbot;yhigh=DEPTH-ztop
      theta(i)=THETA_I
      do j=J0,J1
        overlap=max(0.0_real64,min(front(j),yhigh)-max(0.0_real64,ylow))
        theta(i)=theta(i)+DTH*overlap/dz(i)
      end do
      ztop=zbot
    end do
    call constitutive_guard(theta,n)
    y=0.0_real64
    y(1:n)=theta(1:n)*dz(1:n)
  end subroutine initial_state

  subroutine constitutive(theta,n,psi,k)
    integer,intent(in)::n
    real(real64),intent(in)::theta(MAXN)
    real(real64),intent(out)::psi(MAXN),k(MAXN)
    real(real64)::se,term
    integer::i
    psi=0.0_real64;k=0.0_real64
    do i=1,n
      se=(theta(i)-TR)/(TS-TR)
      call require(ieee_is_finite(se).and.se>0.0_real64.and.se<1.0_real64,'theta domain')
      psi(i)=((se**(-1.0_real64/MM)-1.0_real64)**(1.0_real64/NN))/ALPHA
      term=1.0_real64-(1.0_real64-se**(1.0_real64/MM))**MM
      k(i)=KS*se**ELL*term*term
      call require(ieee_is_finite(psi(i)).and.ieee_is_finite(k(i)).and.k(i)>=0.0_real64,'constitutive finite')
      call require(psi(i)>0.01_real64,'near saturation smoothing')
    end do
  end subroutine constitutive

  subroutine constitutive_guard(theta,n)
    integer,intent(in)::n
    real(real64),intent(in)::theta(MAXN)
    real(real64)::psi(MAXN),k(MAXN)
    call constitutive(theta,n,psi,k)
  end subroutine constitutive_guard

  real(real64) function qbottom(theta,n,dz) result(q)
    integer,intent(in)::n
    real(real64),intent(in)::theta(MAXN),dz(MAXN)
    real(real64)::psi(MAXN),k(MAXN),grad
    call constitutive(theta,n,psi,k)
    grad=1.0_real64-2.0_real64*psi(n)/dz(n)
    q=k(n)*grad
    call require(ieee_is_finite(q),'finite qbottom')
  end function qbottom

  subroutine rhs(y,n,dz,dy)
    integer,intent(in)::n
    real(real64),intent(in)::y(MAXN+2),dz(MAXN)
    real(real64),intent(out)::dy(MAXN+2)
    real(real64)::theta(MAXN),psi(MAXN),k(MAXN),qint(MAXN-1),kij,qb,qup,qdn
    integer::i
    theta=0.0_real64;theta(1:n)=y(1:n)/dz(1:n)
    call constitutive(theta,n,psi,k)
    qint=0.0_real64
    do i=1,n-1
      kij=(dz(i+1)*k(i)+dz(i)*k(i+1))/(dz(i)+dz(i+1))
      qint(i)=kij*(1.0_real64+2.0_real64*(psi(i+1)-psi(i))/(dz(i)+dz(i+1)))
    end do
    qb=k(n)*(1.0_real64-2.0_real64*psi(n)/dz(n))
    dy=0.0_real64
    do i=1,n
      if(i==1)then;qup=0.0_real64;else;qup=qint(i-1);end if
      if(i==n)then;qdn=qb;else;qdn=qint(i);end if
      dy(i)=qup-qdn
    end do
    dy(n+1)=0.0_real64
    dy(n+2)=qb
  end subroutine rhs

  subroutine heun_step(y,dt,n,dz,out,iters)
    integer,intent(in)::n
    real(real64),intent(in)::y(MAXN+2),dt,dz(MAXN)
    real(real64),intent(out)::out(MAXN+2)
    integer,intent(out)::iters
    real(real64)::f0(MAXN+2),fg(MAXN+2),guess(MAXN+2),nxt(MAXN+2),err
    integer::it
    call rhs(y,n,dz,f0)
    guess=y+dt*f0
    do it=1,MAXCOR
      call rhs(guess,n,dz,fg)
      nxt=y+0.5_real64*dt*(f0+fg)
      err=maxval(abs(nxt(1:n)/dz(1:n)-guess(1:n)/dz(1:n)))
      if(err<=COR_TOL)then
        out=nxt;iters=it;return
      end if
      guess=nxt
    end do
    call require(.false.,'Heun corrector convergence')
    out=guess;iters=MAXCOR
  end subroutine heun_step

  subroutine map_theta16(theta,n,dz,vals)
    integer,intent(in)::n
    real(real64),intent(in)::theta(MAXN),dz(MAXN)
    real(real64),intent(out)::vals(16)
    real(real64)::bnd(0:MAXN),lo,hi,w
    integer::i,c
    bnd=0.0_real64
    do i=1,n;bnd(i)=bnd(i-1)+dz(i);end do
    do c=1,16
      lo=10.0_real64*real(c-1,real64);hi=lo+10.0_real64;vals(c)=0.0_real64
      do i=1,n
        w=max(0.0_real64,min(hi,bnd(i))-max(lo,bnd(i-1)))
        vals(c)=vals(c)+theta(i)*w/10.0_real64
      end do
    end do
  end subroutine map_theta16

  pure real(real64) function theta_bin(j) result(v)
    integer,intent(in)::j
    v=TR+real(j,real64)*DTH
  end function theta_bin

  pure real(real64) function psi_of_theta(t) result(v)
    real(real64),intent(in)::t
    real(real64)::se
    se=(t-TR)/(TS-TR)
    v=((se**(-1.0_real64/MM)-1.0_real64)**(1.0_real64/NN))/ALPHA
  end function psi_of_theta

  pure real(real64) function history_lambda(ih) result(v)
    integer,intent(in)::ih
    select case(ih)
    case(1);v=0.375_real64
    case(2);v=0.625_real64
    case(3);v=0.875_real64
    case(4);v=1.125_real64
    case default;v=-1.0_real64
    end select
  end function history_lambda

  function history_label(ih) result(v)
    integer,intent(in)::ih
    character(len=3)::v
    select case(ih)
    case(1);v='V01'
    case(2);v='V02'
    case(3);v='V03'
    case(4);v='V04'
    case default;v='BAD'
    end select
  end function history_label

  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)') 'LARE_BC2_C4T_LARE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_lare_bc2_c4t_lare_compiled
