program test_ahl29_cache_capacity
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, &
       b110_adaptive_hydraulic_cache_key_t, make_b110_adaptive_hydraulic_key
  implicit none

  type(b110_adaptive_hydraulic_cache_t) :: cache
  type(b110_default_mvg_parameters_t) :: parameters
  type(b110_default_mvg_provider_t) :: provider
  type(b110_adaptive_hydraulic_table_t) :: table
  type(b110_adaptive_hydraulic_cache_key_t) :: key
  real(real64) :: raw(24,1)
  logical :: hit,ok
  integer :: i,success,first_failure,builds,hits,misses,entries

  success=0;first_failure=0
  do i=1,40
    call make_raw(i,raw)
    call initialize_b110_default_mvg_parameters(parameters,raw)
    call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
    key=make_b110_adaptive_hydraulic_key(parameters,'AHL29',1,1)
    call cache%get_or_build(key,parameters,provider,table,hit,ok)
    if(ok) then
      success=success+1
    else if(first_failure==0) then
      first_failure=i
    end if
  end do
  call cache%stats(builds,hits,misses,entries)
  write(*,'(A,1X,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
       'AHL29_STAGE1 SUCCESS=',success,'FIRST_FAILURE=',first_failure,'BUILDS=',builds, &
       'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries

  call require(success==32,'expected current bounded-cache success count')
  call require(first_failure==33,'expected current first failure at unique key 33')
  call require(entries==32,'expected cache full at 32 entries')
  write(*,'(A)') 'AHL29_STAGE1_CURRENT_BEHAVIOR_CONFIRMED=PASS'

contains

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
    if(.not.cond) then
      write(*,'(A,1X,A)') 'AHL29_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl29_cache_capacity
