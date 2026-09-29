module mod_fmr_elastic_storage_swap_grid_normalization
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  real(real64), parameter, public :: FMR_ELAS_GRID_CM_TO_M = 0.01_real64
  real(real64), parameter, public :: FMR_ELAS_GRID_TOL_CM = 1.0e-8_real64

  integer, parameter, public :: FMR_ELAS_GRID_OK = 0
  integer, parameter, public :: FMR_ELAS_GRID_INVALID_SHAPE = 1
  integer, parameter, public :: FMR_ELAS_GRID_INVALID_VALUE = 2
  integer, parameter, public :: FMR_ELAS_GRID_INCONSISTENT_GEOMETRY = 3

  type, public :: fmr_elastic_storage_grid_diagnostics_t
    integer :: status = FMR_ELAS_GRID_INVALID_SHAPE
    integer :: failed_node = 0
    logical :: values_valid = .false.
    logical :: geometry_valid = .false.
  end type fmr_elastic_storage_grid_diagnostics_t

  public :: fmr_normalize_swap_grid_cm

contains

  subroutine fmr_normalize_swap_grid_cm(z_cm, dz_cm, node_depth_m, node_thickness_m, diagnostics)
    real(real64), intent(in) :: z_cm(:)
    real(real64), intent(in) :: dz_cm(:)
    real(real64), allocatable, intent(out) :: node_depth_m(:)
    real(real64), allocatable, intent(out) :: node_thickness_m(:)
    type(fmr_elastic_storage_grid_diagnostics_t), intent(out) :: diagnostics

    integer :: i, n
    real(real64) :: top_cm, expected_z_cm

    if (allocated(node_depth_m)) deallocate(node_depth_m)
    if (allocated(node_thickness_m)) deallocate(node_thickness_m)
    diagnostics = fmr_elastic_storage_grid_diagnostics_t()

    n = size(z_cm)
    if (n <= 0 .or. size(dz_cm) /= n) return

    do i = 1, n
      if (.not. ieee_is_finite(z_cm(i)) .or. .not. ieee_is_finite(dz_cm(i))) then
        diagnostics%status = FMR_ELAS_GRID_INVALID_VALUE
        diagnostics%failed_node = i
        return
      end if
      if (z_cm(i) > 0.0_real64 .or. dz_cm(i) <= 0.0_real64) then
        diagnostics%status = FMR_ELAS_GRID_INVALID_VALUE
        diagnostics%failed_node = i
        return
      end if
    end do
    diagnostics%values_valid = .true.

    top_cm = 0.0_real64
    do i = 1, n
      expected_z_cm = -(top_cm + 0.5_real64 * dz_cm(i))
      if (abs(z_cm(i) - expected_z_cm) > FMR_ELAS_GRID_TOL_CM) then
        diagnostics%status = FMR_ELAS_GRID_INCONSISTENT_GEOMETRY
        diagnostics%failed_node = i
        return
      end if
      top_cm = top_cm + dz_cm(i)
    end do
    diagnostics%geometry_valid = .true.

    allocate(node_depth_m(n), node_thickness_m(n))
    node_depth_m = -FMR_ELAS_GRID_CM_TO_M * z_cm
    node_thickness_m = FMR_ELAS_GRID_CM_TO_M * dz_cm

    diagnostics%status = FMR_ELAS_GRID_OK
  end subroutine fmr_normalize_swap_grid_cm

end module mod_fmr_elastic_storage_swap_grid_normalization
