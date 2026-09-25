program test_fahl44_demand_abi
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, bind_b110_adaptive_hydraulic_provider
  implicit none
  integer, parameter :: n=60, reps=200000
  real(real64), parameter :: dt=1.0e-4_real64
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  real(real64) :: cofgen(42,n),h(n),wa(n),ka(n),ca(n),da(n),wd(n),kd(n),cd(n),dd(n)
  integer(int64) :: c0,c1,rate
  integer :: i,r
  real(real64) :: seconds,checksum
  logical :: ok,hit

  call make_parameters(cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,dt)
  call bind_b110_adaptive_hydraulic_provider(adaptive,hp,dt,ok,hit)
  call require(ok,'adaptive bind')

  do i=1,n
    h(i)=-10.0_real64**(0.05_real64+5.7_real64*real(i-1,real64)/real(n-1,real64))
  end do
  h(1)=-0.5_real64
  h(n)=-1.0e6_real64

  call adaptive%evaluate(h,wa,ka,ca,da)
  wd=-999.0_real64;kd=-999.0_real64;cd=-999.0_real64;dd=-999.0_real64
  call adaptive%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wd,kd,cd,dd)
  call require(same_bits_vector(wa,wd),'adaptive water demand equals full adaptive representation')
  wd=-999.0_real64;kd=-999.0_real64;cd=-999.0_real64;dd=-999.0_real64
  call adaptive%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,wd,kd,cd,dd)
  call require(same_bits_vector(ca,cd),'adaptive capacity demand equals full adaptive representation')
  write(*,'(A)') 'FAHL44_DEMAND_SEMANTICS=PASS'

  h=-75.0_real64
  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call analytical%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wd,kd,cd,dd)
    checksum=checksum+wd(1)+wd(n)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  write(*,'(*(g0))') 'FAHL44_TIMING|MODE=ANALYTICAL_THETA|N=',n,'|REPS=',reps,'|NS_PER=', &
       1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum

  checksum=0.0_real64
  call system_clock(c0)
  do r=1,reps
    call adaptive%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wd,kd,cd,dd)
    checksum=checksum+wd(1)+wd(n)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  write(*,'(*(g0))') 'FAHL44_TIMING|MODE=ADAPTIVE_THETA|N=',n,'|REPS=',reps,'|NS_PER=', &
       1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum

  checksum=0.0_real64
  call system_clock(c0)
  do r=1,reps
    call adaptive%evaluate(h,wd,kd,cd,dd)
    checksum=checksum+wd(1)+wd(n)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  write(*,'(*(g0))') 'FAHL44_TIMING|MODE=ADAPTIVE_FULL|N=',n,'|REPS=',reps,'|NS_PER=', &
       1.0e9_real64*seconds/real(reps,real64),'|CHECKSUM=',checksum
  write(*,'(A)') 'FAHL44_DEMAND_TIMING=PASS'

contains
  subroutine make_parameters(c)
    real(real64),intent(out)::c(42,n)
    integer::k
    c=0.0_real64
    do k=1,n
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
  end subroutine
  logical function same_bits_vector(a,b) result(okbits)
    real(real64),intent(in)::a(:),b(:)
    integer(int64),allocatable::ia(:),ib(:)
    allocate(ia(size(a)),ib(size(b)))
    ia=transfer(a,ia);ib=transfer(b,ib)
    okbits=all(ia==ib)
  end function
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)') 'FAHL44_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
