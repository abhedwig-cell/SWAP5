module mod_b110_root_sink_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: root_sink_provider_t
  implicit none
  private

  type, extends(root_sink_provider_t), public :: b110_root_sink_provider_t
     integer :: active_nodes = 0
     real(real64), pointer :: root_extraction_sink(:) => null()
   contains
     procedure :: evaluate => b110_root_sink_evaluate
  end type b110_root_sink_provider_t

  public :: bind_b110_root_sink_provider

contains

  subroutine bind_b110_root_sink_provider(provider, root_extraction_sink)
    type(b110_root_sink_provider_t), intent(out) :: provider
    real(real64), target, intent(in) :: root_extraction_sink(:)

    if (size(root_extraction_sink) <= 0) error stop 'B1.10 root-sink provider: active_nodes must be positive'
    if (any(.not. ieee_is_finite(root_extraction_sink))) &
         error stop 'B1.10 root-sink provider: root sink must be finite'

    provider%active_nodes = size(root_extraction_sink)
    provider%root_extraction_sink => root_extraction_sink
  end subroutine bind_b110_root_sink_provider

  subroutine b110_root_sink_evaluate(self, pressure_head, water_content, root_sink)
    class(b110_root_sink_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: root_sink(:)
    integer :: n

    n = self%active_nodes
    if (n <= 0) error stop 'B1.10 root-sink provider: provider not bound'
    if (.not. associated(self%root_extraction_sink)) error stop 'B1.10 root-sink provider: root sink not bound'
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(root_sink) /= n) &
         error stop 'B1.10 root-sink provider: shape mismatch'
    if (any(.not. ieee_is_finite(self%root_extraction_sink))) &
         error stop 'B1.10 root-sink provider: root sink became non-finite'

    root_sink = self%root_extraction_sink
  end subroutine b110_root_sink_evaluate

end module mod_b110_root_sink_provider
