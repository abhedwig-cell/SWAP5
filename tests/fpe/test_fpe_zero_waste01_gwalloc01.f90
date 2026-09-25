program test_fpe_zero_waste01_gwalloc01
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_tile_aggregation, only: groundwater_tile_exchange_t, groundwater_cell_exchange_t, &
       aggregate_groundwater_cell_tiles, GW_TILE_COMPONENT_SWAP, GW_TILE_AGG_OK
  implicit none

  integer :: ncell, ntile, repeats, rep, cell, k, status
  integer(int64) :: c0, c1, rate
  real(real64) :: old_seconds, reuse_seconds, old_checksum, reuse_checksum
  type(groundwater_tile_exchange_t), allocatable :: exchanges(:)
  type(groundwater_cell_exchange_t) :: aggregate
  character(len=64) :: arg

  call get_command_argument(1,arg); read(arg,*) ncell
  call get_command_argument(2,arg); read(arg,*) ntile
  call get_command_argument(3,arg); read(arg,*) repeats
  if (ncell <= 0 .or. ntile <= 0 .or. repeats <= 0) error stop 'GWALLOC01 invalid dimensions'
  if (mod(4,ntile) /= 0) error stop 'GWALLOC01 use exactly representable reciprocal tile counts'

  old_checksum = 0.0_real64
  call system_clock(c0,rate)
  do rep = 1, repeats
    do cell = 1, ncell
      allocate(exchanges(ntile))
      call fill_exchange_set(exchanges, cell)
      call aggregate_groundwater_cell_tiles(cell_id(cell), exchanges, aggregate, status)
      if (status /= GW_TILE_AGG_OK .or. .not. aggregate%available) error stop 'GWALLOC01 old aggregation failed'
      old_checksum = old_checksum + aggregate%q_swap_area_weighted_m_per_s + aggregate%fraction_sum
      deallocate(exchanges)
    end do
  end do
  call system_clock(c1)
  old_seconds = real(c1-c0,real64)/real(rate,real64)

  allocate(exchanges(ntile))
  reuse_checksum = 0.0_real64
  call system_clock(c0)
  do rep = 1, repeats
    do cell = 1, ncell
      call fill_exchange_set(exchanges, cell)
      call aggregate_groundwater_cell_tiles(cell_id(cell), exchanges(1:ntile), aggregate, status)
      if (status /= GW_TILE_AGG_OK .or. .not. aggregate%available) error stop 'GWALLOC01 reuse aggregation failed'
      reuse_checksum = reuse_checksum + aggregate%q_swap_area_weighted_m_per_s + aggregate%fraction_sum
    end do
  end do
  call system_clock(c1)
  reuse_seconds = real(c1-c0,real64)/real(rate,real64)
  deallocate(exchanges)

  if (transfer(old_checksum,0_int64) /= transfer(reuse_checksum,0_int64)) &
       error stop 'GWALLOC01 checksum bit drift'

  write(*,'(A,I0,A,I0,A,I0,A,ES16.8,A,ES16.8,A,F12.6,A,ES24.16)') &
       'GWALLOC01,ncell=',ncell,',ntile=',ntile,',repeats=',repeats, &
       ',old_seconds=',old_seconds,',reuse_seconds=',reuse_seconds, &
       ',ratio=',reuse_seconds/old_seconds,',checksum=',old_checksum
  write(*,'(A)') 'FPE_ZERO_WASTE01_GWALLOC01_IDENTITY=PASS'

contains

  pure integer(int64) function cell_id(cell) result(value)
    integer, intent(in) :: cell
    value = 1000000_int64 + int(cell,int64)
  end function cell_id

  subroutine fill_exchange_set(values, cell)
    type(groundwater_tile_exchange_t), intent(out) :: values(:)
    integer, intent(in) :: cell
    integer :: j
    real(real64) :: fraction

    fraction = 1.0_real64 / real(size(values),real64)
    do j = 1, size(values)
      values(j)%groundwater_cell_id = cell_id(cell)
      values(j)%tile_id = int(cell,int64)*100_int64 + int(j,int64)
      values(j)%tile_lineage_id = values(j)%tile_id + 7000000_int64
      values(j)%component_kind = GW_TILE_COMPONENT_SWAP
      values(j)%area_fraction = fraction
      values(j)%q_swap_m_per_s = 1.0e-6_real64 * (1.0_real64 + 1.0e-4_real64*real(j,real64))
    end do
  end subroutine fill_exchange_set

end program test_fpe_zero_waste01_gwalloc01
