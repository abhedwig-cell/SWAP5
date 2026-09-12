program test_fgc20_groundwater_tile_aggregation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_tile_aggregation, only: groundwater_tile_exchange_t, groundwater_cell_exchange_t, &
       aggregate_groundwater_cell_tiles, GW_TILE_COMPONENT_SWAP, GW_TILE_COMPONENT_EXTERNAL, &
       GW_TILE_AGG_OK, GW_TILE_AGG_DUPLICATE_TILE, GW_TILE_AGG_FRACTION_SUM, GW_TILE_AGG_WRONG_CELL
  implicit none

  type(groundwater_tile_exchange_t) :: tiles(3), permuted(3), bad(3)
  type(groundwater_cell_exchange_t) :: aggregate_a, aggregate_b
  integer :: status

  tiles(1) = tile(77_int64, 1_int64, 101_int64, GW_TILE_COMPONENT_SWAP, 0.25_real64, 1.0e-6_real64)
  tiles(2) = tile(77_int64, 2_int64, 102_int64, GW_TILE_COMPONENT_EXTERNAL, 0.50_real64, 2.0e-6_real64)
  tiles(3) = tile(77_int64, 3_int64, 103_int64, GW_TILE_COMPONENT_SWAP, 0.25_real64, -1.0e-6_real64)

  call aggregate_groundwater_cell_tiles(77_int64, tiles, aggregate_a, status)
  call require(status == GW_TILE_AGG_OK .and. aggregate_a%available, 'valid multi-tile aggregation')
  call require(aggregate_a%tile_count == 3, 'tile count')
  call require(aggregate_a%swap_tile_count == 2 .and. aggregate_a%external_tile_count == 1, 'mixed component counts')
  call require(abs(aggregate_a%fraction_sum-1.0_real64) < 1.0e-14_real64, 'fraction sum')
  call require(abs(aggregate_a%q_swap_area_weighted_m_per_s-1.0e-6_real64) < 1.0e-18_real64, 'weighted q swap')
  call require(aggregate_a%q_groundwater_area_weighted_m_per_s == -aggregate_a%q_swap_area_weighted_m_per_s, &
       'exact action reaction')

  permuted = [tiles(3), tiles(1), tiles(2)]
  call aggregate_groundwater_cell_tiles(77_int64, permuted, aggregate_b, status)
  call require(status == GW_TILE_AGG_OK, 'permuted aggregation valid')
  call require(abs(aggregate_b%q_swap_area_weighted_m_per_s-aggregate_a%q_swap_area_weighted_m_per_s) <= &
       8.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(aggregate_a%q_swap_area_weighted_m_per_s)), &
       'aggregation order identity envelope')

  bad = tiles
  bad(3)%tile_id = bad(2)%tile_id
  call aggregate_groundwater_cell_tiles(77_int64, bad, aggregate_b, status)
  call require(status == GW_TILE_AGG_DUPLICATE_TILE .and. .not. aggregate_b%available, 'duplicate tile rejected')

  bad = tiles
  bad(3)%area_fraction = 0.20_real64
  call aggregate_groundwater_cell_tiles(77_int64, bad, aggregate_b, status)
  call require(status == GW_TILE_AGG_FRACTION_SUM .and. .not. aggregate_b%available, 'fraction underfill rejected')

  bad = tiles
  bad(1)%groundwater_cell_id = 88_int64
  call aggregate_groundwater_cell_tiles(77_int64, bad, aggregate_b, status)
  call require(status == GW_TILE_AGG_WRONG_CELL .and. .not. aggregate_b%available, 'wrong cell rejected')

  tiles(1) = tile(99_int64, 9_int64, 109_int64, GW_TILE_COMPONENT_EXTERNAL, 1.0_real64, 4.0e-7_real64)
  call aggregate_groundwater_cell_tiles(99_int64, tiles(1:1), aggregate_b, status)
  call require(status == GW_TILE_AGG_OK, 'single non-SWAP tile supported')
  call require(aggregate_b%swap_tile_count == 0 .and. aggregate_b%external_tile_count == 1, 'non-SWAP tile independent')

  write(*,'(a)') 'FGC20_TILE_AGGREGATION=PASS'
  write(*,'(a)') 'FGC20_NO_SILENT_NORMALIZATION=PASS'
  write(*,'(a)') 'FGC20_MULTI_TILE_CELL=PASS'
  write(*,'(a)') 'FGC20_MIXED_COMPONENT_TILES=PASS'
  write(*,'(a)') 'FGC20_EXACT_QGW_NEGATIVE_QSWAP=PASS'

contains

  function tile(cell_id, tile_id, lineage_id, kind, fraction, q) result(value)
    integer(int64), intent(in) :: cell_id, tile_id, lineage_id
    integer, intent(in) :: kind
    real(real64), intent(in) :: fraction, q
    type(groundwater_tile_exchange_t) :: value
    value%groundwater_cell_id = cell_id
    value%tile_id = tile_id
    value%tile_lineage_id = lineage_id
    value%component_kind = kind
    value%area_fraction = fraction
    value%q_swap_m_per_s = q
  end function tile

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,a)') 'FGC20_TEST_FAIL: ', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc20_groundwater_tile_aggregation
