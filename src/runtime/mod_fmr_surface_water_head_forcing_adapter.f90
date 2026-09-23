module mod_fmr_surface_water_head_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  implicit none
  private

  integer, parameter, public :: FMR_SW_HEAD_FORCING_OK = 0
  integer, parameter, public :: FMR_SW_HEAD_FORCING_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_SW_HEAD_FORCING_PROFILE_NOT_ADMITTED = 2
  integer, parameter, public :: FMR_SW_HEAD_FORCING_COMPETING_DRAINAGE_INPUT = 3
  integer, parameter, public :: FMR_SW_HEAD_FORCING_NONFINITE_HEAD = 4

  type, public :: fmr_surface_water_head_forcing_materializer_t
    private
    logical :: initialized = .false.
    integer :: nlevels = 0
    type(fmr_b110_physical_forcing_t), allocatable :: base_forcing
  contains
    procedure, public :: initialize => surface_water_materializer_initialize
    procedure, public :: materialize => surface_water_materialize
    procedure, public :: ready => surface_water_materializer_ready
    procedure, public :: level_count => surface_water_materializer_level_count
  end type fmr_surface_water_head_forcing_materializer_t

contains

  subroutine surface_water_materializer_initialize(self, base_forcing, parameters, status)
    class(fmr_surface_water_head_forcing_materializer_t), intent(inout) :: self
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    integer, intent(out) :: status

    self%initialized = .false.
    self%nlevels = 0
    if (allocated(self%base_forcing)) deallocate(self%base_forcing)

    status = FMR_SW_HEAD_FORCING_PROFILE_NOT_ADMITTED
    if (.not. parameters%drainage_response_active) return
    if (.not. allocated(parameters%drainage_response_levels)) return
    if (size(parameters%drainage_response_levels) /= 1) return
    if (any(parameters%drainage_response_levels%variant /= FMR_DRAIN_VARIANT_EXTENDED_SIGNED)) return

    status = FMR_SW_HEAD_FORCING_COMPETING_DRAINAGE_INPUT
    if (allocated(base_forcing%drainage_flux_by_level)) return
    if (allocated(base_forcing%drainage_response_controls)) return

    status = FMR_SW_HEAD_FORCING_INVALID_REQUEST
    if (.not. allocated(base_forcing%subsurface_irrigation_source)) return
    if (.not. allocated(base_forcing%root_extraction_sink)) return
    if (size(base_forcing%subsurface_irrigation_source) /= parameters%active_nodes) return
    if (size(base_forcing%root_extraction_sink) /= parameters%active_nodes) return
    if (any(.not. ieee_is_finite(base_forcing%subsurface_irrigation_source))) return
    if (any(.not. ieee_is_finite(base_forcing%root_extraction_sink))) return

    allocate(self%base_forcing)
    self%base_forcing = base_forcing
    self%nlevels = size(parameters%drainage_response_levels)
    self%initialized = .true.
    status = FMR_SW_HEAD_FORCING_OK
  end subroutine surface_water_materializer_initialize

  subroutine surface_water_materialize(self, resolved_heads_cm, forcing, status)
    class(fmr_surface_water_head_forcing_materializer_t), intent(in) :: self
    real(real64), intent(in) :: resolved_heads_cm(:)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status
    integer :: i

    forcing = fmr_b110_physical_forcing_t()
    status = FMR_SW_HEAD_FORCING_INVALID_REQUEST
    if (.not. self%ready()) return
    if (size(resolved_heads_cm) /= self%nlevels) return
    if (any(.not. ieee_is_finite(resolved_heads_cm))) then
      status = FMR_SW_HEAD_FORCING_NONFINITE_HEAD
      return
    end if

    forcing = self%base_forcing
    if (allocated(forcing%drainage_flux_by_level)) deallocate(forcing%drainage_flux_by_level)
    if (allocated(forcing%drainage_response_controls)) deallocate(forcing%drainage_response_controls)
    allocate(forcing%drainage_response_controls(self%nlevels))
    do i = 1, self%nlevels
      forcing%drainage_response_controls(i)%drain_head_supplied = .false.
      forcing%drainage_response_controls(i)%resolved_surface_water_head_supplied = .true.
      forcing%drainage_response_controls(i)%resolved_surface_water_head_cm = resolved_heads_cm(i)
    end do
    status = FMR_SW_HEAD_FORCING_OK
  end subroutine surface_water_materialize

  logical function surface_water_materializer_ready(self) result(ready)
    class(fmr_surface_water_head_forcing_materializer_t), intent(in) :: self
    ready = self%initialized .and. self%nlevels > 0 .and. allocated(self%base_forcing)
  end function surface_water_materializer_ready

  integer function surface_water_materializer_level_count(self) result(n)
    class(fmr_surface_water_head_forcing_materializer_t), intent(in) :: self
    n = 0
    if (self%ready()) n = self%nlevels
  end function surface_water_materializer_level_count

end module mod_fmr_surface_water_head_forcing_adapter
