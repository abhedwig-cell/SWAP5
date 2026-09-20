program test_lare_bc2_c4t_fmc_compiled
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic
  implicit none
  integer, parameter :: NBINS=200, IBASE=100, J0=101, J1=199, NHIST=4, NSTEPS=64, NSUB=9
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64, ALPHA=0.021659_real64
  real(real64), parameter :: NN=1.734737_real64, MM=1.0_real64-1.0_real64/NN
  real(real64), parameter :: KS=31.225016_real64, ELL=0.98087_real64
  real(real64), parameter :: DEPTH=160.0_real64, OBS_DT=0.001_real64, SUB_DT=OBS_DT/real(NSUB,real64)
  real(real64), parameter :: DTH=(TS-TR)/real(NBINS,real64), THETA_I=TR+real(IBASE,real64)*DTH
  real(real64), parameter :: HARD_MASS=1.0e-12_real64, RELAX_TOL=1.0e-14_real64

  character(len=32) :: mode,arg
  integer :: repeats,rep
  real(real64) :: checksum,total_checksum,t0,t1

  mode='validate';arg=''
  call get_command_argument(1,mode)
  if(len_trim(mode)==0)mode='validate'
  if(trim(mode)=='bench')then
    call get_command_argument(2,arg);read(arg,*)repeats
    call require(repeats>=1,'positive repeats')
    total_checksum=0.0_real64
    call cpu_time(t0)
    do rep=1,repeats
      call run_all(.false.,checksum)
      total_checksum=total_checksum+checksum
    end do
    call cpu_time(t1)
    write(*,'(*(g0))') 'LARE_BC2_C4T_BENCH|ROUTE=FMC|REPEATS=',repeats, &
         '|CPU_SECONDS=',t1-t0,'|CHECKSUM=',total_checksum
  else
    call run_all(.true.,checksum)
    write(*,'(*(g0))') 'LARE_BC2_C4T_FMC_VALIDATE_COMPLETE=PASS|CHECKSUM=',checksum
  end if

