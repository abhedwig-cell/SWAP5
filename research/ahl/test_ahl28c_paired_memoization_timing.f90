program test_ahl28c_paired_memoization_timing
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NOP=200000, NPAIR=9
  real(real64), target :: raw(24,1)
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_adaptive_hydraulic_provider_t) :: memoized
  real(real64) :: baseline_t(NPAIR), memo_t(NPAIR), ratio(NPAIR)
  real(real64) :: t0,t1,dt
  logical :: ok,hit
  integer :: i,r,b0,h0,m0,e0,b1,h1,m1,e1

  call initialize_raw(raw)
  call initialize_b110_default_mvg_parameters(parameters,raw)

  ! Warm the shared cache once, then establish the long-lived candidate.
  call bind_b110_adaptive_hydraulic_provider(memoized,parameters,0.25_real64,ok,hit)
  call require(ok .and. .not.hit,'cold warmup must build')
  call bind_b110_adaptive_hydraulic_provider(memoized,parameters,0.25_real64,ok,hit)
  call require(ok .and. hit,'memoized provider warmup')

  ! Correctness: local reuse must bypass shared-cache accounting even when
  ! the step duration changes, because only the analytical fallback changes.
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call bind_b110_adaptive_hydraulic_provider(memoized,parameters,0.5_real64,ok,hit)
  call require(ok .and. hit,'changed-dt local reuse')
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  call require(b1==b0 .and. h1==h0 .and. m1==m0 .and. e1==e0,'local reuse touched cache')
  call bind_b110_adaptive_hydraulic_provider(memoized,parameters,0.25_real64,ok,hit)

  do r=1,NPAIR
    if(mod(r,2)==1)then
      call time_baseline(baseline_t(r))
      call time_memoized(memo_t(r))
    else
      call time_memoized(memo_t(r))
      call time_baseline(baseline_t(r))
    end if
    ratio(r)=memo_t(r)/baseline_t(r)
    write(*,'(A,I0,2(1X,ES18.10),1X,F12.8)') 'AHL28C_PAIR ',r,baseline_t(r),memo_t(r),ratio(r)
  end do
  call sort9(ratio)
  write(*,'(A,F12.8)') 'AHL28C_MEDIAN_RATIO ',ratio(5)
  write(*,'(A,F12.8)') 'AHL28C_MEDIAN_REDUCTION ',1.0_real64-ratio(5)
  if(ratio(5)>0.25_real64) error stop 'paired memoization missed frozen 75 percent reduction gate'
  write(*,'(A)') 'AHL28C_PAIRED_TIMING=PASS'

contains

  subroutine time_baseline(elapsed)
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q
    call cpu_time(a)
    do q=1,NOP
      dt=0.20_real64+0.05_real64*real(mod(q,2),real64)
      call fresh_cache_hit(parameters,dt)
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NOP,real64)
  end subroutine time_baseline

  subroutine fresh_cache_hit(p,step_duration)
    type(b110_default_mvg_parameters_t),target,intent(in)::p
    real(real64),intent(in)::step_duration
    type(b110_adaptive_hydraulic_provider_t) :: fresh
    logical::local_ok,local_hit
    call bind_b110_adaptive_hydraulic_provider(fresh,p,step_duration,local_ok,local_hit)
    if(.not.local_ok .or. .not.local_hit) error stop 'fresh warm-cache acquisition failed'
  end subroutine fresh_cache_hit

  subroutine time_memoized(elapsed)
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,cb0,ch0,cm0,ce0,cb1,ch1,cm1,ce1
    call b110_adaptive_hydraulic_cache_stats(cb0,ch0,cm0,ce0)
    call cpu_time(a)
    do q=1,NOP
      dt=0.20_real64+0.05_real64*real(mod(q,2),real64)
      call bind_b110_adaptive_hydraulic_provider(memoized,parameters,dt,ok,hit)
      if(.not.ok .or. .not.hit) error stop 'memoized bind failed'
    end do
    call cpu_time(b)
    call b110_adaptive_hydraulic_cache_stats(cb1,ch1,cm1,ce1)
    if(cb1/=cb0 .or. ch1/=ch0 .or. cm1/=cm0 .or. ce1/=ce0) &
         error stop 'memoized timed path touched shared cache'
    elapsed=(b-a)/real(NOP,real64)
  end subroutine time_memoized

  subroutine initialize_raw(a)
    real(real64),intent(out)::a(24,1)
    a=0.0_real64
    a(1,1)=0.032_real64;a(2,1)=0.423_real64;a(3,1)=4.75_real64
    a(4,1)=0.0135_real64;a(5,1)=0.365_real64;a(6,1)=1.455_real64
    a(7,1)=1.0_real64-1.0_real64/a(6,1);a(8,1)=a(4,1)
    a(9,1)=0.0_real64;a(10,1)=a(3,1);a(11,1)=0.999_real64
    a(12,1)=0.99_real64*a(3,1);a(22,1)=-1.0e6_real64;a(23,1)=1.0e-12_real64
  end subroutine initialize_raw

  subroutine sort9(v)
    real(real64),intent(inout)::v(9)
    real(real64)::x
    integer::a,b
    do a=1,8
      do b=a+1,9
        if(v(b)<v(a))then;x=v(a);v(a)=v(b);v(b)=x;end if
      end do
    end do
  end subroutine sort9

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)')'AHL28C_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_ahl28c_paired_memoization_timing
