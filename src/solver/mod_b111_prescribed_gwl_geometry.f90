module mod_b111_prescribed_gwl_geometry
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: B111_GWL_GEOM_INVALID = 0
  integer, parameter, public :: B111_GWL_GEOM_HIGH = 1
  integer, parameter, public :: B111_GWL_GEOM_IN_PROFILE = 2
  integer, parameter, public :: B111_GWL_GEOM_BELOW_PROFILE = 3

  type, public :: b111_prescribed_gwl_geometry_t
    integer :: status = B111_GWL_GEOM_INVALID
    integer :: unsaturated_nodes = 0
    logical :: valid = .false.
    logical :: below_profile = .false.
    logical :: snapped_to_node = .false.
    real(real64) :: effective_gwl_cm = 0.0_real64
  end type

  public :: classify_b111_prescribed_gwl_geometry

contains

  pure subroutine classify_b111_prescribed_gwl_geometry(z_cm, gwl_cm, nihil_cm, result)
    real(real64), intent(in) :: z_cm(:), gwl_cm, nihil_cm
    type(b111_prescribed_gwl_geometry_t), intent(out) :: result
    integer :: n, nn

    result = b111_prescribed_gwl_geometry_t()
    n = size(z_cm)
    if (n <= 0) return
    if (any(.not. ieee_is_finite(z_cm)) .or. .not. ieee_is_finite(gwl_cm) .or. .not. ieee_is_finite(nihil_cm)) return
    if (n > 1) then
      if (any(z_cm(2:n) >= z_cm(1:n-1))) return
    end if

    result%effective_gwl_cm = gwl_cm

    ! Literal B1.11 high-groundwater special branch. Ordinary parser-admissible
    ! mode1 application will continue to exclude this branch separately.
    if (gwl_cm >= z_cm(1)-1.0e-4_real64) then
      result%status = B111_GWL_GEOM_HIGH
      result%valid = .true.
      return
    end if

    nn = 0
    do while (nn < n)
      if (z_cm(nn+1) <= gwl_cm) exit
      nn = nn + 1
    end do

    if (nn == n) then
      result%status = B111_GWL_GEOM_BELOW_PROFILE
      result%unsaturated_nodes = n
      result%below_profile = .true.
      result%valid = .true.
      return
    end if

    ! B1.11 tests z(nn+1) against gwl+nihil. If the interface is effectively
    ! on node nn, snap and remove that node from the Richards unknown set.
    if (z_cm(nn+1) < gwl_cm + nihil_cm) then
      if (nn > 0) then
        if (z_cm(nn)-gwl_cm < 1.0e-4_real64) then
          result%effective_gwl_cm = z_cm(nn)
          result%snapped_to_node = .true.
          nn = nn - 1
        end if
      end if
    end if

    result%status = B111_GWL_GEOM_IN_PROFILE
    result%unsaturated_nodes = nn
    result%valid = .true.
  end subroutine

end module mod_b111_prescribed_gwl_geometry
