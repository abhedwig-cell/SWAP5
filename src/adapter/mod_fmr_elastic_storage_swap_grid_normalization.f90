module mod_fmr_elastic_storage_swap_grid_normalization
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  real(real64), parameter, public :: FMR_ELAS_GRID_TOL_M = 1.0e-10_real64

  integer, parameter, public :: FMR_ELAS_GRID_OK = 0
  integer, parameter, public :: FMR_ELAS_GRID_INVALID_SHAPE = 1
  integer, parameter, public :: FMR_ELAS_GRID_INVALID_VALUE = 2
  integer, parameter, public :: FMR_ELAS_GRID_NONCONTIGUOUS = 3

  type, public :: fmr_elastic_storage_grid_diagnostics_t
    integer :: status = FMR_ELAS_GRID_INVALID_SHAPE
    integer :: failed_node = 0
    logical :: geometry_complete = .false.
  end type fmr_elastic_storage_grid_diagnostics_t

  public :: fmr_normalize_swap_grid_geometry

contains

  subroutine fmr_normalize_swap_grid_geometry(z_cm, dz_cm, node_depth_m, node_thickness_m, diagnostics)
    real(real64), intent(in) :: z_cm(:), dz_cm(:)
    real(real64), allocatable, intent(out) :: node_depth_m(:), node_thickness_m(:)
    type(fmr_elastic_storage_grid_diagnostics_t), intent(out) :: diagnostics

    integer :: i, n
    real(real64) :: top_m, bottom_m, previous_bottom_m

    if (allocated(node_depth_m)) deallocate(node_depth_m)
    if (allocated(node_thickness_m)) deallocate(node_thickness_m)
    diagnostics = fmr_elastic_storage_grid_diagnostics_t()

    n = size(z_cm)
    if (n <= 0 .or. size(dz_cm) /= n) return

    allocate(node_depth_m(n), node_thickness_m(n))

    do i = 1, n
      if (.not. ieee_is_finite(z_cm(i)) .or. .not. ieee_is_finite(dz_cm(i))) then
        diagnostics%status = FMR_ELAS_GRID_INVALID_VALUE
        diagnostics%failed_node = i
        call clear_outputs(node_depth_m, node_thickness_m)
        return
      end if
      if (z_cm(i) > 1.0e-10_real64 .or. dz_cm(i) <= 0.0_real64) then
        diagnostics%status = FMR_ELAS_GRID_INVALID_VALUE
        diagnostics%failed_node = i
        call clear_outputs(node_depth_m, node_thickness_m)
        return
      end if

      node_depth_m(i) = -z_cm(i) / 100.0_real64
      node_thickness_m(i) = dz_cm(i) / 100.0_real64
      top_m = node_depth_m(i) - 0.5_real64 * node_thickness_m(i)
      bottom_m = node_depth_m(i) + 0.5_real64 * node_thickness_m(i)

      if (top_m < -1.0e-12_real64) then
        diagnostics%status = FMR_ELAS_GRID_INVALID_VALUE
        diagnostics%failed_node = i
        call clear_outputs(node_depth_m, node_thickness_m)
        return
      end if

      if (i == 1) then
        if (abs(top_m) > FMR_ELAS_GRID_TOL_M) then
          diagnostics%status = FMR_ELAS_GRID_NONCONTIGUOUS
          diagnostics%failed_node = i
          call clear_outputs(node_depth_m, node_thickness_m)
          return
        end if
      else
        if (abs(top_m - previous_bottom_m) > FMR_ELAS_GRID_TOL_M) then
          diagnostics%status = FMR_ELAS_GRID_NONCONTIGUOUS
          diagnostics%failed_node = i
          call clear_outputs(node_depth_m, node_thickness_m)
          return
        end if
      end if
      previous_bottom_m = bottom_m
    end do

    diagnostics%status = FMR_ELAS_GRID_OK
    diagnostics%geometry_complete = .true.
  end subroutine fmr_normalize_swap_grid_geometry

  subroutine clear_outputs(node_depth_m, node_thickness_m)
    real(real64), allocatable, intent(inout) :: node_depth_m(:), node_thickness_m(:)
    if (allocated(node_depth_m)) deallocate(node_depth_m)
    if (allocated(node_thickness_m)) deallocate(node_thickness_m)
  end subroutine clear_outputs

end module mod_fmr_elastic_storage_swap_grid_normalization
