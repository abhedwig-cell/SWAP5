module mod_groundwater_topology_composition
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  implicit none
  private

  integer, parameter, public :: GW_TOPOLOGY_OK = 0
  integer, parameter, public :: GW_TOPOLOGY_EMPTY = 1
  integer, parameter, public :: GW_TOPOLOGY_INVALID_TILE = 2
  integer, parameter, public :: GW_TOPOLOGY_INVALID_CELL = 3
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_TILE_ID = 4
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_SWAP_LINEAGE = 5
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_LEDGER_ID = 6
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_CELL_ID = 7
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_COUPLING_ID = 8
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_GROUNDWATER_LINEAGE = 9
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_PACKAGE_SLOT = 10
  integer, parameter, public :: GW_TOPOLOGY_DUPLICATE_MODFLOW_NODE = 11
  integer, parameter, public :: GW_TOPOLOGY_TILE_CELL_MISSING = 12
  integer, parameter, public :: GW_TOPOLOGY_CELL_WITHOUT_TILE = 13
  integer, parameter, public :: GW_TOPOLOGY_FRACTION_SUM = 14
  integer, parameter, public :: GW_TOPOLOGY_INVALID_OUTPUT = 15

  ! Application-level state/storage authority. These labels do not create
  ! physical storage; they state how a MODFLOW state equation is interpreted.
  integer, parameter, public :: GW_STORAGE_STATE_ROLE_UNRESOLVED = 0
  integer, parameter, public :: GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE = 1
  integer, parameter, public :: GW_STORAGE_STATE_ROLE_PHYSICAL_INDEPENDENT_STORAGE = 2
  integer, parameter, public :: GW_STORAGE_STATE_ROLE_MIXED_EFFECTIVE_STORAGE = 3

  ! Exactly one application owner may represent any admitted physical drainage
  ! route. The coupler/ledger is deliberately not a physical drainage owner.
  integer, parameter, public :: GW_DRAINAGE_OWNER_UNRESOLVED = 0
  integer, parameter, public :: GW_DRAINAGE_OWNER_NONE = 1
  integer, parameter, public :: GW_DRAINAGE_OWNER_SWAP = 2
  integer, parameter, public :: GW_DRAINAGE_OWNER_MODFLOW = 3
  integer, parameter, public :: GW_DRAINAGE_OWNER_SURFACE_WATER = 4

  type, public :: groundwater_topology_tile_t
    integer(int64) :: tile_id = 0_int64
    integer(int64) :: swap_lineage_id = 0_int64
    integer(int64) :: ledger_id = 0_int64
    integer(int64) :: groundwater_cell_id = 0_int64
    real(real64) :: area_fraction = 0.0_real64
  contains
    procedure, public :: valid => groundwater_topology_tile_valid
  end type groundwater_topology_tile_t

  type, public :: groundwater_topology_cell_t
    integer(int64) :: groundwater_cell_id = 0_int64
    integer(int64) :: coupling_id = 0_int64
    integer(int64) :: groundwater_service_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer :: package_slot = 0
    integer(int32) :: modflow_node_id = 0_int32
    integer :: storage_state_role = GW_STORAGE_STATE_ROLE_UNRESOLVED
    integer :: drainage_owner = GW_DRAINAGE_OWNER_UNRESOLVED
  contains
    procedure, public :: valid => groundwater_topology_cell_valid
  end type groundwater_topology_cell_t

  type, public :: groundwater_topology_t
    private
    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    type(groundwater_topology_cell_t), allocatable :: cells(:)
    logical :: materialized = .false.
  contains
    procedure, public :: ready => groundwater_topology_ready
    procedure, public :: tile_count => groundwater_topology_tile_count
    procedure, public :: cell_count => groundwater_topology_cell_count
    procedure, public :: copy_tiles => groundwater_topology_copy_tiles
    procedure, public :: copy_cells => groundwater_topology_copy_cells
    procedure, public :: direct_bindings_for_cell => groundwater_topology_direct_bindings_for_cell
    procedure, public :: api_bindings => groundwater_topology_api_bindings
  end type groundwater_topology_t

  public :: materialize_groundwater_topology

