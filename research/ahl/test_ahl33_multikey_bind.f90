program test_ahl33_multikey_bind
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NREQ=200000, NKEY=64
  type(b110_default_mvg_parameters_t), target :: p(NKEY)
  type(b110_adaptive_hydraulic_provider_t) :: provider
  real(real64) :: raw(42,1)
  integer :: i
  logical :: ok,hit

  do i=1,NKEY
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(p(i),raw)
  end do

  ! Untimed population of all keys used by the switching workloads.
  do i=1,NKEY
    call bind_b110_adaptive_hydraulic_provider(provider,p(i),0.25_real64,ok,hit)
    call require(ok,'registry warmup')
  end do

  call run_case('same_key',1,p,provider)
  call run_case('switch_16',16,p,provider)
  call run_case('switch_64',64,p,provider)
  write(*,'(A)') 'AHL33_CHARACTERIZATION=PASS'

contains

  subroutine run_case(label,nunique,params,prov)
    character(len=*),intent(in)::label
    integer,intent(in)::nunique
    type(b110_default_mvg_parameters_t),target,intent(in)::params(:)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    integer::q,idx,b0,h0,m0,e0,b1,h1,m1,e1
    real(real64)::t0,t1
    logical::lok,lhit

    ! For same_key explicitly establish the key before timing. For switching
    ! workloads the first timed bind is deliberately a real authority switch.
    if(nunique==1)then
      call bind_b110_adaptive_hydraulic_provider(prov,params(1),0.25_real64,lok,lhit)
      call require(lok,'same-key setup')
    end if

    call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
    call cpu_time(t0)
    do q=1,NREQ
      idx=1+mod(q-1,nunique)
      call bind_b110_adaptive_hydraulic_provider(prov,params(idx),0.25_real64,lok,lhit)
      if(.not.lok) error stop 'AHL33 bind failure'
    end do
    call cpu_time(t1)
    call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)

    write(*,'(A,1X,A,1X,A,I0,1X,A,ES18.10,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL33_BIND',trim(label),'UNIQUE=',nunique,'SEC_PER_BIND=',(t1-t0)/real(NREQ,real64), &
         'BUILD_DELTA=',b1-b0,'HIT_DELTA=',h1-h0,'MISS_DELTA=',m1-m0,'ENTRIES=',e1
    call require(b1-b0==0,'no timed builds')
    call require(m1-m0==0,'no timed misses')
    if(nunique==1)then
      call require(h1-h0==0,'same-key path bypasses shared registry')
    else
      call require(h1-h0==NREQ,'multi-key path uses warmed registry')
    end if
  end subroutine run_case

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(42,1)
    real(real64)::n,scale
    a=0.0_real64
    scale=1.0_real64+1.0e-5_real64*real(idx,real64)
    n=1.60_real64
    a(1,1)=0.02_real64
    a(2,1)=0.43_real64
    a(3,1)=5.0_real64*scale
    a(4,1)=0.015_real64
    a(5,1)=0.5_real64
    a(6,1)=n
    a(7,1)=1.0_real64-1.0_real64/n
    a(8,1)=a(4,1)
    a(9,1)=0.0_real64
    a(10,1)=a(3,1)
    a(11,1)=0.999_real64
    a(12,1)=0.99_real64*a(3,1)
    a(22,1)=-1.0e6_real64
    a(23,1)=1.0e-12_real64
  end subroutine make_raw

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'AHL33_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl33_multikey_bind
