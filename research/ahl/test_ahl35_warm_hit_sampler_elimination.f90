program test_ahl35_warm_hit_sampler_elimination
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: NKEY=64, NREQ=200000, NPAIR=9
  type(b110_default_mvg_parameters_t), target :: p(NKEY)
  type(b110_adaptive_hydraulic_provider_t) :: provider
  real(real64) :: raw(24,1), candidate_times(NPAIR), baseline_times(NPAIR), ratios(NPAIR)
  integer :: i,r,b0,h0,m0,e0,b1,h1,m1,e1
  logical :: ok,hit

  do i=1,NKEY
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(p(i),raw)
  end do

  ! Warm all exact keys outside the timed region.
  do i=1,NKEY
    call bind_b110_adaptive_hydraulic_provider(provider,p(i),0.25_real64,ok,hit)
    call require(ok,'warmup bind')
  end do
  call require_registry_warm()

  call check_step_duration_fallback(provider,p)

  ! Normalize the provider to the round-robin terminal key and start the timed
  ! accounting only after the untimed semantic checks above.
  call bind_b110_adaptive_hydraulic_provider(provider,p(NKEY),0.25_real64,ok,hit)
  call require(ok,'timing normalization bind')
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call require(e0>=NKEY,'64 warm registry entries')

  do r=1,NPAIR
    if(mod(r,2)==1) then
      call time_baseline(provider,p,baseline_times(r))
      call time_candidate(provider,p,candidate_times(r))
    else
      call time_candidate(provider,p,candidate_times(r))
      call time_baseline(provider,p,baseline_times(r))
    end if
    ratios(r)=candidate_times(r)/baseline_times(r)
    write(*,'(A,1X,I0,1X,ES18.10,1X,ES18.10,1X,F10.6)') &
         'AHL35_PAIR',r,baseline_times(r),candidate_times(r),ratios(r)
  end do

  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)
  call require(b1==b0,'no timed builds')
  call require(m1==m0,'no timed misses')
  call require(e1==e0,'entry count stable')
  call require(h1-h0==2*NREQ*NPAIR,'exactly one registry hit per timed bind')

  call sort9(ratios)
  write(*,'(A,1X,F10.6)') 'AHL35_MEDIAN_RATIO',ratios(5)
  write(*,'(A,1X,F10.6)') 'AHL35_MEDIAN_REDUCTION',1.0_real64-ratios(5)
  call require(ratios(5)<=0.90_real64,'paired timing gate')
  write(*,'(A)') 'AHL35_WARM_HIT_SAMPLER_ELIMINATION=PASS'

contains

  subroutine require_registry_warm()
    integer :: bb,hh,mm,ee
    call b110_adaptive_hydraulic_cache_stats(bb,hh,mm,ee)
    call require(ee>=NKEY,'64 warm registry entries before semantic checks')
  end subroutine require_registry_warm

  subroutine time_candidate(prov,param,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::param(:)
    real(real64),intent(out)::elapsed
    real(real64)::a,b
    integer::q,idx
    logical::lok,lhit

    call bind_b110_adaptive_hydraulic_provider(prov,param(size(param)),0.25_real64,lok,lhit)
    call require(lok,'candidate prebind')
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,size(param))
      call bind_b110_adaptive_hydraulic_provider(prov,param(idx),0.25_real64,lok,lhit)
      if(.not.lok .or. .not.lhit) error stop 'candidate timed warm hit'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_candidate

  subroutine time_baseline(prov,param,elapsed)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::param(:)
    real(real64),intent(out)::elapsed
    type(b110_default_mvg_parameters_t),target :: sampler_parameters
    type(b110_default_mvg_provider_t) :: sampler
    real(real64)::one_node_input(42,1),a,b
    integer::q,idx
    logical::lok,lhit

    call bind_b110_adaptive_hydraulic_provider(prov,param(size(param)),0.25_real64,lok,lhit)
    call require(lok,'baseline prebind')
    call cpu_time(a)
    do q=1,NREQ
      idx=1+mod(q-1,size(param))
      one_node_input(:,1)=param(idx)%cofgen(1:42,1)
      call initialize_b110_default_mvg_parameters(sampler_parameters,one_node_input, &
           param(idx)%ksatexm_extension_enabled)
      call bind_b110_default_mvg_provider(sampler,sampler_parameters,0.25_real64)
      call bind_b110_adaptive_hydraulic_provider(prov,param(idx),0.25_real64,lok,lhit)
      if(.not.lok .or. .not.lhit) error stop 'baseline timed warm hit'
    end do
    call cpu_time(b)
    elapsed=(b-a)/real(NREQ,real64)
  end subroutine time_baseline

  subroutine check_step_duration_fallback(prov,param)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::prov
    type(b110_default_mvg_parameters_t),target,intent(in)::param(:)
    type(b110_default_mvg_provider_t) :: ref
    real(real64)::h(1),wa(1),ka(1),ca(1),da(1),wr(1),kr(1),cr(1),dr(1)
    logical::lok,lhit

    ! p(2) is already warm but different from the current provider authority.
    call bind_b110_adaptive_hydraulic_provider(prov,param(1),0.25_real64,lok,lhit)
    call require(lok,'fallback prebind')
    call bind_b110_adaptive_hydraulic_provider(prov,param(2),0.5_real64,lok,lhit)
    call require(lok .and. lhit,'changed-key warm hit at new step duration')
    call bind_b110_default_mvg_provider(ref,param(2),0.5_real64)
    h(1)=-0.5_real64
    call prov%evaluate(h,wa,ka,ca,da)
    call ref%evaluate(h,wr,kr,cr,dr)
    call require(all(wa==wr),'fallback theta current')
    call require(all(ka==kr),'fallback K current')
    call require(all(ca==cr),'fallback C current')
    call require(all(da==dr),'fallback dKdh current')
    write(*,'(A)') 'AHL35_STEP_DURATION_FALLBACK=PASS'
  end subroutine check_step_duration_fallback

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

  subroutine sort9(v)
    real(real64),intent(inout)::v(9)
    real(real64)::tmp
    integer::a,b
    do a=1,8
      do b=a+1,9
        if(v(b)<v(a))then
          tmp=v(a);v(a)=v(b);v(b)=tmp
        end if
      end do
    end do
  end subroutine sort9

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'AHL35_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl35_warm_hit_sampler_elimination
