program test_ahl33_multikey_switching
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NKEY=64, NREQ=200000, NREP=5
  type(b110_default_mvg_parameters_t), target :: p(NKEY)
  type(b110_adaptive_hydraulic_provider_t) :: provider
  real(real64) :: raw(24,1), t_same(NREP), t16(NREP), t64(NREP)
  integer :: i,r,b0,h0,m0,e0,b1,h1,m1,e1
  logical :: ok,hit

  do i=1,NKEY
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(p(i),raw)
  end do

  ! Untimed registry warmup. A single long-lived provider is intentional:
  ! every changed authority is acquired through the production provider path.
  do i=1,NKEY
    call bind_b110_adaptive_hydraulic_provider(provider,p(i),0.25_real64,ok,hit)
    call require(ok,'warmup bind')
  end do
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call require(e0>=NKEY,'all 64 authorities retained after warmup')

  do r=1,NREP
    ! Put provider on a key outside the 16-key working set before each switch16
    ! batch so the first request is a registry hit rather than local reuse.
    call bind_b110_adaptive_hydraulic_provider(provider,p(NKEY),0.25_real64,ok,hit)
    call time_same(provider,p(1),t_same(r))
    call bind_b110_adaptive_hydraulic_provider(provider,p(NKEY),0.25_real64,ok,hit)
    call time_switch(provider,p,16,t16(r))
    call time_switch(provider,p,NKEY,t64(r))
  end do

  call sort5(t_same); call sort5(t16); call sort5(t64)
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)

  write(*,'(A,1X,ES18.10)') 'AHL33_SAME_KEY_SEC_PER_BIND',t_same(3)
  write(*,'(A,1X,ES18.10,1X,A,F12.4)') 'AHL33_SWITCH16_SEC_PER_BIND',t16(3), &
       'RATIO_TO_SAME=',t16(3)/max(t_same(3),tiny(1.0_real64))
  write(*,'(A,1X,ES18.10,1X,A,F12.4)') 'AHL33_SWITCH64_SEC_PER_BIND',t64(3), &
       'RATIO_TO_SAME=',t64(3)/max(t_same(3),tiny(1.0_real64))
  write(*,'(A,4(1X,I0))') 'AHL33_CACHE_BEFORE',b0,h0,m0,e0
  write(*,'(A,4(1X,I0))') 'AHL33_CACHE_AFTER',b1,h1,m1,e1
  call require(b1==b0,'no timed rebuilds')
  call require(m1==m0,'no timed misses')
  call require(e1==e0,'registry entries stable')
  call require(h1>h0,'multi-key switching produced registry hits')
  write(*,'(A)') 'AHL33_CHARACTERIZATION=PASS'

contains

  subroutine time_same(prov,param,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::param
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q
    logical::lok,lhit
    call bind_b110_adaptive_hydraulic_provider(prov,param,0.25_real64,lok,lhit)
    if(.not.lok) error stop 'same-key prebind'
    call cpu_time(a)
    do q=1,NREQ
      call bind_b110_adaptive_hydraulic_provider(prov,param,0.25_real64,lok,lhit)
      if(.not.lok .or. .not.lhit) error stop 'same-key timed bind'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_same

  subroutine time_switch(prov,param,nworking,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::param(:)
    integer,intent(in)::nworking
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    logical::lok,lhit
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,nworking)
      call bind_b110_adaptive_hydraulic_provider(prov,param(idx),0.25_real64,lok,lhit)
      if(.not.lok .or. .not.lhit) error stop 'switch timed bind'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_switch

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(24,1)
    real(real64)::scale,n
    a=0.0_real64
    scale=1.0_real64+1.0e-5_real64*real(idx,real64)
    n=1.50_real64+5.0e-4_real64*real(mod(idx,11),real64)
    a(1,1)=0.02_real64; a(2,1)=0.43_real64; a(3,1)=5.0_real64*scale
    a(4,1)=0.015_real64; a(5,1)=0.5_real64; a(6,1)=n
    a(7,1)=1.0_real64-1.0_real64/n; a(8,1)=a(4,1)
    a(9,1)=0.0_real64; a(10,1)=a(3,1); a(11,1)=0.999_real64
    a(12,1)=0.99_real64*a(3,1); a(22,1)=-1.0e6_real64; a(23,1)=1.0e-12_real64
  end subroutine make_raw

  subroutine sort5(v)
    real(real64),intent(inout)::v(5)
    real(real64)::tmp
    integer::a,b
    do a=1,4
      do b=a+1,5
        if(v(b)<v(a))then;tmp=v(a);v(a)=v(b);v(b)=tmp;end if
      end do
    end do
  end subroutine sort5

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'AHL33_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl33_multikey_switching
