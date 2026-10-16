module mod_groundwater_application_plan
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_t, groundwater_topology_tile_t, &
       groundwater_topology_cell_t, GW_TOPOLOGY_OK
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_response_t, MODFLOW6_PREDICTOR_OK
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
       compose_modflow6_multiswap_cell_response, MODFLOW6_MULTI_CELL_OK
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       compose_modflow6_linear_boundary_term, MODFLOW6_LINEAR_BACKEND_OK
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  implicit none
  private

  integer, parameter, public :: GW_APP_PLAN_OK = 0
  integer, parameter, public :: GW_APP_PLAN_INVALID_TOPOLOGY = 1
  integer, parameter, public :: GW_APP_PLAN_INVALID_PREDICTOR_COUNT = 2
  integer, parameter, public :: GW_APP_PLAN_INVALID_PREDICTOR = 3
  integer, parameter, public :: GW_APP_PLAN_DUPLICATE_PREDICTOR_TILE = 4
  integer, parameter, public :: GW_APP_PLAN_MISSING_PREDICTOR_TILE = 5
  integer, parameter, public :: GW_APP_PLAN_PREDICTOR_LINEAGE_MISMATCH = 6
  integer, parameter, public :: GW_APP_PLAN_PREDICTOR_CELL_MISMATCH = 7
  integer, parameter, public :: GW_APP_PLAN_WINDOW_MISMATCH = 8
  integer, parameter, public :: GW_APP_PLAN_SERVICE_MISMATCH = 9
  integer, parameter, public :: GW_APP_PLAN_INVALID_AREA_COUNT = 10
  integer, parameter, public :: GW_APP_PLAN_INVALID_AREA = 11
  integer, parameter, public :: GW_APP_PLAN_DUPLICATE_AREA_CELL = 12
  integer, parameter, public :: GW_APP_PLAN_MISSING_AREA_CELL = 13
  integer, parameter, public :: GW_APP_PLAN_BINDING_FAILED = 14
  integer, parameter, public :: GW_APP_PLAN_CELL_RESPONSE_FAILED = 15
  integer, parameter, public :: GW_APP_PLAN_LINEAR_TERM_FAILED = 16
  integer, parameter, public :: GW_APP_PLAN_INTERNAL_ORDER_FAILED = 17

  type, public :: groundwater_tile_predictor_input_t
    integer(int64) :: tile_id = 0_int64
    type(modflow6_swap_predictor_response_t) :: response
  contains
    procedure, public :: valid => tile_predictor_input_valid
  end type groundwater_tile_predictor_input_t

  type, public :: groundwater_cell_area_input_t
    integer(int64) :: groundwater_cell_id = 0_int64
    real(real64) :: cell_area_m2 = 0.0_real64
  contains
    procedure, public :: valid => cell_area_input_valid
  end type groundwater_cell_area_input_t

  type, public :: groundwater_application_cell_plan_t
    type(groundwater_topology_cell_t) :: topology
    integer :: tile_begin = 0
    integer :: tile_count = 0
    real(real64) :: reference_head_m = 0.0_real64
    type(modflow6_multiswap_cell_response_t) :: response
    type(modflow6_linear_boundary_term_t) :: linear_term
  contains
    procedure, public :: valid => application_cell_plan_valid
  end type groundwater_application_cell_plan_t

  type, public :: groundwater_application_plan_t
    private
    type(groundwater_coupling_window_t) :: window_value
    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    integer(int64), allocatable :: tile_swap_origin_revisions(:)
    type(groundwater_application_cell_plan_t), allocatable :: cells(:)
    type(modflow6_api_slot_binding_t), allocatable :: api(:)
    logical :: materialized = .false.
  contains
    procedure, public :: ready => application_plan_ready
    procedure, public :: tile_count => application_plan_tile_count
    procedure, public :: cell_count => application_plan_cell_count
    procedure, public :: window => application_plan_window
    procedure, public :: copy_tiles => application_plan_copy_tiles
    procedure, public :: copy_tile_swap_origin_revisions => application_plan_copy_tile_swap_origin_revisions
    procedure, public :: copy_cells => application_plan_copy_cells
    procedure, public :: copy_linear_terms => application_plan_copy_linear_terms
    procedure, public :: copy_api_bindings => application_plan_copy_api_bindings
  end type groundwater_application_plan_t

  public :: materialize_groundwater_application_plan

