module mod_b110_source_sink_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: source_sink_provider_t
  implicit none
  private

  type, extends(source_sink_provider_t), public :: b110_source_sink_provider_t
     integer :: active_nodes = 0
     integer :: drainage_levels = 0
     real(real64), pointer :: drainage_flux_by_level(:,:) => null()
     real(real64), pointer :: subsurface_irrigation_source(:) => null()
     real(real64), pointer :: root_extraction_sink(:) => null()
   contains
     procedure :: evaluate => b110_source_sink_evaluate
  end type b110_source_sink_provider_t

  public :: bind_b110_source_sink_provider

contains

  subroutine bind_b110_source_sink_provider(provider, drainage_flux_by_level, subsurface_irrigation_source, root_extraction_sink)
    type(b110_source_sink_provider_t), intent(out) :: provider
    real(real64), target, intent(in) :: drainage_flux_by_level(:,:)
    real(real64), target, intent(in) :: subsurface_irrigation_source(:)
    real(real64), target, intent(in) :: root_extraction_sink(:)
    integer :: n

    n = size(subsurface_irrigation_source)
    if (n <= 0) error stop 'B1.10 source/sink provider: active_nodes must be positive'
    if (size(root_extraction_sink) /= n) error stop 'B1.10 source/sink provider: root sink shape mismatch'
    if (size(drainage_flux_by_level,2) /= n) error stop 'B1.10 source/sink provider: drainage node shape mismatch'
    if (size(drainage_flux_by_level,1) <= 0) error stop 'B1.10 source/sink provider: drainage levels must be positive'
    if (any(.not. ieee_is_finite(root_extraction_sink))) &
         error stop 'B1.10 source/sink provider: root sink must be finite'
    if (any(abs(root_extraction_sink) > 0.0_real64)) &
         error stop 'B1.10 source/sink provider: active root extraction not admitted by F-SI10'

    provider%active_nodes = n
    provider%drainage_levels = size(drainage_flux_by_level,1)
    provider%drainage_flux_by_level => drainage_flux_by_level
    provider%subsurface_irrigation_source => subsurface_irrigation_source
    provider%root_extraction_sink => root_extraction_sink
  end subroutine bind_b110_source_sink_provider

  subroutine b110_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(b110_source_sink_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    integer :: level, n

    n = self%active_nodes
    if (n <= 0) error stop 'B1.10 source/sink provider: provider not bound'
    if (.not. associated(self%drainage_flux_by_level)) error stop 'B1.10 source/sink provider: drainage not bound'
    if (.not. associated(self%subsurface_irrigation_source)) error stop 'B1.10 source/sink provider: irrigation not bound'
    if (.not. associated(self%root_extraction_sink)) error stop 'B1.10 source/sink provider: root sink not bound'
    if (size(pressure_head) /= n .or. size(water_content) /= n) error stop 'B1.10 source/sink provider: state shape mismatch'
    if (size(source) /= n .or. size(sink) /= n) error stop 'B1.10 source/sink provider: output shape mismatch'
    if (size(self%drainage_flux_by_level,1) /= self%drainage_levels .or. &
        size(self%drainage_flux_by_level,2) /= n) error stop 'B1.10 source/sink provider: drainage binding changed shape'
    if (any(.not. ieee_is_finite(self%root_extraction_sink))) &
         error stop 'B1.10 source/sink provider: root sink became non-finite'
    if (any(abs(self%root_extraction_sink) > 0.0_real64)) &
         error stop 'B1.10 source/sink provider: active root extraction not admitted by F-SI10'

    source = self%subsurface_irrigation_source
    sink = 0.0_real64
    do level = 1, self%drainage_levels
       sink = sink + self%drainage_flux_by_level(level,:)
    end do
  end subroutine b110_source_sink_evaluate

end module mod_b110_source_sink_provider
