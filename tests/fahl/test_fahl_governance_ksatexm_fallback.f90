program test_fahl_governance_ksatexm_fallback
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_profile_supported, &
       b110_adaptive_hydraulic_cache_stats
  implicit none

  integer, parameter :: n=2
  real(real64) :: cofgen(24,n)
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  logical :: ok, hit
  integer :: builds,hits,misses,entries,i

  cofgen=0.0_real64
  do i=1,n
    cofgen(1,i)=0.032_real64;cofgen(2,i)=0.423_real64;cofgen(3,i)=4.75_real64
    cofgen(4,i)=0.0135_real64;cofgen(5,i)=0.365_real64;cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i)
    cofgen(9,i)=0.0_real64;cofgen(10,i)=cofgen(3,i);cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i);cofgen(22,i)=-1.0e6_real64;cofgen(23,i)=1.0e-12_real64
  end do

  call initialize_b110_default_mvg_parameters(hp,cofgen,enable_ksatexm_extension=.true.)
  call require(.not.b110_adaptive_hydraulic_profile_supported(hp),'KSATEXM profile must be outside admitted AHL envelope')
  call bind_b110_adaptive_hydraulic_provider(adaptive,hp,0.25_real64,ok,hit)
  call require(.not.ok .and. .not.hit,'KSATEXM direct adaptive bind must fail closed')
  call b110_adaptive_hydraulic_cache_stats(builds,hits,misses,entries)
  call require(builds==0 .and. hits==0 .and. misses==0 .and. entries==0,'KSATEXM fallback must not touch AHL cache')

  write(*,'(A)') 'FAHL_KSATEXM_ANALYTICAL_FALLBACK=PASS'
contains
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL_KSATEXM_FALLBACK_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fahl_governance_ksatexm_fallback