contains

  subroutine run_all(emit,checksum)
    logical,intent(in)::emit
    real(real64),intent(out)::checksum
    integer::ih
    checksum=0.0_real64
    do ih=1,NHIST
      call run_history(ih,history_lambda(ih),emit,checksum)
    end do
  end subroutine run_all

  subroutine run_history(ih,lam,emit,checksum)
    integer,intent(in)::ih
    real(real64),intent(in)::lam
    logical,intent(in)::emit
    real(real64),intent(inout)::checksum
    real(real64)::h(J0:J1),hn(J0:J1),mapped(16)
    real(real64)::s0,s1,cumb,db,mass,relaxerr,q,initial_storage,ledger
    integer::j,step,sub,cell
    do j=J0,J1
      h(j)=lam*psi(theta_bin(j))
      call require(ieee_is_finite(h(j)).and.h(j)>0.0_real64.and.h(j)<=DEPTH,'initial front bounds')
    end do
    initial_storage=storage(h);cumb=0.0_real64
    if(emit)write(*,'(*(g0))') 'LARE_BC2_C4T_FMC_INITIAL|HISTORY=',trim(history_label(ih)), &
         '|LAMBDA=',lam,'|TOTAL_STORAGE=',initial_storage

    do step=1,NSTEPS
      do sub=1,NSUB
        s0=storage(h)
        call advance_substep(h,hn,relaxerr)
        s1=storage(hn)
        db=-(s1-s0)
        mass=(s1-s0)+db
        call require(abs(mass)<=HARD_MASS,'substep mass gate')
        call require(abs(relaxerr)<=RELAX_TOL,'relaxation storage gate')
        cumb=cumb+db
        h=hn
      end do
      s1=storage(h);q=terminal_bottom_flux(h);ledger=s1-initial_storage+cumb
      call require(abs(ledger)<=HARD_MASS,'history ledger gate')
      call mapped_theta16(h,mapped)
      if(emit)then
        write(*,'(*(g0))') 'LARE_BC2_C4T_FMC_STATE|HISTORY=',trim(history_label(ih)),'|STEP=',step, &
             '|TOTAL_STORAGE=',s1,'|CUM_BOTTOM=',cumb,'|BOTTOM_FLUX=',q,'|LEDGER=',ledger
        do cell=1,16
          write(*,'(*(g0))') 'LARE_BC2_C4T_FMC_CELL|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|CELL=',cell,'|THETA=',mapped(cell)
        end do
      end if
    end do
    checksum=checksum+s1+cumb+q+sum(mapped)+sum(h)
  end subroutine run_history

  subroutine advance_substep(h,out,drift)
    real(real64),intent(in)::h(J0:J1)
    real(real64),intent(out)::out(J0:J1),drift
    real(real64)::raw(J0:J1)
    integer::j
    do j=J0,J1
      raw(j)=h(j)+SUB_DT*velocity(j,h(j))
      call require(ieee_is_finite(raw(j)).and.raw(j)>0.0_real64.and.raw(j)<=DEPTH,'front physical bounds')
    end do
    out=raw
    call sort_desc(out)
    drift=DTH*(sum(out)-sum(raw))
  end subroutine advance_substep

  subroutine sort_desc(a)
    real(real64),intent(inout)::a(J0:J1)
    real(real64)::tmp
    integer::i,j,maxj
    do i=J0,J1-1
      maxj=i
      do j=i+1,J1
        if(a(j)>a(maxj))maxj=j
      end do
      if(maxj/=i)then;tmp=a(i);a(i)=a(maxj);a(maxj)=tmp;end if
    end do
  end subroutine sort_desc

  pure real(real64) function storage(h) result(v)
    real(real64),intent(in)::h(J0:J1)
    v=THETA_I*DEPTH+DTH*sum(h)
  end function storage

  pure real(real64) function velocity(j,h) result(v)
    integer,intent(in)::j
    real(real64),intent(in)::h
    real(real64)::tj
    tj=theta_bin(j)
    v=(kval(tj)-kval(THETA_I))/(tj-THETA_I)*(abs(psi(tj))/h-1.0_real64)
  end function velocity

  pure real(real64) function terminal_bottom_flux(h) result(v)
    real(real64),intent(in)::h(J0:J1)
    integer::j
    v=0.0_real64
    do j=J0,J1
      v=v-DTH*velocity(j,h(j))
    end do
  end function terminal_bottom_flux

  subroutine mapped_theta16(h,vals)
    real(real64),intent(in)::h(J0:J1)
    real(real64),intent(out)::vals(16)
    real(real64)::top,bot,ylow,yhigh,overlap,t
    integer::c,j
    do c=1,16
      top=10.0_real64*real(c-1,real64);bot=top+10.0_real64
      ylow=DEPTH-bot;yhigh=DEPTH-top;t=THETA_I
      do j=J0,J1
        overlap=max(0.0_real64,min(h(j),yhigh)-max(0.0_real64,ylow))
        t=t+DTH*overlap/10.0_real64
      end do
      call require(t>TR.and.t<TS.and.ieee_is_finite(t),'mapped theta bounds')
      vals(c)=t
    end do
  end subroutine mapped_theta16

  pure real(real64) function theta_bin(j) result(v)
    integer,intent(in)::j
    v=TR+real(j,real64)*DTH
  end function theta_bin

  pure real(real64) function psi(t) result(v)
    real(real64),intent(in)::t
    real(real64)::se
    se=(t-TR)/(TS-TR)
    v=((se**(-1.0_real64/MM)-1.0_real64)**(1.0_real64/NN))/ALPHA
  end function psi

  pure real(real64) function kval(t) result(v)
    real(real64),intent(in)::t
    real(real64)::se,term
    se=(t-TR)/(TS-TR)
    term=1.0_real64-(1.0_real64-se**(1.0_real64/MM))**MM
    v=KS*se**ELL*term*term
  end function kval

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
      write(*,'(A,1X,A)') 'LARE_BC2_C4T_FMC_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_lare_bc2_c4t_fmc_compiled
