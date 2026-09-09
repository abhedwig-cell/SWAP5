module mod_fsi23_mms_providers
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fsi23_linear_hydraulics_provider_t
     real(real64) :: equilibrium_head = -100.0_real64
     real(real64) :: theta_equilibrium = 0.30_real64
     real(real64) :: capacity = 0.001_real64
     real(real64) :: conductivity = 1.0_real64
   contains
     procedure :: evaluate => fsi23_linear_hydraulics_evaluate
  end type fsi23_linear_hydraulics_provider_t

  type, extends(source_sink_provider_t), public :: fsi23_linear_decay_sink_provider_t
     integer :: active_nodes = 0
     real(real64) :: equilibrium_head = -100.0_real64
     real(real64) :: capacity = 0.001_real64
     real(real64) :: lambda = 8.0_real64
     real(real64), allocatable :: dz(:)
   contains
     procedure :: evaluate => fsi23_linear_decay_sink_evaluate
  end type fsi23_linear_decay_sink_provider_t

  public :: initialize_fsi23_linear_decay_sink

contains

  subroutine fsi23_linear_hydraulics_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi23_linear_hydraulics_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)

    if (.not. ieee_is_finite(self%equilibrium_head) .or. .not. ieee_is_finite(self%theta_equilibrium) .or. &
        .not. ieee_is_finite(self%capacity) .or. self%capacity <= 0.0_real64 .or. &
        .not. ieee_is_finite(self%conductivity) .or. self%conductivity <= 0.0_real64) then
       error stop 'F-SI23 MMS hydraulics: invalid provider parameters'
    end if
    if (size(water_content) /= size(pressure_head) .or. size(conductivity) /= size(pressure_head) .or. &
        size(capacity) /= size(pressure_head) .or. size(dconductivity_dhead) /= size(pressure_head)) then
       error stop 'F-SI23 MMS hydraulics: shape mismatch'
    end if
    water_content = self%theta_equilibrium + self%capacity * (pressure_head - self%equilibrium_head)
    conductivity = self%conductivity
    capacity = self%capacity
    dconductivity_dhead = 0.0_real64
  end subroutine fsi23_linear_hydraulics_evaluate

  subroutine initialize_fsi23_linear_decay_sink(provider, dz, equilibrium_head, capacity, lambda)
    type(fsi23_linear_decay_sink_provider_t), intent(out) :: provider
    real(real64), intent(in) :: dz(:)
    real(real64), intent(in) :: equilibrium_head, capacity, lambda

    if (size(dz) <= 0 .or. any(.not. ieee_is_finite(dz)) .or. any(dz <= 0.0_real64)) &
         error stop 'F-SI23 MMS sink: invalid dz'
    if (.not. ieee_is_finite(equilibrium_head) .or. .not. ieee_is_finite(capacity) .or. capacity <= 0.0_real64 .or. &
        .not. ieee_is_finite(lambda) .or. lambda <= 0.0_real64) &
         error stop 'F-SI23 MMS sink: invalid parameters'

    provider%active_nodes = size(dz)
    provider%equilibrium_head = equilibrium_head
    provider%capacity = capacity
    provider%lambda = lambda
    allocate(provider%dz(provider%active_nodes))
    provider%dz = dz
  end subroutine initialize_fsi23_linear_decay_sink

  subroutine fsi23_linear_decay_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(fsi23_linear_decay_sink_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)

    if (self%active_nodes <= 0 .or. .not. allocated(self%dz)) &
         error stop 'F-SI23 MMS sink: provider not initialized'
    if (size(pressure_head) /= self%active_nodes .or. size(water_content) /= self%active_nodes .or. &
        size(source) /= self%active_nodes .or. size(sink) /= self%active_nodes) &
         error stop 'F-SI23 MMS sink: shape mismatch'
    if (any(.not. ieee_is_finite(pressure_head)) .or. any(.not. ieee_is_finite(water_content))) &
         error stop 'F-SI23 MMS sink: nonfinite state'

    source = 0.0_real64
    sink = self%lambda * self%capacity * self%dz * (pressure_head - self%equilibrium_head)
  end subroutine fsi23_linear_decay_sink_evaluate

end module mod_fsi23_mms_providers
