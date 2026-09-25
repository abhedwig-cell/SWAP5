program test_fahl27_cache_capacity
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_mvg_provider, only: b110_adaptive_mvg_provider_t, bind_b110_adaptive_mvg_provider, &
       b110_adaptive_mvg_cache_stats
  implicit none

  integer, parameter :: n=40
  real(real64), parameter :: dt=0.25_real64
  real(real64) :: input(24,n), ksat
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_adaptive_mvg_provider_t) :: adaptive
  logical :: ok,hit1,hit2
  integer :: i,builds,hits,misses,entries

  input=0.0_real64
  do i=1,n
    ksat=1.0_real64+0.1_real64*real(i,real64)
    input(1,i)=0.032_real64
    input(2,i)=0.423_real64
    input(3,i)=ksat
    input(4,i)=0.0135_real64
    input(5,i)=0.365_real64
    input(6,i)=1.455_real64
    input(7,i)=1.0_real64-1.0_real64/input(6,i)
    input(8,i)=input(4,i)
    input(9,i)=0.0_real64
    input(10,i)=ksat
    input(11,i)=0.999_real64
    input(12,i)=0.99_real64*ksat
    input(22,i)=-1.0e6_real64
    input(23,i)=1.0e-12_real64
  end do

  call initialize_b110_default_mvg_parameters(hp,input)

  call bind_b110_adaptive_mvg_provider(adaptive,hp,dt,ok,hit1)
  call require(ok,'first 40-material bind')
  call require(.not.hit1,'first 40-material bind contains builds')
  call require(adaptive%unique_material_count()==n,'40 unique material mappings')
  call b110_adaptive_mvg_cache_stats(adaptive,builds,hits,misses,entries)
  call require(builds==n .and. misses==n .and. entries==n,'dynamic cache holds 40 unique entries')

  call bind_b110_adaptive_mvg_provider(adaptive,hp,dt,ok,hit2)
  call require(ok,'second 40-material bind')
  call require(hit2,'second 40-material bind all hits')
  call b110_adaptive_mvg_cache_stats(adaptive,builds,hits,misses,entries)
  call require(builds==n,'no additional builds on second bind')
  call require(hits==n,'40 hits on second bind')
  call require(misses==n .and. entries==n,'cache remains exact and complete')

  write(*,'(A,I0)') 'FAHL27_CACHE_CAPACITY_ENTRIES=',entries
  write(*,'(A,I0)') 'FAHL27_CACHE_CAPACITY_HITS=',hits
  write(*,'(A)') 'FAHL27_DYNAMIC_CACHE_40=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FAHL27_CACHE_CAPACITY_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fahl27_cache_capacity
