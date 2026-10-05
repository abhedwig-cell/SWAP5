module mod_fmr_irrigation_source_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  implicit none
  private

  integer, parameter, public :: FMR_IRR_SOURCE_OK = 0
  integer, parameter, public :: FMR_IRR_SOURCE_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_IRR_SOURCE_INACTIVE = 2
  integer, parameter, public :: FMR_IRR_SOURCE_UNSUPPORTED_APPLICATION = 3
  integer, parameter, public :: FMR_IRR_SOURCE_INVALID_SHAPE = 4
  integer, parameter, public :: FMR_IRR_SOURCE_INVALID_RATE = 5

  type, public :: fmr_irrigation_source_diagnostics_t
    integer :: status = FMR_IRR_SOURCE_OK
    logical :: upstream_accepted = .false.
    logical :: source_added = .false.
    real(real64) :: added_depth_cm_per_day = 0.0_real64
  end type fmr_irrigation_source_diagnostics_t

  public :: fmr_bind_irrigation_to_subsurface_source

contains

  pure subroutine fmr_bind_irrigation_to_subsurface_source(base_source, flux, upstream, bound_source, diagnostics)
    real(real64), intent(in) :: base_source(:)
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: upstream
    real(real64), allocatable, intent(out) :: bound_source(:)
    type(fmr_irrigation_source_diagnostics_t), intent(out) :: diagnostics

    diagnostics = fmr_irrigation_source_diagnostics_t()
    if (upstream%status /= IRRIGATION_OK) then
      diagnostics%status = FMR_IRR_SOURCE_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_accepted = .true.
    if (.not. flux%applied) then
      diagnostics%status = FMR_IRR_SOURCE_INACTIVE
      return
    end if
    if (flux%application_type /= IRRIGATION_APPLICATION_SSDI) then
      diagnostics%status = FMR_IRR_SOURCE_UNSUPPORTED_APPLICATION
      return
    end if
    if (.not. allocated(flux%subsurface_source)) then
      diagnostics%status = FMR_IRR_SOURCE_INVALID_SHAPE
      return
    end if
    if (size(flux%subsurface_source) /= size(base_source)) then
      diagnostics%status = FMR_IRR_SOURCE_INVALID_SHAPE
      return
    end if
    if (any(.not. ieee_is_finite(base_source)) .or. any(base_source < 0.0_real64) .or. &
        any(.not. ieee_is_finite(flux%subsurface_source)) .or. &
        any(flux%subsurface_source < 0.0_real64)) then
      diagnostics%status = FMR_IRR_SOURCE_INVALID_RATE
      return
    end if

    allocate(bound_source(size(base_source)))
    bound_source = base_source + flux%subsurface_source
    diagnostics%added_depth_cm_per_day = sum(flux%subsurface_source)
    diagnostics%source_added = .true.
  end subroutine fmr_bind_irrigation_to_subsurface_source

end module mod_fmr_irrigation_source_binding