contains

  pure logical function tile_predictor_input_valid(self) result(valid)
    class(groundwater_tile_predictor_input_t), intent(in) :: self

    valid = .false.
    if (self%tile_id <= 0_int64) return
    if (.not. self%response%valid) return
    if (self%response%status /= MODFLOW6_PREDICTOR_OK) return
    if (.not. self%response%window%valid()) return
    if (self%response%lineage%coupling_id <= 0_int64) return
    if (self%response%lineage%swap_lineage_id <= 0_int64) return
    if (self%response%lineage%swap_origin_revision < 0_int64) return
    if (self%response%lineage%groundwater_service_id <= 0_int64) return
    if (self%response%lineage%groundwater_lineage_id <= 0_int64) return
    if (self%response%lineage%groundwater_origin_revision < 0_int64) return
    valid = .true.
  end function tile_predictor_input_valid

  pure logical function cell_area_input_valid(self) result(valid)
    class(groundwater_cell_area_input_t), intent(in) :: self

    valid = self%groundwater_cell_id > 0_int64 .and. ieee_is_finite(self%cell_area_m2) .and. self%cell_area_m2 > 0.0_real64
  end function cell_area_input_valid

  pure logical function application_cell_plan_valid(self) result(valid)
    class(groundwater_application_cell_plan_t), intent(in) :: self

    valid = .false.
    if (.not. self%topology%valid()) return
    if (self%tile_begin <= 0 .or. self%tile_count <= 0) return
    if (.not. ieee_is_finite(self%reference_head_m)) return
    if (.not. self%response%valid .or. self%response%status /= MODFLOW6_MULTI_CELL_OK) return
    if (.not. self%linear_term%valid .or. self%linear_term%status /= MODFLOW6_LINEAR_BACKEND_OK) return
    if (self%response%groundwater_cell_id /= self%topology%groundwater_cell_id) return
    if (self%linear_term%groundwater_cell_id /= self%topology%groundwater_cell_id) return
    valid = .true.
  end function application_cell_plan_valid

  subroutine materialize_groundwater_application_plan(topology, predictors, cell_areas, plan, status)
    type(groundwater_topology_t), intent(in) :: topology
    type(groundwater_tile_predictor_input_t), intent(in) :: predictors(:)
    type(groundwater_cell_area_input_t), intent(in) :: cell_areas(:)
    type(groundwater_application_plan_t), intent(out) :: plan
    integer, intent(out) :: status

    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    type(groundwater_topology_cell_t), allocatable :: cells(:)
    type(modflow6_api_slot_binding_t), allocatable :: api(:)
    type(groundwater_direct_tile_binding_t), allocatable :: bindings(:)
    type(modflow6_swap_predictor_response_t), allocatable :: cell_responses(:)
    type(groundwater_coupling_window_t) :: common_window
    integer :: i, j, k, idx, predictor_index, area_index, first_tile, topology_status
    integer :: cell_cursor, binding_count
    real(real64) :: reference_head, compensation, term, y, t
    integer(int64) :: common_service_id
    logical :: have_window, canonical_alignment

    plan%materialized = .false.
    status = GW_APP_PLAN_INVALID_TOPOLOGY
    if (.not. topology%ready()) return

    call topology%copy_tiles(tiles, topology_status)
    if (topology_status /= GW_TOPOLOGY_OK .or. .not. allocated(tiles)) return
    call topology%copy_cells(cells, topology_status)
    if (topology_status /= GW_TOPOLOGY_OK .or. .not. allocated(cells)) return
    call topology%api_bindings(api, topology_status)
    if (topology_status /= GW_TOPOLOGY_OK .or. .not. allocated(api)) then
      status = GW_APP_PLAN_BINDING_FAILED
      return
    end if

    status = GW_APP_PLAN_INVALID_PREDICTOR_COUNT
    if (size(predictors) /= size(tiles)) return
    status = GW_APP_PLAN_INVALID_AREA_COUNT
    if (size(cell_areas) /= size(cells)) return

    canonical_alignment = .true.
    do i = 1, size(predictors)
      if (predictors(i)%tile_id /= tiles(i)%tile_id) canonical_alignment = .false.
    end do
    do i = 1, size(cell_areas)
      if (cell_areas(i)%groundwater_cell_id /= cells(i)%groundwater_cell_id) canonical_alignment = .false.
    end do

    if (canonical_alignment) then
      do i = 1, size(predictors)
        status = GW_APP_PLAN_INVALID_PREDICTOR
        if (.not. predictors(i)%valid()) return
      end do
      do i = 1, size(cell_areas)
        status = GW_APP_PLAN_INVALID_AREA
        if (.not. cell_areas(i)%valid()) return
      end do
    else
      do i = 1, size(predictors)
        status = GW_APP_PLAN_INVALID_PREDICTOR
        if (.not. predictors(i)%valid()) return
        do j = 1, i - 1
          if (predictors(j)%tile_id == predictors(i)%tile_id) then
            status = GW_APP_PLAN_DUPLICATE_PREDICTOR_TILE
            return
          end if
        end do
      end do

      do i = 1, size(cell_areas)
        status = GW_APP_PLAN_INVALID_AREA
        if (.not. cell_areas(i)%valid()) return
        do j = 1, i - 1
          if (cell_areas(j)%groundwater_cell_id == cell_areas(i)%groundwater_cell_id) then
            status = GW_APP_PLAN_DUPLICATE_AREA_CELL
            return
          end if
        end do
      end do
    end if

    have_window = .false.
    common_service_id = cells(1)%groundwater_service_id
    do i = 1, size(cells)
      if (cells(i)%groundwater_service_id /= common_service_id) then
        status = GW_APP_PLAN_SERVICE_MISMATCH
        return
      end if
    end do

    cell_cursor = 1
    do i = 1, size(tiles)
      if (canonical_alignment) then
        predictor_index = i
        do while (cell_cursor <= size(cells) .and. &
             cells(cell_cursor)%groundwater_cell_id < tiles(i)%groundwater_cell_id)
          cell_cursor = cell_cursor + 1
        end do
        if (cell_cursor > size(cells) .or. &
            cells(cell_cursor)%groundwater_cell_id /= tiles(i)%groundwater_cell_id) then
          status = GW_APP_PLAN_INVALID_TOPOLOGY
          return
        end if
        j = cell_cursor
      else
        predictor_index = find_predictor_index(predictors, tiles(i)%tile_id)
        if (predictor_index <= 0) then
          status = GW_APP_PLAN_MISSING_PREDICTOR_TILE
          return
        end if
        j = find_cell_index(cells, tiles(i)%groundwater_cell_id)
        if (j <= 0) then
          status = GW_APP_PLAN_INVALID_TOPOLOGY
          return
        end if
      end if

      if (predictors(predictor_index)%response%lineage%swap_lineage_id /= tiles(i)%swap_lineage_id) then
        status = GW_APP_PLAN_PREDICTOR_LINEAGE_MISMATCH
        return
      end if
      if (predictors(predictor_index)%response%lineage%coupling_id /= cells(j)%coupling_id .or. &
          predictors(predictor_index)%response%lineage%groundwater_service_id /= cells(j)%groundwater_service_id .or. &
          predictors(predictor_index)%response%lineage%groundwater_lineage_id /= cells(j)%groundwater_lineage_id) then
        status = GW_APP_PLAN_PREDICTOR_CELL_MISMATCH
        return
      end if

      if (.not. have_window) then
        common_window = predictors(predictor_index)%response%window
        have_window = .true.
      else if (.not. same_window(common_window, predictors(predictor_index)%response%window)) then
        status = GW_APP_PLAN_WINDOW_MISMATCH
        return
      end if
    end do

    if (.not. canonical_alignment) then
      do i = 1, size(cells)
        area_index = find_area_index(cell_areas, cells(i)%groundwater_cell_id)
        if (area_index <= 0) then
          status = GW_APP_PLAN_MISSING_AREA_CELL
          return
        end if
      end do
    end if

    allocate(plan%tiles(size(tiles)))
    allocate(plan%tile_swap_origin_revisions(size(tiles)))
    allocate(plan%cells(size(cells)))
    allocate(plan%api(size(api)))
    plan%tiles = tiles
    do i = 1, size(tiles)
      if (canonical_alignment) then
        predictor_index = i
      else
        predictor_index = find_predictor_index(predictors, tiles(i)%tile_id)
        if (predictor_index <= 0) then
          status = GW_APP_PLAN_MISSING_PREDICTOR_TILE
          return
        end if
      end if
      plan%tile_swap_origin_revisions(i) = predictors(predictor_index)%response%lineage%swap_origin_revision
    end do
    plan%api = api
    plan%window_value = common_window

    first_tile = 1
    do i = 1, size(cells)
      if (canonical_alignment) then
        if (first_tile > size(tiles) .or. tiles(first_tile)%groundwater_cell_id /= cells(i)%groundwater_cell_id) then
          status = GW_APP_PLAN_BINDING_FAILED
          return
        end if
        binding_count = 0
        idx = first_tile
        do while (idx <= size(tiles))
          if (tiles(idx)%groundwater_cell_id /= cells(i)%groundwater_cell_id) exit
          binding_count = binding_count + 1
          idx = idx + 1
        end do
        if (binding_count <= 0) then
          status = GW_APP_PLAN_BINDING_FAILED
          return
        end if
        allocate(bindings(binding_count), cell_responses(binding_count))
        do k = 1, binding_count
          idx = first_tile + k - 1
          bindings(k)%groundwater_cell_id = cells(i)%groundwater_cell_id
          bindings(k)%tile_id = tiles(idx)%tile_id
          bindings(k)%area_fraction = tiles(idx)%area_fraction
          cell_responses(k) = predictors(idx)%response
        end do
      else
        call topology%direct_bindings_for_cell(cells(i)%groundwater_cell_id, bindings, topology_status)
        if (topology_status /= GW_TOPOLOGY_OK .or. .not. allocated(bindings)) then
          status = GW_APP_PLAN_BINDING_FAILED
          return
        end if
        allocate(cell_responses(size(bindings)))
        do k = 1, size(bindings)
          predictor_index = find_predictor_index(predictors, bindings(k)%tile_id)
          if (predictor_index <= 0) then
            status = GW_APP_PLAN_MISSING_PREDICTOR_TILE
            return
          end if
          cell_responses(k) = predictors(predictor_index)%response
        end do
      end if

      reference_head = 0.0_real64
      compensation = 0.0_real64
      do k = 1, size(bindings)
        term = bindings(k)%area_fraction * cell_responses(k)%h_bot_end_m
        y = term - compensation
        t = reference_head + y
        compensation = (t - reference_head) - y
        reference_head = t
      end do

      plan%cells(i)%topology = cells(i)
      plan%cells(i)%tile_begin = first_tile
      plan%cells(i)%tile_count = size(bindings)
      plan%cells(i)%reference_head_m = reference_head

      call compose_modflow6_multiswap_cell_response(bindings, cell_responses, reference_head, &
           plan%cells(i)%response, status)
      if (status /= MODFLOW6_MULTI_CELL_OK .or. .not. plan%cells(i)%response%valid) then
        status = GW_APP_PLAN_CELL_RESPONSE_FAILED
        return
      end if

      if (plan%cells(i)%response%coupling_id /= cells(i)%coupling_id .or. &
          plan%cells(i)%response%groundwater_service_id /= cells(i)%groundwater_service_id .or. &
          plan%cells(i)%response%groundwater_lineage_id /= cells(i)%groundwater_lineage_id) then
        status = GW_APP_PLAN_PREDICTOR_CELL_MISMATCH
        return
      end if

      if (canonical_alignment) then
        area_index = i
      else
        area_index = find_area_index(cell_areas, cells(i)%groundwater_cell_id)
      end if
      call compose_modflow6_linear_boundary_term(plan%cells(i)%response, cell_areas(area_index)%cell_area_m2, &
           plan%cells(i)%linear_term, status)
      if (status /= MODFLOW6_LINEAR_BACKEND_OK .or. .not. plan%cells(i)%linear_term%valid) then
        status = GW_APP_PLAN_LINEAR_TERM_FAILED
        return
      end if

      if (.not. plan%cells(i)%valid()) then
        status = GW_APP_PLAN_INTERNAL_ORDER_FAILED
        return
      end if
      if (first_tile > size(tiles)) then
        status = GW_APP_PLAN_INTERNAL_ORDER_FAILED
        return
      end if
      if (tiles(first_tile)%groundwater_cell_id /= cells(i)%groundwater_cell_id) then
        status = GW_APP_PLAN_INTERNAL_ORDER_FAILED
        return
      end if
      if (first_tile + size(bindings) - 1 > size(tiles)) then
        status = GW_APP_PLAN_INTERNAL_ORDER_FAILED
        return
      end if
      do k = first_tile, first_tile + size(bindings) - 1
        if (tiles(k)%groundwater_cell_id /= cells(i)%groundwater_cell_id) then
          status = GW_APP_PLAN_INTERNAL_ORDER_FAILED
          return
        end if
      end do
      first_tile = first_tile + size(bindings)

      deallocate(bindings)
      deallocate(cell_responses)
    end do

    if (first_tile /= size(tiles) + 1) then
      status = GW_APP_PLAN_INTERNAL_ORDER_FAILED
      return
    end if

    plan%materialized = .true.
    status = GW_APP_PLAN_OK
  end subroutine materialize_groundwater_application_plan

  pure logical function application_plan_ready(self) result(ready)
    class(groundwater_application_plan_t), intent(in) :: self
    integer :: i

    ready = self%materialized .and. allocated(self%tiles) .and. allocated(self%tile_swap_origin_revisions) .and. &
         allocated(self%cells) .and. allocated(self%api)
    if (.not. ready) return
    if (size(self%tiles) <= 0 .or. size(self%tile_swap_origin_revisions) /= size(self%tiles) .or. &
        any(self%tile_swap_origin_revisions < 0_int64) .or. size(self%cells) <= 0 .or. &
        size(self%api) /= size(self%cells)) then
      ready = .false.
      return
    end if
    if (.not. self%window_value%valid()) then
      ready = .false.
      return
    end if
    do i = 1, size(self%cells)
      if (.not. self%cells(i)%valid()) then
        ready = .false.
        return
      end if
    end do
  end function application_plan_ready

  pure integer function application_plan_tile_count(self) result(count)
    class(groundwater_application_plan_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = size(self%tiles)
  end function application_plan_tile_count

  pure integer function application_plan_cell_count(self) result(count)
    class(groundwater_application_plan_t), intent(in) :: self
    count = 0
    if (.not. self%ready()) return
    count = size(self%cells)
  end function application_plan_cell_count

  subroutine application_plan_window(self, window, available)
    class(groundwater_application_plan_t), intent(in) :: self
    type(groundwater_coupling_window_t), intent(out) :: window
    logical, intent(out) :: available

    window = groundwater_coupling_window_t()
    available = self%ready()
    if (available) window = self%window_value
  end subroutine application_plan_window

  subroutine application_plan_copy_tiles(self, tiles, status)
    class(groundwater_application_plan_t), intent(in) :: self
    type(groundwater_topology_tile_t), allocatable, intent(out) :: tiles(:)
    integer, intent(out) :: status

    status = GW_APP_PLAN_INVALID_TOPOLOGY
    if (.not. self%ready()) return
    allocate(tiles(size(self%tiles)))
    tiles = self%tiles
    status = GW_APP_PLAN_OK
  end subroutine application_plan_copy_tiles

  subroutine application_plan_copy_tile_swap_origin_revisions(self, revisions, status)
    class(groundwater_application_plan_t), intent(in) :: self
    integer(int64), allocatable, intent(out) :: revisions(:)
    integer, intent(out) :: status

    status = GW_APP_PLAN_INVALID_TOPOLOGY
    if (.not. self%ready()) return
    allocate(revisions(size(self%tile_swap_origin_revisions)))
    revisions = self%tile_swap_origin_revisions
    status = GW_APP_PLAN_OK
  end subroutine application_plan_copy_tile_swap_origin_revisions

  subroutine application_plan_copy_cells(self, cells, status)
    class(groundwater_application_plan_t), intent(in) :: self
    type(groundwater_application_cell_plan_t), allocatable, intent(out) :: cells(:)
    integer, intent(out) :: status

    status = GW_APP_PLAN_INVALID_TOPOLOGY
    if (.not. self%ready()) return
    allocate(cells(size(self%cells)))
    cells = self%cells
    status = GW_APP_PLAN_OK
  end subroutine application_plan_copy_cells

  subroutine application_plan_copy_linear_terms(self, terms, status)
    class(groundwater_application_plan_t), intent(in) :: self
    type(modflow6_linear_boundary_term_t), allocatable, intent(out) :: terms(:)
    integer, intent(out) :: status
    integer :: i

    status = GW_APP_PLAN_INVALID_TOPOLOGY
    if (.not. self%ready()) return
    allocate(terms(size(self%cells)))
    do i = 1, size(self%cells)
      terms(i) = self%cells(i)%linear_term
    end do
    status = GW_APP_PLAN_OK
  end subroutine application_plan_copy_linear_terms

  subroutine application_plan_copy_api_bindings(self, bindings, status)
    class(groundwater_application_plan_t), intent(in) :: self
    type(modflow6_api_slot_binding_t), allocatable, intent(out) :: bindings(:)
    integer, intent(out) :: status

    status = GW_APP_PLAN_INVALID_TOPOLOGY
    if (.not. self%ready()) return
    allocate(bindings(size(self%api)))
    bindings = self%api
    status = GW_APP_PLAN_OK
  end subroutine application_plan_copy_api_bindings

  pure integer function find_predictor_index(predictors, tile_id) result(index)
    type(groundwater_tile_predictor_input_t), intent(in) :: predictors(:)
    integer(int64), intent(in) :: tile_id
    integer :: i

    index = 0
    do i = 1, size(predictors)
      if (predictors(i)%tile_id == tile_id) then
        index = i
        return
      end if
    end do
  end function find_predictor_index

  pure integer function find_area_index(cell_areas, cell_id) result(index)
    type(groundwater_cell_area_input_t), intent(in) :: cell_areas(:)
    integer(int64), intent(in) :: cell_id
    integer :: i

    index = 0
    do i = 1, size(cell_areas)
      if (cell_areas(i)%groundwater_cell_id == cell_id) then
        index = i
        return
      end if
    end do
  end function find_area_index

  pure integer function find_cell_index(cells, cell_id) result(index)
    type(groundwater_topology_cell_t), intent(in) :: cells(:)
    integer(int64), intent(in) :: cell_id
    integer :: i

    index = 0
    do i = 1, size(cells)
      if (cells(i)%groundwater_cell_id == cell_id) then
        index = i
        return
      end if
    end do
  end function find_cell_index

  pure logical function same_window(a, b) result(matches)
    type(groundwater_coupling_window_t), intent(in) :: a, b

    matches = same_real(a%t0, b%t0) .and. same_real(a%t1, b%t1)
  end function same_window

  pure logical function same_real(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a - b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_real

end module mod_groundwater_application_plan
