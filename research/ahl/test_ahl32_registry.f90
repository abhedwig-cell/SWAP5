program test_ahl32_registry
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, &
       b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key, B110_AHL_MAX_CACHE
  implicit none

  call stage12_ten_thousand()
  call collision_safety()
  call stage3_capacity_plus_one()
  write(*,'(A)') 'AHL32_REGISTRY_ALL=PASS'

contains

  subroutine stage12_ten_thousand()
    integer, parameter :: N=10000
    type(b110_adaptive_hydraulic_cache_t) :: registry
    type(b110_default_mvg_parameters_t) :: parameters
    type(b110_default_mvg_provider_t) :: provider
    type(b110_adaptive_hydraulic_table_t) :: table
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: raw(24,1)
    logical :: hit,ok
    integer :: i,failures,builds1,hits1,misses1,entries1
    integer :: builds2,hits2,misses2,entries2,max_probes1,max_probes2
    integer(int64) :: probes1,probes2
    real(real64) :: t0,t1,first_seconds,second_seconds
    real(real64) :: mean_insert_probes,mean_hit_probes

    failures=0
    call cpu_time(t0)
    do i=1,N
      call make_raw(i,raw)
      call initialize_b110_default_mvg_parameters(parameters,raw)
      call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
      key=make_b110_adaptive_hydraulic_key(parameters,'AHL32',1,1)
      call registry%get_or_build(key,parameters,provider,table,hit,ok)
      if(.not.ok .or. hit) failures=failures+1
    end do
    call cpu_time(t1)
    first_seconds=t1-t0
    call registry%stats(builds1,hits1,misses1,entries1)
    call registry%probe_stats(probes1,max_probes1)
    mean_insert_probes=real(probes1,real64)/real(N,real64)

    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL32_STAGE1','FAILURES=',failures,'BUILDS=',builds1,'HITS=',hits1, &
         'MISSES=',misses1,'ENTRIES=',entries1
    write(*,'(A,1X,A,F10.4,1X,A,I0)') &
         'AHL32_STAGE1_PROBES','MEAN=',mean_insert_probes,'MAX=',max_probes1

    call require(failures==0,'stage1 unique request behavior')
    call require(builds1==N .and. hits1==0 .and. misses1==N .and. entries1==N,'stage1 accounting')

    failures=0
    call cpu_time(t0)
    do i=1,N
      call make_raw(i,raw)
      call initialize_b110_default_mvg_parameters(parameters,raw)
      call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
      key=make_b110_adaptive_hydraulic_key(parameters,'AHL32',1,1)
      call registry%get_or_build(key,parameters,provider,table,hit,ok)
      if(.not.ok .or. .not.hit) failures=failures+1
    end do
    call cpu_time(t1)
    second_seconds=t1-t0
    call registry%stats(builds2,hits2,misses2,entries2)
    call registry%probe_stats(probes2,max_probes2)
    mean_hit_probes=real(probes2-probes1,real64)/real(N,real64)

    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL32_STAGE2','FAILURES=',failures,'BUILDS=',builds2,'HITS=',hits2, &
         'MISSES=',misses2,'ENTRIES=',entries2
    write(*,'(A,1X,A,ES18.10,1X,A,ES18.10,1X,A,F10.4,1X,A,I0)') &
         'AHL32_PERF','FIRST_PASS_SEC_PER_REQUEST=',first_seconds/real(N,real64), &
         'SECOND_PASS_SEC_PER_REQUEST=',second_seconds/real(N,real64), &
         'MEAN_SECOND_PASS_PROBES=',mean_hit_probes,'MAX_PROBES=',max_probes2

    call require(failures==0,'stage2 exact-key reuse')
    call require(builds2-builds1==0,'stage2 no new builds')
    call require(misses2-misses1==0,'stage2 no new misses')
    call require(hits2-hits1==N,'stage2 ten thousand hits')
    call require(entries2==N,'stage2 stable entries')
    call require(mean_hit_probes<=4.0_real64,'stage2 mean probe gate')
    call require(max_probes2<=128,'stage2 maximum probe gate')
  end subroutine stage12_ten_thousand

  subroutine collision_safety()
    type(b110_adaptive_hydraulic_cache_t) :: registry
    type(b110_default_mvg_parameters_t) :: pa,pb
    type(b110_default_mvg_provider_t) :: prova,provb
    type(b110_adaptive_hydraulic_table_t) :: ta,tb,ta2
    type(b110_adaptive_hydraulic_cache_key_t) :: ka,kb
    real(real64) :: ra(24,1),rb(24,1)
    logical :: hit,ok
    integer :: builds,hits,misses,entries

    call make_raw(777,ra)
    call make_raw(778,rb)
    call initialize_b110_default_mvg_parameters(pa,ra)
    call initialize_b110_default_mvg_parameters(pb,rb)
    call bind_b110_default_mvg_provider(prova,pa,0.25_real64)
    call bind_b110_default_mvg_provider(provb,pb,0.25_real64)
    ka=make_b110_adaptive_hydraulic_key(pa,'AHL32COLL',1,1)
    kb=make_b110_adaptive_hydraulic_key(pb,'AHL32COLL',1,1)
    kb%fingerprint=ka%fingerprint

    call registry%get_or_build(ka,pa,prova,ta,hit,ok)
    call require(ok .and. .not.hit,'collision first key')
    call registry%get_or_build(kb,pb,provb,tb,hit,ok)
    call require(ok .and. .not.hit,'collision distinct exact key')
    call registry%get_or_build(ka,pa,prova,ta2,hit,ok)
    call require(ok .and. hit,'collision exact-key retrieval')
    call registry%stats(builds,hits,misses,entries)
    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL32_COLLISION','BUILDS=',builds,'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries
    call require(builds==2 .and. hits==1 .and. misses==2 .and. entries==2,'collision accounting')
    call require(ta2%n==ta%n,'collision returned wrong table')
  end subroutine collision_safety

  subroutine stage3_capacity_plus_one()
    integer, parameter :: N=B110_AHL_MAX_CACHE+1
    type(b110_adaptive_hydraulic_cache_t) :: registry
    type(b110_default_mvg_parameters_t) :: parameters
    type(b110_default_mvg_provider_t) :: provider
    type(b110_adaptive_hydraulic_table_t) :: table
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: raw(24,1)
    logical :: hit,ok,last_ok,last_hit
    integer :: i,failures,builds,hits,misses,entries,max_before,max_after
    integer(int64) :: probes_before,probes_after

    failures=0;last_ok=.false.;last_hit=.false.
    probes_before=0_int64;probes_after=0_int64;max_before=0;max_after=0
    do i=1,N
      if(i==N) call registry%probe_stats(probes_before,max_before)
      call make_raw(20000+i,raw)
      call initialize_b110_default_mvg_parameters(parameters,raw)
      call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
      key=make_b110_adaptive_hydraulic_key(parameters,'AHL32CAP',1,1)
      call registry%get_or_build(key,parameters,provider,table,hit,ok)
      if(.not.ok)failures=failures+1
      if(i==N)then
        last_ok=ok;last_hit=hit
      end if
    end do
    call registry%stats(builds,hits,misses,entries)
    call registry%probe_stats(probes_after,max_after)
    write(*,'(A,1X,A,I0,1X,A,L1,1X,A,L1,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL32_STAGE3','FAILURES=',failures,'LAST_OK=',last_ok,'LAST_HIT=',last_hit, &
         'BUILDS=',builds,'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries
    write(*,'(A,1X,A,I0,1X,A,I0)') 'AHL32_STAGE3_FULL_MISS', &
         'PROBES=',int(probes_after-probes_before),'MAX_PROBES=',max_after
    call require(failures==0,'capacity plus one correctness')
    call require(last_ok .and. .not.last_hit,'capacity plus one uncached fallback')
    call require(entries==B110_AHL_MAX_CACHE,'registry remains bounded')
    call require(builds==N .and. misses==N,'capacity plus one accounting')
  end subroutine stage3_capacity_plus_one

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(24,1)
    real(real64)::n,scale
    a=0.0_real64
    ! Tiny deterministic Ksat perturbation is sufficient to create exact-key
    ! uniqueness without pushing the constitutive family outside its qualified
    ! default-MvG envelope.
    scale=1.0_real64+1.0e-7_real64*real(idx,real64)
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
      write(*,'(A,1X,A)')'AHL32_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl32_registry
