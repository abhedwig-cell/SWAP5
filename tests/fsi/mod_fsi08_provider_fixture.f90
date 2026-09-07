module mod_fsi08_provider_fixture
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fsi08_constitutive_provider_t
     real(real64) :: water_content_value = 0.30_real64
     real(real64) :: conductivity_value = 1.0_real64
     real(real64) :: capacity_value = 0.0_real64
     real(real64) :: dconductivity_dhead_value = 0.0_real64
   contains
     procedure :: evaluate => fsi08_constitutive_evaluate
  end type fsi08_constitutive_provider_t

  type, extends(source_sink_provider_t), public :: fsi08_source_sink_provider_t
     real(real64) :: source_value = 0.0_real64
     real(real64) :: sink_value = 0.0_real64
   contains
     procedure :: evaluate => fsi08_source_sink_evaluate
  end type fsi08_source_sink_provider_t

contains

  subroutine fsi08_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi08_constitutive_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (size(pressure_head) <= 0) error stop 'F-SI08 constitutive: empty pressure-head vector'
    water_content = self%water_content_value
    conductivity = self%conductivity_value
    capacity = self%capacity_value
    dconductivity_dhead = self%dconductivity_dhead_value
  end subroutine fsi08_constitutive_evaluate

  subroutine fsi08_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(fsi08_source_sink_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    if (size(pressure_head) <= 0 .or. size(water_content) /= size(pressure_head)) &
      error stop 'F-SI08 source/sink: invalid state vector'
    source = self%source_value
    sink = self%sink_value
  end subroutine fsi08_source_sink_evaluate

end module mod_fsi08_provider_fixture
