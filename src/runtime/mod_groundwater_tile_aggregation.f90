module mod_groundwater_tile_aggregation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: GW_TILE_COMPONENT_SWAP = 1
  integer, parameter, public :: GW_TILE_COMPONENT_EXTERNAL = 2

  integer, parameter, public :: GW_TILE_AGG_OK = 0
  integer, parameter, public :: GW_TILE_AGG_EMPTY = 1
  integer, parameter, public :: GW_TILE_AGG_INVALID_ID = 2
  integer, parameter, public :: GW_TILE_AGG_WRONG_CELL = 3
  integer, parameter, public :: GW_TILE_AGG_INVALID_COMPONENT = 4
  integer, parameter, public :: GW_TILE_AGG_INVALID_FRACTION = 5
  integer, parameter, public :: GW_TILE_AGG_DUPLICATE_TILE = 6
  integer, parameter, public :: GW_TILE_AGG_FRACTION_SUM = 7
  integer, parameter, public :: GW_TILE_AGG_INVALID_FLUX = 8
  integer, parameter, public :: GW_TILE_AGG_NONFINITE_RESULT = 9

  type, public :: groundwater_tile_exchange_t
    integer(int64) :: groundwater_cell_id = 0_int64
    integer(int64) :: tile_id = 0_int64
    integer(int64) :: tile_lineage_id = 0_int64
    integer :: component_kind = 0
    real(real64) :: area_fraction = 0.0_real64
    real(real64) :: q_swap_m_per_s = 0.0_real64
  end type groundwater_tile_exchange_t

  type, public :: groundwater_cell_exchange_t
    logical :: available = .false.
    integer(int64) :: groundwater_cell_id = 0_int64
    integer :: tile_count = 0
    integer :: swap_tile_count = 0
    integer :: external_tile_count = 0
    real(real64) :: fraction_sum = 0.0_real64
    real(real64) :: q_swap_area_weighted_m_per_s = 0.0_real64
    real(real64) :: q_groundwater_area_weighted_m_per_s = 0.0_real64
  end type groundwater_cell_exchange_t

  public :: aggregate_groundwater_cell_tiles

contains

  subroutine aggregate_groundwater_cell_tiles(target_cell_id, tiles, aggregate, status)
    integer(int64), intent(in) :: target_cell_id
    type(groundwater_tile_exchange_t), intent(in) :: tiles(:)
    type(groundwater_cell_exchange_t), intent(out) :: aggregate
    integer, intent(out) :: status

    integer :: i, j
    real(real64) :: fraction_sum, fraction_compensation
    real(real64) :: weighted_flux, flux_compensation, term, y, t
    real(real64) :: fraction_scale

    aggregate = groundwater_cell_exchange_t()
    status = GW_TILE_AGG_EMPTY
    if (size(tiles) <= 0) return

    status = GW_TILE_AGG_INVALID_ID
    if (target_cell_id <= 0_int64) return

    fraction_sum = 0.0_real64
    fraction_compensation = 0.0_real64
    weighted_flux = 0.0_real64
    flux_compensation = 0.0_real64

    do i = 1, size(tiles)
      status = GW_TILE_AGG_INVALID_ID
      if (tiles(i)%tile_id <= 0_int64 .or. tiles(i)%tile_lineage_id <= 0_int64) return
      status = GW_TILE_AGG_WRONG_CELL
      if (tiles(i)%groundwater_cell_id /= target_cell_id) return
      status = GW_TILE_AGG_INVALID_COMPONENT
      if (tiles(i)%component_kind /= GW_TILE_COMPONENT_SWAP .and. &
          tiles(i)%component_kind /= GW_TILE_COMPONENT_EXTERNAL) return
      status = GW_TILE_AGG_INVALID_FRACTION
      if (.not. ieee_is_finite(tiles(i)%area_fraction)) return
      if (tiles(i)%area_fraction <= 0.0_real64 .or. tiles(i)%area_fraction > 1.0_real64) return
      status = GW_TILE_AGG_INVALID_FLUX
      if (.not. ieee_is_finite(tiles(i)%q_swap_m_per_s)) return

      do j = 1, i-1
        status = GW_TILE_AGG_DUPLICATE_TILE
        if (tiles(j)%tile_id == tiles(i)%tile_id) return
      end do

      ! Kahan compensated accumulation keeps aggregation deterministic enough for
      ! different runtime batching orders without introducing a user tolerance.
      y = tiles(i)%area_fraction - fraction_compensation
      t = fraction_sum + y
      fraction_compensation = (t - fraction_sum) - y
      fraction_sum = t

      term = tiles(i)%area_fraction * tiles(i)%q_swap_m_per_s
      if (.not. ieee_is_finite(term)) then
        status = GW_TILE_AGG_NONFINITE_RESULT
        return
      end if
      y = term - flux_compensation
      t = weighted_flux + y
      flux_compensation = (t - weighted_flux) - y
      weighted_flux = t
    end do

    status = GW_TILE_AGG_FRACTION_SUM
    fraction_scale = max(1.0_real64, abs(fraction_sum))
    if (abs(fraction_sum-1.0_real64) > 64.0_real64*epsilon(1.0_real64)*fraction_scale) return

    if (.not. ieee_is_finite(weighted_flux)) then
      status = GW_TILE_AGG_NONFINITE_RESULT
      return
    end if

    aggregate%available = .true.
    aggregate%groundwater_cell_id = target_cell_id
    aggregate%tile_count = size(tiles)
    aggregate%swap_tile_count = count(tiles%component_kind == GW_TILE_COMPONENT_SWAP)
    aggregate%external_tile_count = count(tiles%component_kind == GW_TILE_COMPONENT_EXTERNAL)
    aggregate%fraction_sum = fraction_sum
    aggregate%q_swap_area_weighted_m_per_s = weighted_flux
    aggregate%q_groundwater_area_weighted_m_per_s = -weighted_flux
    status = GW_TILE_AGG_OK
  end subroutine aggregate_groundwater_cell_tiles

end module mod_groundwater_tile_aggregation
