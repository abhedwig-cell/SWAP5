program test_ahl29_postrepair_cache_semantics
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, &
       b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key
  implicit none

  call stage1_over_capacity()
  call stage2_amortization()
  write(*,'(A)') 'AHL29_POSTREPAIR_ALL=PASS'

contains

  subroutine stage1_over_capacity()
    type(b110_adaptive_hydraulic_cache_t) :: cache
    type(b110_default_mvg_parameters_t) :: parameters
    type(b110_default_mvg_provider_t) :: provider
    type(b110_adaptive_hydraulic_table_t) :: table
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: raw(24,1)
    logical :: hit,ok
    integer :: i,failures,builds,hits,misses,entries

    failures=0
    do i=1,40
      call make_raw(i,raw)
      call initialize_b110_default_mvg_parameters(parameters,raw)
      call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
      key=make_b110_adaptive_hydraulic_key(parameters,'AHL29',1,1)
      call cache%get_or_build(key,parameters,provider,table,hit,ok)
      if(.not.ok)failures=failures+1
      if(ok .and. table%n<2)failures=failures+1
    end do
    call cache%stats(builds,hits,misses,entries)
    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL29_STAGE1_POSTREPAIR','FAILURES=',failures,'BUILDS=',builds,'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries
    call require(failures==0,'over-capacity requests must remain correct')
    call require(entries==32,'bounded cache must remain bounded at 32')
  end subroutine stage1_over_capacity

  subroutine stage2_amortization()
    type(b110_adaptive_hydraulic_cache_t) :: cache
    type(b110_default_mvg_parameters_t) :: parameters
    type(b110_default_mvg_provider_t) :: provider
    type(b110_adaptive_hydraulic_table_t) :: table
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: raw(24,1)
    logical :: hit,ok
    integer :: q,idx,failures,builds,hits,misses,entries

    failures=0
    do q=1,10000
      idx=1+mod(q-1,16)
      call make_raw(idx,raw)
      call initialize_b110_default_mvg_parameters(parameters,raw)
      call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
      key=make_b110_adaptive_hydraulic_key(parameters,'AHL29',1,1)
      call cache%get_or_build(key,parameters,provider,table,hit,ok)
      if(.not.ok)failures=failures+1
    end do
    call cache%stats(builds,hits,misses,entries)
    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL29_STAGE2_AMORTIZATION','FAILURES=',failures,'BUILDS=',builds,'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries
    call require(failures==0,'amortization workload correctness')
    call require(builds==16,'exactly one cached build per unique key')
    call require(hits>=9984,'expected repeated exact-key hits')
    call require(entries==16,'expected 16 cached entries')
  end subroutine stage2_amortization

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
      write(*,'(A,1X,A)')'AHL29_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl29_postrepair_cache_semantics
