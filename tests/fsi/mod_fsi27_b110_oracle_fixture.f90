module mod_fsi27_b110_oracle_fixture
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       root_sink_provider_t, top_boundary_provider_t, soil_water_boundary_conditions_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fsi27_oracle_constitutive_t
     integer :: marker = 0
   contains
     procedure :: evaluate => constitutive_evaluate
  end type fsi27_oracle_constitutive_t

  type, extends(source_sink_provider_t), public :: fsi27_oracle_source_sink_t
     integer :: marker = 0
   contains
     procedure :: evaluate => source_sink_evaluate
  end type fsi27_oracle_source_sink_t

  type, extends(root_sink_provider_t), public :: fsi27_oracle_root_sink_t
     integer :: marker = 0
   contains
     procedure :: evaluate => root_sink_evaluate
  end type fsi27_oracle_root_sink_t

  type, extends(top_boundary_provider_t), public :: fsi27_oracle_top_t
     integer :: marker = 0
   contains
     procedure :: evaluate => top_evaluate
  end type fsi27_oracle_top_t

contains

  subroutine constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi27_oracle_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (self%marker /= 0) error stop 'invalid F-SI27 oracle constitutive marker'
    water_content = 0.30_real64 + 0.001_real64*(pressure_head + 75.0_real64)
    conductivity = 1.0_real64
    capacity = 0.001_real64
    dconductivity_dhead = 0.0_real64
  end subroutine constitutive_evaluate

  subroutine source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(fsi27_oracle_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    if (self%marker /= 0 .or. size(pressure_head) /= size(water_content)) error stop 'invalid F-SI27 oracle source fixture'
    source = 0.0_real64
    sink = 0.0_real64
  end subroutine source_sink_evaluate

  subroutine root_sink_evaluate(self, pressure_head, water_content, root_sink)
    class(fsi27_oracle_root_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: root_sink(:)
    if (self%marker /= 0 .or. size(pressure_head) /= size(water_content)) error stop 'invalid F-SI27 oracle root fixture'
    root_sink = 0.0_real64
  end subroutine root_sink_evaluate

  subroutine top_evaluate(self, pressure_head_top, water_content_top, requested, actual_top_flux, surface_head, runoff_flux)
    class(fsi27_oracle_top_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    if (self%marker /= 0 .or. pressure_head_top > huge(pressure_head_top) .or. &
        water_content_top > huge(water_content_top)) error stop 'invalid F-SI27 oracle top fixture'
    actual_top_flux = requested%top_flux
    surface_head = 0.0_real64
    runoff_flux = 0.0_real64
  end subroutine top_evaluate

end module mod_fsi27_b110_oracle_fixture