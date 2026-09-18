module mod_b110_legacy_groundwater_level_projection
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: B110_LEGACY_GWL_OK = 0
  integer, parameter, public :: B110_LEGACY_GWL_INVALID_INPUT = 1
  integer, parameter, public :: B110_LEGACY_GWL_UNSUPPORTED_BOTTOM = 2
  integer, parameter, public :: B110_LEGACY_GWL_UNSUPPORTED_MACROPORE = 3
  integer, parameter, public :: B110_LEGACY_GWL_NO_WATER_TABLE = 4

  type, public :: b110_legacy_gwl_diagnostics_t
    integer :: status = B110_LEGACY_GWL_INVALID_INPUT
    integer :: crossing_lower_node = 0
    logical :: value_defined = .false.
    character(len=48) :: route = 'not-evaluated'
  end type b110_legacy_gwl_diagnostics_t

  public :: evaluate_b110_legacy_swbotb6_groundwater_level

contains

  pure subroutine evaluate_b110_legacy_swbotb6_groundwater_level(bottom_mode, macropore_active, z, node_distance, &
                                                                  pressure_head, ponding_depth, groundwater_level, &
                                                                  diagnostics)
    integer, intent(in) :: bottom_mode
    logical, intent(in) :: macropore_active
    real(real64), intent(in) :: z(:), node_distance(:), pressure_head(:)
    real(real64), intent(in) :: ponding_depth
    real(real64), intent(out) :: groundwater_level
    type(b110_legacy_gwl_diagnostics_t), intent(out) :: diagnostics

    integer :: n, node
    real(real64) :: h_lower, h_upper, denominator

    groundwater_level = 0.0_real64
    diagnostics = b110_legacy_gwl_diagnostics_t()

    if (bottom_mode /= 6) then
      diagnostics%status = B110_LEGACY_GWL_UNSUPPORTED_BOTTOM
      diagnostics%route = 'swbotb6-only'
      return
    end if
    if (macropore_active) then
      diagnostics%status = B110_LEGACY_GWL_UNSUPPORTED_MACROPORE
      diagnostics%route = 'macropore-excluded'
      return
    end if

    n = size(pressure_head)
    if (n < 2 .or. size(z) /= n .or. size(node_distance) /= n) then
      diagnostics%route = 'shape-invalid'
      return
    end if
    if (any(.not. ieee_is_finite(z)) .or. any(.not. ieee_is_finite(node_distance)) .or. &
        any(.not. ieee_is_finite(pressure_head)) .or. .not. ieee_is_finite(ponding_depth)) then
      diagnostics%route = 'nonfinite-input'
      return
    end if
    if (any(node_distance(2:n) <= 0.0_real64) .or. ponding_depth < 0.0_real64) then
      diagnostics%route = 'geometry-or-ponding-invalid'
      return
    end if

    ! Exact non-macropore calcgwl search used by B1.11 for SWBOTB /= 1.
    if (pressure_head(n) < 0.0_real64) then
      diagnostics%status = B110_LEGACY_GWL_NO_WATER_TABLE
      diagnostics%route = 'water-table-below-profile'
      return
    end if

    node = n
    do while (node > 1)
      node = node - 1
      if (pressure_head(node) < 0.0_real64) then
        h_lower = pressure_head(node)
        h_upper = pressure_head(node+1)
        denominator = h_upper-h_lower
        if (.not. ieee_is_finite(denominator) .or. denominator <= 0.0_real64) then
          diagnostics%route = 'crossing-invalid'
          return
        end if
        groundwater_level = z(node+1) + h_upper/denominator*node_distance(node+1)
        if (.not. ieee_is_finite(groundwater_level)) then
          groundwater_level = 0.0_real64
          diagnostics%route = 'projection-nonfinite'
          return
        end if
        diagnostics%status = B110_LEGACY_GWL_OK
        diagnostics%crossing_lower_node = node
        diagnostics%value_defined = .true.
        diagnostics%route = 'b111-nonmacro-interior-zero-crossing'
        return
      end if
    end do

    ! Exact fully-saturated branch of calcgwl.
    if (pressure_head(1) > 0.0_real64) then
      if (ponding_depth < 1.0e-8_real64) then
        groundwater_level = min(z(1)+pressure_head(1), ponding_depth)
      else
        groundwater_level = ponding_depth
      end if
    else
      groundwater_level = 0.0_real64
    end if
    if (.not. ieee_is_finite(groundwater_level)) then
      groundwater_level = 0.0_real64
      diagnostics%route = 'fully-saturated-nonfinite'
      return
    end if
    diagnostics%status = B110_LEGACY_GWL_OK
    diagnostics%crossing_lower_node = 0
    diagnostics%value_defined = .true.
    diagnostics%route = 'b111-nonmacro-fully-saturated'
  end subroutine evaluate_b110_legacy_swbotb6_groundwater_level

end module mod_b110_legacy_groundwater_level_projection
