module mod_fmr_legacy_bottom_boundary_application_binding
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: FMR_LEGACY_BOTTOM_BINDING_OK = 0
  integer, parameter, public :: FMR_LEGACY_BOTTOM_BINDING_UNSUPPORTED_MODE = 1

  ! F-APP02 owns only the application-level semantic translation from the
  ! preserved legacy selector to an already-qualified typed bottom-boundary
  ! representation. It does not parse files and does not alter solver physics.
  type, public :: fmr_legacy_bottom_boundary_binding_t
    logical :: available = .false.
    integer :: legacy_swbotb = 0
    integer :: typed_bottom_mode = 0
    real(real64) :: typed_bottom_flux = 0.0_real64
  end type fmr_legacy_bottom_boundary_binding_t

  public :: fmr_resolve_legacy_bottom_boundary

contains

  subroutine fmr_resolve_legacy_bottom_boundary(legacy_swbotb, binding, status)
    integer, intent(in) :: legacy_swbotb
    type(fmr_legacy_bottom_boundary_binding_t), intent(out) :: binding
    integer, intent(out) :: status

    binding = fmr_legacy_bottom_boundary_binding_t()
    binding%legacy_swbotb = legacy_swbotb
    status = FMR_LEGACY_BOTTOM_BINDING_UNSUPPORTED_MODE

    ! SWAP 4.3.1 SWBOTB=6 is the zero-bottom-flux option. F-SI27 already
    ! qualifies current typed bottom_mode=2 as prescribed qbot [cm d-1].
    ! Therefore the exact semantic image is prescribed qbot = +0.0 cm d-1.
    if (legacy_swbotb == 6) then
      binding%available = .true.
      binding%typed_bottom_mode = 2
      binding%typed_bottom_flux = 0.0_real64
      status = FMR_LEGACY_BOTTOM_BINDING_OK
    end if
  end subroutine fmr_resolve_legacy_bottom_boundary

end module mod_fmr_legacy_bottom_boundary_application_binding
