program test_fahl28_bind_overhead
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NREP=20000
  real(real64), target :: input(24,1)
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_default_mvg_provider_t) :: analytical
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  real(real64) :: t0,t1,ta,td,dt
  integer :: i,b0,h0,m0,e0,b1,h1,m1,e1
  logical :: ok,hit

  input=0.0_real64
  input(1,1)=0.032_real64
  input(2,1)=0.423_real64
  input(3,1)=4.75_real64
  input(4,1)=0.0135_real64
  input(5,1)=0.365_real64
  input(6,1)=1.455_real64
  input(7,1)=1.0_real64-1.0_real64/input(6,1)
  input(8,1)=input(4,1)
  input(9,1)=0.0_real64
  input(10,1)=input(3,1)
  input(11,1)=0.999_real64
  input(12,1)=0.99_real64*input(3,1)
  input(22,1)=-1.0e6_real64
  input(23,1)=1.0e-12_real64

  call initialize_b110_default_mvg_parameters(parameters,input)

  ! One cold acquisition, excluded from the timed warm-hit benchmark.
  call bind_b110_adaptive_hydraulic_provider(adaptive,parameters,0.25_real64,ok,hit)
  call require(ok,'cold adaptive bind')
  call require(.not.hit,'first adaptive acquisition is a build')
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)

  call cpu_time(t0)
  do i=1,NREP
    dt=0.20_real64+0.05_real64*real(mod(i,2),real64)
    call bind_b110_default_mvg_provider(analytical,parameters,dt)
  end do
  call cpu_time(t1)
  ta=(t1-t0)/real(NREP,real64)

  call cpu_time(t0)
  do i=1,NREP
    dt=0.20_real64+0.05_real64*real(mod(i,2),real64)
    call bind_b110_adaptive_hydraulic_provider(adaptive,parameters,dt,ok,hit)
    if(.not.ok .or. .not.hit) error stop 'warm adaptive bind did not hit cache'
  end do
  call cpu_time(t1)
  td=(t1-t0)/real(NREP,real64)

  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)

  write(*,'(A,4(1X,I0))') 'FAHL28_CACHE_BEFORE',b0,h0,m0,e0
  write(*,'(A,4(1X,I0))') 'FAHL28_CACHE_AFTER',b1,h1,m1,e1
  write(*,'(A,1X,ES18.10)') 'FAHL28_ANALYTICAL_BIND_SEC',ta
  write(*,'(A,1X,ES18.10)') 'FAHL28_ADAPTIVE_WARM_BIND_SEC',td
  write(*,'(A,1X,F12.4)') 'FAHL28_WARM_BIND_RATIO',td/max(ta,tiny(1.0_real64))

  call require(b1==b0,'no rebuild during warm loop')
  call require(h1-h0==NREP,'one cache hit per warm bind')
  call require(m1==m0,'no additional cache miss during warm loop')
  call require(e1==e0,'cache entry count stable')
  write(*,'(A)') 'FAHL28_REPEATED_BIND_BASELINE=PASS'

contains
  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)') 'FAHL28_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fahl28_bind_overhead
