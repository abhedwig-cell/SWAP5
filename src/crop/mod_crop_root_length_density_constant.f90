module mod_crop_root_length_density_constant
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private

  integer, parameter, public :: ROOT_LRV_CONSTANT_OK = 0
  integer, parameter, public :: ROOT_LRV_CONSTANT_INVALID_TABLE = 1
  integer, parameter, public :: ROOT_LRV_CONSTANT_INVALID_GEOMETRY = 2
  integer, parameter, public :: ROOT_LRV_CONSTANT_INVALID_RESULT = 3
  real(real64), parameter, public :: ROOT_LRV_CONSTANT_FLOOR = 0.01_real64

  public :: evaluate_constant_absolute_root_length_density

contains

  subroutine evaluate_constant_absolute_root_length_density(table, node_z_cm, rooted_nodes, rooted_bottom_cm, &
                                                             root_length_density, status)
    type(wofost_rate_table_t), intent(in) :: table
    real(real64), intent(in) :: node_z_cm(:)
    integer, intent(in) :: rooted_nodes
    real(real64), intent(in) :: rooted_bottom_cm
    real(real64), allocatable, intent(out) :: root_length_density(:)
    integer, intent(out) :: status

    integer :: node, table_status
    real(real64) :: relative_depth, value

    if (allocated(root_length_density)) deallocate(root_length_density)
    status = ROOT_LRV_CONSTANT_INVALID_GEOMETRY

    if (.not. table%ready()) then
      status = ROOT_LRV_CONSTANT_INVALID_TABLE
      return
    end if
    if (size(node_z_cm) <= 0 .or. any(.not. ieee_is_finite(node_z_cm))) return
    if (rooted_nodes < 0 .or. rooted_nodes > size(node_z_cm)) return
    if (.not. ieee_is_finite(rooted_bottom_cm) .or. rooted_bottom_cm >= 0.0_real64) return

    allocate(root_length_density(size(node_z_cm)))
    root_length_density = 0.0_real64
    if (rooted_nodes == 0) then
      status = ROOT_LRV_CONSTANT_OK
      return
    end if

    do node = 1, rooted_nodes
      if (node_z_cm(node) > 0.0_real64) then
        deallocate(root_length_density)
        status = ROOT_LRV_CONSTANT_INVALID_GEOMETRY
        return
      end if
      relative_depth = -node_z_cm(node) / abs(rooted_bottom_cm)
      call table%evaluate(relative_depth, value, table_status)
      if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(value)) then
        deallocate(root_length_density)
        status = ROOT_LRV_CONSTANT_INVALID_TABLE
        return
      end if
      root_length_density(node) = max(ROOT_LRV_CONSTANT_FLOOR, value)
    end do

    if (any(.not. ieee_is_finite(root_length_density)) .or. any(root_length_density < 0.0_real64)) then
      deallocate(root_length_density)
      status = ROOT_LRV_CONSTANT_INVALID_RESULT
      return
    end if
    status = ROOT_LRV_CONSTANT_OK
  end subroutine evaluate_constant_absolute_root_length_density

end module mod_crop_root_length_density_constant
