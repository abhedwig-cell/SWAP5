module mod_fmr_adaptive_hydraulic_policy
  implicit none
  private

  integer, parameter, public :: FMR_AHL_ROUTE_ANALYTICAL = 0
  integer, parameter, public :: FMR_AHL_ROUTE_ADAPTIVE_DEFAULT_MVG = 1

  public :: select_fmr_adaptive_hydraulic_route

contains

  pure integer function select_fmr_adaptive_hydraulic_route(bottom_mode, swkimpl, ksatexm_extension_active, &
       default_mvg_family) result(route)
    integer, intent(in) :: bottom_mode
    integer, intent(in) :: swkimpl
    logical, intent(in) :: ksatexm_extension_active
    logical, intent(in) :: default_mvg_family

    route = FMR_AHL_ROUTE_ANALYTICAL

    ! F-AHL-P01 bounded admission policy.
    ! Only the exact already-qualified default-MvG prescribed-head route is
    ! eligible. Everything else is deliberately fail-closed to authority.
    if (.not. default_mvg_family) return
    if (bottom_mode /= 5) return
    if (swkimpl /= 0) return
    if (ksatexm_extension_active) return

    route = FMR_AHL_ROUTE_ADAPTIVE_DEFAULT_MVG
  end function select_fmr_adaptive_hydraulic_route

end module mod_fmr_adaptive_hydraulic_policy
