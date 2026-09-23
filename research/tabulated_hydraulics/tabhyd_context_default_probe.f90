module mod_tabhyd_context_default_probe
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  type, extends(constitutive_hydraulics_provider_t) :: dummy_constitutive_provider_t
  contains
    procedure :: evaluate => dummy_evaluate
  end type dummy_constitutive_provider_t
contains
  subroutine dummy_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(dummy_constitutive_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    water_content=0.0_real64
    conductivity=1.0_real64
    capacity=1.0_real64
    dconductivity_dhead=0.0_real64
  end subroutine dummy_evaluate
end module mod_tabhyd_context_default_probe

program tabhyd_context_default_probe
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tabhyd_context_default_probe, only: dummy_constitutive_provider_t
  implicit none
  type(dummy_constitutive_provider_t) :: provider
  if (provider%context_compatible(0.04_real64)) error stop 'default capability did not fail closed'
  write(*,'(a)') 'TABHYD_CTX01_DEFAULT_FAIL_CLOSED=PASS'
end program tabhyd_context_default_probe
