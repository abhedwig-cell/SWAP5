program test_ahl30_over_capacity_reuse
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, &
       b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key
  implicit none

  integer, parameter :: NUNIQUE=64, NROUND=10000, NGROUP=128
  type(b110_default_mvg_parameters_t), target :: parameters(NUNIQUE)
  type(b110_default_mvg_provider_t) :: provider(NUNIQUE)
  type(b110_adaptive_hydraulic_cache_key_t) :: key(NUNIQUE)
  real(real64) :: raw(24,1)
  integer :: i

  do i=1,NUNIQUE
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(parameters(i),raw)
    call bind_b110_default_mvg_provider(provider(i),parameters(i),0.25_real64)
    key(i)=make_b110_adaptive_hydraulic_key(parameters(i),'AHL30',1,1)
  end do

  call run_round_robin(parameters,provider,key)
  call run_grouped(parameters,provider,key)
  write(*,'(A)') 'AHL30_CHARACTERIZATION=PASS'

contains

  subroutine run_round_robin(p,prov,k)
    type(b110_default_mvg_parameters_t),intent(in)::p(:)
    type(b110_default_mvg_provider_t),intent(in)::prov(:)
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::k(:)
    type(b110_adaptive_hydraulic_cache_t)::cache
    type(b110_adaptive_hydraulic_table_t)::table
    integer::q,idx,builds,hits,misses,entries,failures
    real(real64)::a,b
    logical::was_hit,ok

    failures=0
    call cpu_time(a)
    do q=1,NROUND
      idx=1+mod(q-1,NUNIQUE)
      call cache%get_or_build(k(idx),p(idx),prov(idx),table,was_hit,ok)
      if(.not.ok)failures=failures+1
    end do
    call cpu_time(b)
    call cache%stats(builds,hits,misses,entries)
    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,ES18.10)') &
         'AHL30_ROUND_ROBIN_64','FAILURES=',failures,'BUILDS=',builds,'HITS=',hits, &
         'MISSES=',misses,'ENTRIES=',entries,'SEC_PER_REQUEST=',(b-a)/real(NROUND,real64)
    call require(failures==0,'round-robin correctness')
    call require(entries==32,'round-robin bounded cache')
  end subroutine run_round_robin

  subroutine run_grouped(p,prov,k)
    type(b110_default_mvg_parameters_t),intent(in)::p(:)
    type(b110_default_mvg_provider_t),intent(in)::prov(:)
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::k(:)
    type(b110_adaptive_hydraulic_cache_t)::cache
    type(b110_adaptive_hydraulic_table_t)::table
    integer::idx,q,nreq,builds,hits,misses,entries,failures
    real(real64)::a,b
    logical::was_hit,ok

    failures=0;nreq=NUNIQUE*NGROUP
    call cpu_time(a)
    do idx=1,NUNIQUE
      do q=1,NGROUP
        call cache%get_or_build(k(idx),p(idx),prov(idx),table,was_hit,ok)
        if(.not.ok)failures=failures+1
      end do
    end do
    call cpu_time(b)
    call cache%stats(builds,hits,misses,entries)
    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,ES18.10)') &
         'AHL30_GROUPED_64','FAILURES=',failures,'BUILDS=',builds,'HITS=',hits, &
         'MISSES=',misses,'ENTRIES=',entries,'SEC_PER_REQUEST=',(b-a)/real(nreq,real64)
    call require(failures==0,'grouped correctness')
    call require(entries==32,'grouped bounded cache')
  end subroutine run_grouped

  subroutine make_raw(idx,a)
    integer,intent(in)::idx
    real(real64),intent(out)::a(24,1)
    real(real64)::n
    a=0.0_real64
    n=1.35_real64+0.004_real64*real(idx,real64)
    a(1,1)=0.02_real64
    a(2,1)=0.43_real64
    a(3,1)=5.0_real64+0.1_real64*real(idx,real64)
    a(4,1)=0.012_real64+2.0e-5_real64*real(idx,real64)
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
      write(*,'(A,1X,A)')'AHL30_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl30_over_capacity_reuse
