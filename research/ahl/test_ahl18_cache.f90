program test_ahl18_cache
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_ahl17_runtime_builder, only: ahl17_table_t
  use mod_ahl18_cache, only: ahl18_cache_t, ahl18_cache_key_t, make_ahl18_key
  implicit none

  integer, parameter :: NREPEAT=10000
  type(b110_default_mvg_parameters_t),target :: hp,hp2
  type(b110_default_mvg_provider_t) :: provider,provider2
  type(ahl18_cache_t) :: cache
  type(ahl18_cache_key_t) :: key,key2,key_policy
  type(ahl17_table_t) :: table,table_ref
  real(real64) :: cof(24,1),cof2(24,1),t0,t1,hit_elapsed
  logical :: hit,ok
  integer :: i,builds,hits,misses,entries

  call configure(cof)
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(provider,hp,0.25_real64)
  key=make_ahl18_key(hp,'B110_MVG',1,1)

  call cache%get_or_build(key,hp,provider,table_ref,hit,ok)
  call require(ok,'first build succeeds')
  call require(.not.hit,'first request is miss')

  call cpu_time(t0)
  do i=1,NREPEAT
    call cache%get_or_build(key,hp,provider,table,hit,ok)
    call require(ok,'repeat succeeds')
    call require(hit,'repeat is hit')
    call require(table%n==table_ref%n,'same support count')
    call require(all(table%x==table_ref%x),'x immutable')
    call require(all(table%z==table_ref%z),'z immutable')
    call require(all(table%dzdx==table_ref%dzdx),'dzdx immutable')
    call require(all(table%logk==table_ref%logk),'logk immutable')
  end do
  call cpu_time(t1);hit_elapsed=(t1-t0)/real(NREPEAT,real64)

  cof2=cof
  cof2(4,1)=nearest(cof2(4,1),1.0_real64)
  call initialize_b110_default_mvg_parameters(hp2,cof2)
  call bind_b110_default_mvg_provider(provider2,hp2,0.25_real64)
  key2=make_ahl18_key(hp2,'B110_MVG',1,1)
  call require(.not.all(key2%coeff==key%coeff),'perturbed coefficient differs')
  call cache%get_or_build(key2,hp2,provider2,table,hit,ok)
  call require(ok,'perturbed parameter builds')
  call require(.not.hit,'perturbed parameter misses')

  key_policy=make_ahl18_key(hp,'B110_MVG',2,1)
  call cache%get_or_build(key_policy,hp,provider,table,hit,ok)
  call require(ok,'changed policy builds')
  call require(.not.hit,'changed policy misses')

  call cache%stats(builds,hits,misses,entries)
  call require(builds==3,'three builds expected')
  call require(hits==NREPEAT,'repeat hit count')
  call require(misses==3,'three misses expected')
  call require(entries==3,'three entries expected')

  write(*,'(A,1X,A,Z16.16)') 'AHL18_FINGERPRINT_BASE','0x',key%fingerprint
  write(*,'(A,1X,A,ES16.8)') 'AHL18_HIT_TIME','SECONDS=',hit_elapsed
  write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') 'AHL18_STATS','BUILDS=',builds,'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries
  write(*,'(A)') 'AHL18_CACHE=PASS'

contains

  subroutine configure(c)
    real(real64),intent(out)::c(24,1)
    real(real64),parameter::tr=0.02_real64,ts=0.427494_real64,a=0.021659_real64,n=1.734737_real64,ks=31.225016_real64,lam=0.98087_real64
    c=0.0_real64
    c(1,1)=tr;c(2,1)=ts;c(3,1)=ks;c(4,1)=a;c(5,1)=lam;c(6,1)=n
    c(7,1)=1.0_real64-1.0_real64/n;c(8,1)=a;c(9,1)=0.0_real64
    c(10,1)=ks;c(11,1)=0.999_real64;c(12,1)=0.99_real64*ks
    c(22,1)=-1.0e6_real64;c(23,1)=1.0e-12_real64
  end subroutine configure

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'AHL18_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl18_cache
