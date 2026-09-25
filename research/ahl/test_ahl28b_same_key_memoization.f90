program test_ahl28b_same_key_memoization
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NBIND=200000, NREP=5
  real(real64), parameter :: dt=0.25_real64
  real(real64), allocatable :: cofgen(:,:),cofgen2(:,:)
  type(b110_default_mvg_parameters_t), target :: hp,hp2
  type(b110_adaptive_hydraulic_provider_t) :: provider
  real(real64) :: tb(NREP),t0,t1,hprobe(1),wprobe(1),kprobe(1),cprobe(1),dprobe(1)
  logical :: ok,hit
  integer :: j,r,b0,h0,m0,e0,b1,h1,m1,e1

  allocate(cofgen(42,1));cofgen=0.0_real64
  cofgen(1,1)=0.032_real64;cofgen(2,1)=0.423_real64;cofgen(3,1)=4.75_real64
  cofgen(4,1)=0.0135_real64;cofgen(5,1)=0.365_real64;cofgen(6,1)=1.455_real64
  cofgen(7,1)=1.0_real64-1.0_real64/cofgen(6,1);cofgen(8,1)=cofgen(4,1)
  cofgen(9,1)=0.0_real64;cofgen(10,1)=cofgen(3,1);cofgen(11,1)=0.999_real64
  cofgen(12,1)=0.99_real64*cofgen(3,1);cofgen(22,1)=-1.0e6_real64;cofgen(23,1)=1.0e-12_real64
  call initialize_b110_default_mvg_parameters(hp,cofgen)

  call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
  if(.not.ok .or. hit) error stop 'first bind must build'
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)

  call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
  if(.not.ok .or. .not.hit) error stop 'same-key provider reuse must report hit-equivalent'
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  if(b1/=b0 .or. h1/=h0 .or. m1/=m0 .or. e1/=e0) error stop 'same-key reuse touched shared cache'

  do r=1,NREP
    call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
    call cpu_time(t0)
    do j=1,NBIND
      call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
      if(.not.ok .or. .not.hit) error stop 'same-key memoized bind failed'
    end do
    call cpu_time(t1)
    tb(r)=(t1-t0)/real(NBIND,real64)
    call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
    if(b1/=b0 .or. h1/=h0 .or. m1/=m0 .or. e1/=e0) error stop 'memoized binds touched shared cache'
  end do

  ! Same hydraulic authority with a different step duration must reuse the
  ! immutable table while rebinding the analytical fallback. Saturated
  ! capacity is exactly step_duration*1e-7 and therefore exposes stale fallback
  ! state immediately.
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call bind_b110_adaptive_hydraulic_provider(provider,hp,0.5_real64,ok,hit)
  if(.not.ok .or. .not.hit) error stop 'same-key changed-dt reuse failed'
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  if(b1/=b0 .or. h1/=h0 .or. m1/=m0 .or. e1/=e0) error stop 'changed-dt reuse touched shared cache'
  hprobe=0.0_real64
  call provider%evaluate(hprobe,wprobe,kprobe,cprobe,dprobe)
  if(cprobe(1)/=0.5_real64*1.0e-7_real64) error stop 'analytical fallback step duration stale'
  call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
  call provider%evaluate(hprobe,wprobe,kprobe,cprobe,dprobe)
  if(cprobe(1)/=dt*1.0e-7_real64) error stop 'analytical fallback step duration restore failed'

  ! A bitwise hydraulic-authority change must never take the local fast path.
  allocate(cofgen2(42,1));cofgen2=cofgen
  cofgen2(4,1)=0.0136_real64
  call initialize_b110_default_mvg_parameters(hp2,cofgen2)
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call bind_b110_adaptive_hydraulic_provider(provider,hp2,dt,ok,hit)
  if(.not.ok) error stop 'changed authority bind failed'
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  if((b1-b0)+(h1-h0)+(m1-m0)<=0) error stop 'changed authority incorrectly stayed on local fast path'
  if(e1<e0 .or. e1>e0+1) error stop 'changed authority cache entry accounting'
  call bind_b110_adaptive_hydraulic_provider(provider,hp2,dt,ok,hit)
  if(.not.ok .or. .not.hit) error stop 'changed authority second bind did not local-reuse'
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call bind_b110_adaptive_hydraulic_provider(provider,hp,dt,ok,hit)
  if(.not.ok .or. .not.hit) error stop 'restore original authority did not cache-hit'
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  if(h1/=h0+1 .or. b1/=b0 .or. m1/=m0 .or. e1/=e0) error stop 'restore authority cache accounting'
  write(*,'(A)') 'AHL28B_AUTHORITY_AND_DT_GATES=PASS'

  call sort5(tb)
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  write(*,'(A,ES18.10)') 'AHL28B_SAME_KEY_BIND_SECONDS ',tb(3)
  write(*,'(A,F12.6)') 'AHL28B_REDUCTION_FROM_BASELINE ',1.0_real64-tb(3)/5.9575e-7_real64
  write(*,'(A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') 'AHL28B_CACHE BUILDS=',b1,'HITS=',h1,'MISSES=',m1,'ENTRIES=',e1
  if(tb(3)>=0.25_real64*5.9575e-7_real64) error stop 'memoized bind missed 75 percent reduction gate'
  write(*,'(A)') 'AHL28B_MEMOIZATION_MICROBENCH=PASS'
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
  end subroutine sort5
end program test_ahl28b_same_key_memoization