contains

  pure logical function groundwater_topology_tile_valid(self) result(valid)
    class(groundwater_topology_tile_t), intent(in) :: self

    valid = .false.
    if (self%tile_id <= 0_int64) return
    if (self%swap_lineage_id <= 0_int64) return
    if (self%ledger_id <= 0_int64) return
    if (self%groundwater_cell_id <= 0_int64) return
    if (.not. ieee_is_finite(self%area_fraction)) return
    if (self%area_fraction <= 0.0_real64 .or. self%area_fraction > 1.0_real64) return
    valid = .true.
  end function groundwater_topology_tile_valid

  pure logical function groundwater_topology_cell_valid(self) result(valid)
    class(groundwater_topology_cell_t), intent(in) :: self

    valid = .false.
    if (self%groundwater_cell_id <= 0_int64) return
    if (self%coupling_id <= 0_int64) return
    if (self%groundwater_service_id <= 0_int64) return
    if (self%groundwater_lineage_id <= 0_int64) return
    if (self%package_slot <= 0) return
    if (self%modflow_node_id <= 0_int32) return
    if (self%storage_state_role < GW_STORAGE_STATE_ROLE_UNRESOLVED .or. &
        self%storage_state_role > GW_STORAGE_STATE_ROLE_MIXED_EFFECTIVE_STORAGE) return
    if (self%drainage_owner < GW_DRAINAGE_OWNER_UNRESOLVED .or. &
        self%drainage_owner > GW_DRAINAGE_OWNER_SURFACE_WATER) return
    valid = .true.
  end function groundwater_topology_cell_valid

  subroutine materialize_groundwater_topology(tile_contracts, cell_contracts, topology, status)
    type(groundwater_topology_tile_t), intent(in) :: tile_contracts(:)
    type(groundwater_topology_cell_t), intent(in) :: cell_contracts(:)
    type(groundwater_topology_t), intent(out) :: topology
    integer, intent(out) :: status

    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    type(groundwater_topology_cell_t), allocatable :: cells(:)
    real(real64) :: fraction_sum, compensation, y, t, scale
    integer :: i, j, cell_index, tile_count, tile_cursor
    logical :: canonical_input, canonical_tiles, canonical_cells

    topology%materialized = .false.
    status = GW_TOPOLOGY_EMPTY
    if (size(tile_contracts) <= 0 .or. size(cell_contracts) <= 0) return

    allocate(tiles(size(tile_contracts)))
    allocate(cells(size(cell_contracts)))
    tiles = tile_contracts
    cells = cell_contracts

    canonical_tiles = .true.
    do i = 1, size(tiles)
      status = GW_TOPOLOGY_INVALID_TILE
      if (.not. tiles(i)%valid()) return
      if (i > 1) then
        if (tiles(i-1)%tile_id >= tiles(i)%tile_id) canonical_tiles = .false.
        if (tiles(i-1)%swap_lineage_id >= tiles(i)%swap_lineage_id) canonical_tiles = .false.
        if (tiles(i-1)%ledger_id >= tiles(i)%ledger_id) canonical_tiles = .false.
        if (tiles(i-1)%groundwater_cell_id > tiles(i)%groundwater_cell_id) canonical_tiles = .false.
      end if
    end do

    if (.not. canonical_tiles) then
      do i = 1, size(tiles)
        do j = 1, i - 1
          if (tiles(j)%tile_id == tiles(i)%tile_id) then
            status = GW_TOPOLOGY_DUPLICATE_TILE_ID
            return
          end if
          if (tiles(j)%swap_lineage_id == tiles(i)%swap_lineage_id) then
            status = GW_TOPOLOGY_DUPLICATE_SWAP_LINEAGE
            return
          end if
          if (tiles(j)%ledger_id == tiles(i)%ledger_id) then
            status = GW_TOPOLOGY_DUPLICATE_LEDGER_ID
            return
          end if
        end do
      end do
    end if

    canonical_cells = .true.
    do i = 1, size(cells)
      status = GW_TOPOLOGY_INVALID_CELL
      if (.not. cells(i)%valid()) return
      if (cells(i)%package_slot > size(cells)) return
      if (i > 1) then
        if (cells(i-1)%groundwater_cell_id >= cells(i)%groundwater_cell_id) canonical_cells = .false.
        if (cells(i-1)%coupling_id >= cells(i)%coupling_id) canonical_cells = .false.
        if (cells(i-1)%groundwater_lineage_id >= cells(i)%groundwater_lineage_id) canonical_cells = .false.
        if (cells(i-1)%package_slot >= cells(i)%package_slot) canonical_cells = .false.
        if (cells(i-1)%modflow_node_id >= cells(i)%modflow_node_id) canonical_cells = .false.
      end if
    end do

    if (.not. canonical_cells) then
      do i = 1, size(cells)
        do j = 1, i - 1
          if (cells(j)%groundwater_cell_id == cells(i)%groundwater_cell_id) then
            status = GW_TOPOLOGY_DUPLICATE_CELL_ID
            return
          end if
          if (cells(j)%coupling_id == cells(i)%coupling_id) then
            status = GW_TOPOLOGY_DUPLICATE_COUPLING_ID
            return
          end if
          if (cells(j)%groundwater_lineage_id == cells(i)%groundwater_lineage_id) then
            status = GW_TOPOLOGY_DUPLICATE_GROUNDWATER_LINEAGE
            return
          end if
          if (cells(j)%package_slot == cells(i)%package_slot) then
            status = GW_TOPOLOGY_DUPLICATE_PACKAGE_SLOT
            return
          end if
          if (cells(j)%modflow_node_id == cells(i)%modflow_node_id) then
            status = GW_TOPOLOGY_DUPLICATE_MODFLOW_NODE
            return
          end if
        end do
      end do
    end if
    canonical_input = canonical_tiles .and. canonical_cells

    if (canonical_input) then
      cell_index = 1
      do i = 1, size(tiles)
        do while (cell_index <= size(cells) .and. &
             cells(cell_index)%groundwater_cell_id < tiles(i)%groundwater_cell_id)
          cell_index = cell_index + 1
        end do
        if (cell_index > size(cells) .or. &
            cells(cell_index)%groundwater_cell_id /= tiles(i)%groundwater_cell_id) then
          status = GW_TOPOLOGY_TILE_CELL_MISSING
          return
        end if
      end do
    else
      do i = 1, size(tiles)
        cell_index = find_cell_index(cells, tiles(i)%groundwater_cell_id)
        if (cell_index <= 0) then
          status = GW_TOPOLOGY_TILE_CELL_MISSING
          return
        end if
      end do
    end if

    if (canonical_input) then
      tile_cursor = 1
      do i = 1, size(cells)
        fraction_sum = 0.0_real64
        compensation = 0.0_real64
        tile_count = 0
        do while (tile_cursor <= size(tiles))
          if (tiles(tile_cursor)%groundwater_cell_id /= cells(i)%groundwater_cell_id) exit
          tile_count = tile_count + 1
          y = tiles(tile_cursor)%area_fraction - compensation
          t = fraction_sum + y
          compensation = (t - fraction_sum) - y
          fraction_sum = t
          tile_cursor = tile_cursor + 1
        end do
        if (tile_count <= 0) then
          status = GW_TOPOLOGY_CELL_WITHOUT_TILE
          return
        end if
        scale = max(1.0_real64, abs(fraction_sum))
        if (abs(fraction_sum - 1.0_real64) > 64.0_real64 * epsilon(1.0_real64) * scale) then
          status = GW_TOPOLOGY_FRACTION_SUM
          return
        end if
      end do
    else
      do i = 1, size(cells)
        fraction_sum = 0.0_real64
        compensation = 0.0_real64
        tile_count = 0
        do j = 1, size(tiles)
          if (tiles(j)%groundwater_cell_id /= cells(i)%groundwater_cell_id) cycle
          tile_count = tile_count + 1
          y = tiles(j)%area_fraction - compensation
          t = fraction_sum + y
          compensation = (t - fraction_sum) - y
          fraction_sum = t
        end do
        if (tile_count <= 0) then
          status = GW_TOPOLOGY_CELL_WITHOUT_TILE
          return
        end if
        scale = max(1.0_real64, abs(fraction_sum))
        if (abs(fraction_sum - 1.0_real64) > 64.0_real64 * epsilon(1.0_real64) * scale) then
          status = GW_TOPOLOGY_FRACTION_SUM
          return
        end if
      end do
    end if

    if (.not. canonical_input) then
      call sort_cells_by_id(cells)
      call sort_tiles_by_cell_then_tile(tiles)
    end if

    allocate(topology%tiles(size(tiles)))
    allocate(topology%cells(size(cells)))
    topology%tiles = tiles
    topology%cells = cells
    topology%materialized = .true.
    status = GW_TOPOLOGY_OK
  end subroutine materialize_groundwater_topology

  pure logical function groundwater_topology_ready(self) result(ready)
    class(groundwater_topology_t), intent(in) :: self
    ready = self%materialized .and. allocated(self%tiles) .and. allocated(self%cells)
    if (.not. ready) return
    ready = size(self%tiles) > 0 .and. size(self%cells) > 0
  end function groundwater_topology_ready

  pure integer function groundwater_topology_tile_count(self) result(count)
    class(groundwater_topology_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = size(self%tiles)
  end function groundwater_topology_tile_count

  pure integer function groundwater_topology_cell_count(self) result(count)
    class(groundwater_topology_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = size(self%cells)
  end function groundwater_topology_cell_count

  subroutine groundwater_topology_copy_tiles(self, tile_contracts, status)
    class(groundwater_topology_t), intent(in) :: self
    type(groundwater_topology_tile_t), allocatable, intent(out) :: tile_contracts(:)
    integer, intent(out) :: status

    status = GW_TOPOLOGY_INVALID_OUTPUT
    if (.not. self%ready()) return
    allocate(tile_contracts(size(self%tiles)))
    tile_contracts = self%tiles
    status = GW_TOPOLOGY_OK
  end subroutine groundwater_topology_copy_tiles

  subroutine groundwater_topology_copy_cells(self, cell_contracts, status)
    class(groundwater_topology_t), intent(in) :: self
    type(groundwater_topology_cell_t), allocatable, intent(out) :: cell_contracts(:)
    integer, intent(out) :: status

    status = GW_TOPOLOGY_INVALID_OUTPUT
    if (.not. self%ready()) return
    allocate(cell_contracts(size(self%cells)))
    cell_contracts = self%cells
    status = GW_TOPOLOGY_OK
  end subroutine groundwater_topology_copy_cells

  subroutine groundwater_topology_direct_bindings_for_cell(self, groundwater_cell_id, bindings, status)
    class(groundwater_topology_t), intent(in) :: self
    integer(int64), intent(in) :: groundwater_cell_id
    type(groundwater_direct_tile_binding_t), allocatable, intent(out) :: bindings(:)
    integer, intent(out) :: status

    integer :: i, n, k

    status = GW_TOPOLOGY_INVALID_OUTPUT
    if (.not. self%ready()) return
    if (find_cell_index(self%cells, groundwater_cell_id) <= 0) return

    n = count(self%tiles%groundwater_cell_id == groundwater_cell_id)
    if (n <= 0) return
    allocate(bindings(n))
    k = 0
    do i = 1, size(self%tiles)
      if (self%tiles(i)%groundwater_cell_id /= groundwater_cell_id) cycle
      k = k + 1
      bindings(k)%groundwater_cell_id = groundwater_cell_id
      bindings(k)%tile_id = self%tiles(i)%tile_id
      bindings(k)%area_fraction = self%tiles(i)%area_fraction
    end do
    status = GW_TOPOLOGY_OK
  end subroutine groundwater_topology_direct_bindings_for_cell

  subroutine groundwater_topology_api_bindings(self, bindings, status)
    class(groundwater_topology_t), intent(in) :: self
    type(modflow6_api_slot_binding_t), allocatable, intent(out) :: bindings(:)
    integer, intent(out) :: status

    integer :: i, slot

    status = GW_TOPOLOGY_INVALID_OUTPUT
    if (.not. self%ready()) return
    allocate(bindings(size(self%cells)))
    do i = 1, size(self%cells)
      slot = self%cells(i)%package_slot
      if (slot < 1 .or. slot > size(bindings)) return
      bindings(slot)%groundwater_cell_id = self%cells(i)%groundwater_cell_id
      bindings(slot)%package_slot = slot
      bindings(slot)%modflow_node_id = self%cells(i)%modflow_node_id
    end do
    status = GW_TOPOLOGY_OK
  end subroutine groundwater_topology_api_bindings

  pure integer function find_cell_index(cells, groundwater_cell_id) result(index)
    type(groundwater_topology_cell_t), intent(in) :: cells(:)
    integer(int64), intent(in) :: groundwater_cell_id
    integer :: i

    index = 0
    do i = 1, size(cells)
      if (cells(i)%groundwater_cell_id == groundwater_cell_id) then
        index = i
        return
      end if
    end do
  end function find_cell_index

  subroutine sort_cells_by_id(cells)
    type(groundwater_topology_cell_t), intent(inout) :: cells(:)
    type(groundwater_topology_cell_t) :: key
    integer :: i, j

    do i = 2, size(cells)
      key = cells(i)
      j = i - 1
      do while (j >= 1)
        if (cells(j)%groundwater_cell_id <= key%groundwater_cell_id) exit
        cells(j + 1) = cells(j)
        j = j - 1
      end do
      cells(j + 1) = key
    end do
  end subroutine sort_cells_by_id

  subroutine sort_tiles_by_cell_then_tile(tiles)
    type(groundwater_topology_tile_t), intent(inout) :: tiles(:)
    type(groundwater_topology_tile_t) :: key
    integer :: i, j

    do i = 2, size(tiles)
      key = tiles(i)
      j = i - 1
      do while (j >= 1)
        if (tiles(j)%groundwater_cell_id < key%groundwater_cell_id) exit
        if (tiles(j)%groundwater_cell_id == key%groundwater_cell_id .and. &
            tiles(j)%tile_id <= key%tile_id) exit
        tiles(j + 1) = tiles(j)
        j = j - 1
      end do
      tiles(j + 1) = key
    end do
  end subroutine sort_tiles_by_cell_then_tile

end module mod_groundwater_topology_composition
