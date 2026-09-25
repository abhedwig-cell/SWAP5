program test_ahl28_binding_overhead
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NBIND=200000, NEVAL=200000, NH=16, NREP=5
  real(real64), parameter :: dt=0.25_real64
  real(real64), allocatable :: cofgen(:,:)
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_adaptive_hydraulic_provider_t) :: provider
  real(real64) :: h(NH),w(NH),k(NH),c(NH),d(NH)
  real(real64) :: tb(NREP),te(NREP),t0,t1,checksum
  logical :: ok,hit
  integer :: i,j,r,b0,h0,m0,e0,b1,h1,m1,e1

  allocate(cofgen(24,1));cofgen=0.0_real64
  cofgen(1,1)=0.032_real64;cofgen(2,1)=0.423_real64;cofgen(3,1)=4.75_real64
  cofgen(4,1)=0.0135_real64;cofgen(5,1)=0.365_real64;cofgen(6,1)=1.455_real64
  cofgen(7,1)=1.0_real64-1.0_real64/cofgen(6,1);cofgen(8,1)=cofgen(4,1)
  cofgen(9,1)=0.0_real64;cofgen(10,1)=cofgen(3,1);cofgen(11,1)=0.999_real64
  cofgen(12,1)=0.99_real64*cofgen(3,1);cofgen(22,1)=-1.0e6_real64;cofgen(23,1)=1.0e-12_real64
  call initialize_b110_default_mvg_parameters(hp,cofgen)

  call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
  if(.not.ok .or. hit) error stop 'first bind must build'
  call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
  if(.not.ok .or. .not.hit) error stop 'second bind must hit'

  do i=1,NH
    h(i)=-10.0_real64**(0.0_real64+4.0_real64*real(i-1,real64)/real(NH-1,real64))
  end do

  checksum=0.0_real64
  do r=1,NREP
    call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
    call cpu_time(t0)
    do j=1,NBIND
      call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
      if(.not.ok .or. .not.hit) error stop 'warm bind failed'
    end do
    call cpu_time(t1)
    tb(r)=(t1-t0)/real(NBIND,real64)
    call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
    if(h1-h0/=NBIND .or. b1/=b0 .or. m1/=m0 .or. e1/=e0) error stop 'warm bind cache accounting'

    call cpu_time(t0)
    do j=1,NEVAL
      call provider%evaluate(h,w,k,c,d)
      checksum=checksum+sum(w)+1.0e-6_real64*sum(c)+1.0e-9_real64*sum(k)
    end do
    call cpu_time(t1)
    te(r)=(t1-t0)/real(NEVAL,real64)
  end do

  call sort5(tb);call sort5(te)
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  write(*,'(A,ES18.10)') 'AHL28_WARM_BIND_SECONDS ',tb(3)
  write(*,'(A,ES18.10)') 'AHL28_PROVIDER_EVAL16_SECONDS ',te(3)
  write(*,'(A,F12.6)') 'AHL28_BIND_OVER_EVAL16_RATIO ',tb(3)/te(3)
  write(*,'(A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') 'AHL28_CACHE BUILDS=',b1,'HITS=',h1,'MISSES=',m1,'ENTRIES=',e1
  write(*,'(A,ES24.16)') 'AHL28_CHECKSUM ',checksum
  write(*,'(A)') 'AHL28_BINDING_MICROBENCH=PASS'
contains
  subroutine sort5(v)
    real(real64),intent(inout)::v(5)
    real(real64)::q
    integer::a,b
    do a=1,4
      do b=a+1,5
        if(v(b)<v(a))then;q=v(a);v(a)=v(b);v(b)=q;end if
      end do
    end do
  end subroutine
end program test_ahl28_binding_overhead
