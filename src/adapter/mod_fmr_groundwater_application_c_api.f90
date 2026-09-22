module mod_fmr_groundwater_application_c_api
  use, intrinsic :: iso_c_binding, only: c_double, c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, &
       FMR_GW_APP_CONTEXT_OK, FMR_GW_APP_CONTEXT_INVALID_REQUEST
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t
  implicit none
  private

  integer, parameter, public :: FMR_GW_APP_C_API_OK = 0
  integer, parameter, public :: FMR_GW_APP_C_API_INVALID_CONTEXT = 100
  integer, parameter, public :: FMR_GW_APP_C_API_CONTEXT_BUSY = 101
  integer, parameter, public :: FMR_GW_APP_C_API_HANDLE_EXHAUSTED = 102
  integer, parameter :: INITIAL_CONTEXT_CAPACITY = 8

  type :: context_slot_t
    logical :: active = .false.
    integer(int64) :: handle_id = 0_int64
    type(fmr_groundwater_application_context_t), pointer :: context => null()
  end type context_slot_t

  type(context_slot_t), allocatable, save :: slots(:)
  integer(int64), save :: next_handle = 1_int64

  public :: register_fmr_groundwater_application_context
  public :: release_fmr_groundwater_application_context
  public :: fgc49d_context_counts_c
  public :: fgc49d_plan_view_c
  public :: fgc49d_tile_view_c
  public :: fgc49d_capture_origins_c
  public :: fgc49d_evaluate_groundwater_fluxes_c
  public :: fgc49d_trial_cell_heads_c
  public :: fgc49d_trial_response_tangents_c
  public :: fgc49d_discard_candidates_c
  public :: fgc49d_reanchor_terms_c
  public :: fgc49d_relinearize_terms_c
  public :: fgc49d_swap_preflight_c
  public :: fgc49d_prepare_ledgers_c
  public :: fgc49d_ledgers_preflight_c
  public :: fgc49d_abort_prepublication_c
  public :: fgc49d_commit_swaps_c
  public :: fgc49d_commit_ledgers_c
  public :: fgc49d_release_context_c

contains

  subroutine register_fmr_groundwater_application_context(context, handle, status)
    type(fmr_groundwater_application_context_t), target, intent(inout) :: context
    integer(int64), intent(out) :: handle
    integer, intent(out) :: status

    type(context_slot_t), allocatable :: grown(:)
    integer :: i, slot, old_size, new_size, alloc_status

    handle = 0_int64
    status = FMR_GW_APP_C_API_INVALID_CONTEXT
    if (.not. context%ready()) return

    if (.not. allocated(slots)) then
      allocate(slots(INITIAL_CONTEXT_CAPACITY), stat=alloc_status)
      if (alloc_status /= 0) return
    end if

    do i = 1, size(slots)
      if (.not. slots(i)%active) cycle
      if (associated(slots(i)%context, context)) return
    end do

    slot = 0
    do i = 1, size(slots)
      if (.not. slots(i)%active) then
        slot = i
        exit
      end if
    end do

    if (slot == 0) then
      old_size = size(slots)
      if (old_size > huge(old_size) - max(old_size, INITIAL_CONTEXT_CAPACITY)) return
      new_size = old_size + max(old_size, INITIAL_CONTEXT_CAPACITY)
      allocate(grown(new_size), stat=alloc_status)
      if (alloc_status /= 0) return
      grown(1:old_size) = slots
      call move_alloc(grown, slots)
      slot = old_size + 1
    end if

    if (next_handle <= 0_int64 .or. next_handle >= huge(0_int64)) then
      status = FMR_GW_APP_C_API_HANDLE_EXHAUSTED
      return
    end if

    slots(slot)%active = .true.
    slots(slot)%handle_id = next_handle
    slots(slot)%context => context
    handle = next_handle
    next_handle = next_handle + 1_int64
    status = FMR_GW_APP_C_API_OK
  end subroutine register_fmr_groundwater_application_context

  subroutine release_fmr_groundwater_application_context(handle, status)
    integer(int64), intent(in) :: handle
    integer, intent(out) :: status

    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot

    call resolve_context(handle, context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) return
    if (.not. context%quiescent()) then
      status = FMR_GW_APP_C_API_CONTEXT_BUSY
      return
    end if
    slots(slot)%active = .false.
    nullify(slots(slot)%context)
    status = FMR_GW_APP_C_API_OK
  end subroutine release_fmr_groundwater_application_context

  integer(c_int) function fgc49d_context_counts_c(handle, ncell, ntile) &
       bind(C, name="fgc49d_context_counts_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), intent(out) :: ncell, ntile

    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    ncell = 0_c_int
    ntile = 0_c_int
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    ncell = int(context%cell_count(), c_int)
    ntile = int(context%tile_count(), c_int)
    c_status = int(FMR_GW_APP_C_API_OK, c_int)
  end function fgc49d_context_counts_c

  integer(c_int) function fgc49d_plan_view_c(handle, n, cell_ids, binding_cell_ids, package_slots, modflow_node_ids, &
       term_cell_ids, term_hcof, term_rhs) bind(C, name="fgc49d_plan_view_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    integer(c_int64_t), intent(out) :: cell_ids(*), binding_cell_ids(*), term_cell_ids(*)
    integer(c_int), intent(out) :: package_slots(*), modflow_node_ids(*)
    real(c_double), intent(out) :: term_hcof(*), term_rhs(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    type(modflow6_api_slot_binding_t), allocatable :: bindings(:)
    type(modflow6_linear_boundary_term_t), allocatable :: terms(:)
    integer(int64), allocatable :: ids(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%cell_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if

    call context%copy_plan_view(bindings, terms, ids, status)
    if (status /= FMR_GW_APP_CONTEXT_OK) then
      c_status = int(status, c_int)
      return
    end if
    do i = 1, n_local
      cell_ids(i) = int(ids(i), c_int64_t)
      binding_cell_ids(i) = int(bindings(i)%groundwater_cell_id, c_int64_t)
      package_slots(i) = int(bindings(i)%package_slot, c_int)
      modflow_node_ids(i) = int(bindings(i)%modflow_node_id, c_int)
      term_cell_ids(i) = int(terms(i)%groundwater_cell_id, c_int64_t)
      term_hcof(i) = real(terms(i)%hcof_m2_per_day, c_double)
      term_rhs(i) = real(terms(i)%rhs_m3_per_day, c_double)
    end do
    c_status = int(FMR_GW_APP_C_API_OK, c_int)
  end function fgc49d_plan_view_c

  integer(c_int) function fgc49d_tile_view_c(handle, n, tile_ids, cell_ids, ledger_ids, participant_handles, &
       area_fractions) bind(C, name="fgc49d_tile_view_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    integer(c_int64_t), intent(out) :: tile_ids(*), cell_ids(*), ledger_ids(*), participant_handles(*)
    real(c_double), intent(out) :: area_fractions(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    type(groundwater_topology_tile_t), allocatable :: tiles(:)
    integer(int64), allocatable :: handles(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%tile_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if

    call context%copy_tile_view(tiles, handles, status)
    if (status /= FMR_GW_APP_CONTEXT_OK) then
      c_status = int(status, c_int)
      return
    end if
    do i = 1, n_local
      tile_ids(i) = int(tiles(i)%tile_id, c_int64_t)
      cell_ids(i) = int(tiles(i)%groundwater_cell_id, c_int64_t)
      ledger_ids(i) = int(tiles(i)%ledger_id, c_int64_t)
      participant_handles(i) = int(handles(i), c_int64_t)
      area_fractions(i) = real(tiles(i)%area_fraction, c_double)
    end do
    c_status = int(FMR_GW_APP_C_API_OK, c_int)
  end function fgc49d_tile_view_c

  integer(c_int) function fgc49d_capture_origins_c(handle) bind(C, name="fgc49d_capture_origins_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) call context%capture_origins(status)
    c_status = int(status, c_int)
  end function fgc49d_capture_origins_c

  integer(c_int) function fgc49d_evaluate_groundwater_fluxes_c(handle, n, heads, fluxes) &
       bind(C, name="fgc49d_evaluate_groundwater_fluxes_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    real(c_double), intent(in) :: heads(*)
    real(c_double), intent(out) :: fluxes(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    real(real64), allocatable :: local_heads(:), local_fluxes(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%cell_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if
    allocate(local_heads(n_local), local_fluxes(n_local))
    do i = 1, n_local
      local_heads(i) = real(heads(i), real64)
    end do
    call context%evaluate_groundwater_fluxes(local_heads, local_fluxes, status)
    if (status == FMR_GW_APP_CONTEXT_OK) then
      do i = 1, n_local
        fluxes(i) = real(local_fluxes(i), c_double)
      end do
    end if
    c_status = int(status, c_int)
  end function fgc49d_evaluate_groundwater_fluxes_c

  integer(c_int) function fgc49d_trial_cell_heads_c(handle, n, heads, fluxes) &
       bind(C, name="fgc49d_trial_cell_heads_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    real(c_double), intent(in) :: heads(*)
    real(c_double), intent(out) :: fluxes(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    real(real64), allocatable :: local_heads(:), local_fluxes(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%cell_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if
    allocate(local_heads(n_local), local_fluxes(n_local))
    do i = 1, n_local
      local_heads(i) = real(heads(i), real64)
    end do
    call context%trial_cell_heads(local_heads, local_fluxes, status)
    if (status == FMR_GW_APP_CONTEXT_OK) then
      do i = 1, n_local
        fluxes(i) = real(local_fluxes(i), c_double)
      end do
    end if
    c_status = int(status, c_int)
  end function fgc49d_trial_cell_heads_c

  integer(c_int) function fgc49d_trial_response_tangents_c(handle, n, tangents) &
       bind(C, name="fgc49d_trial_response_tangents_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    real(c_double), intent(out) :: tangents(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    real(real64), allocatable :: local_tangents(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%cell_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if
    allocate(local_tangents(n_local))
    call context%trial_response_tangents(local_tangents, status)
    if (status == FMR_GW_APP_CONTEXT_OK) then
      do i = 1, n_local
        tangents(i) = real(local_tangents(i), c_double)
      end do
    end if
    c_status = int(status, c_int)
  end function fgc49d_trial_response_tangents_c

  integer(c_int) function fgc49d_discard_candidates_c(handle) &
       bind(C, name="fgc49d_discard_candidates_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) call context%discard_candidates(status)
    c_status = int(status, c_int)
  end function fgc49d_discard_candidates_c

  integer(c_int) function fgc49d_reanchor_terms_c(handle, n, heads, fluxes) &
       bind(C, name="fgc49d_reanchor_terms_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    real(c_double), intent(in) :: heads(*), fluxes(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    real(real64), allocatable :: local_heads(:), local_fluxes(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%cell_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if
    allocate(local_heads(n_local), local_fluxes(n_local))
    do i = 1, n_local
      local_heads(i) = real(heads(i), real64)
      local_fluxes(i) = real(fluxes(i), real64)
    end do
    call context%reanchor_terms(local_heads, local_fluxes, status)
    c_status = int(status, c_int)
  end function fgc49d_reanchor_terms_c

  integer(c_int) function fgc49d_relinearize_terms_c(handle, n, heads, fluxes, tangents) &
       bind(C, name="fgc49d_relinearize_terms_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), value, intent(in) :: n
    real(c_double), intent(in) :: heads(*), fluxes(*), tangents(*)

    type(fmr_groundwater_application_context_t), pointer :: context
    real(real64), allocatable :: local_heads(:), local_fluxes(:), local_tangents(:)
    integer :: i, slot, status, n_local

    n_local = int(n)
    call resolve_context(int(handle, int64), context, slot, status)
    if (status /= FMR_GW_APP_C_API_OK) then
      c_status = int(status, c_int)
      return
    end if
    if (n_local /= context%cell_count() .or. n_local <= 0) then
      c_status = int(FMR_GW_APP_CONTEXT_INVALID_REQUEST, c_int)
      return
    end if
    allocate(local_heads(n_local), local_fluxes(n_local), local_tangents(n_local))
    do i = 1, n_local
      local_heads(i) = real(heads(i), real64)
      local_fluxes(i) = real(fluxes(i), real64)
      local_tangents(i) = real(tangents(i), real64)
    end do
    call context%relinearize_terms(local_heads, local_fluxes, local_tangents, status)
    c_status = int(status, c_int)
  end function fgc49d_relinearize_terms_c

  integer(c_int) function fgc49d_swap_preflight_c(handle, ready) &
       bind(C, name="fgc49d_swap_preflight_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), intent(out) :: ready
    type(fmr_groundwater_application_context_t), pointer :: context
    logical :: local_ready
    integer :: slot, status

    ready = 0_c_int
    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) then
      call context%swap_preflight(local_ready, status)
      if (local_ready) ready = 1_c_int
    end if
    c_status = int(status, c_int)
  end function fgc49d_swap_preflight_c

  integer(c_int) function fgc49d_prepare_ledgers_c(handle) bind(C, name="fgc49d_prepare_ledgers_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) call context%prepare_ledgers(status)
    c_status = int(status, c_int)
  end function fgc49d_prepare_ledgers_c

  integer(c_int) function fgc49d_ledgers_preflight_c(handle, ready) &
       bind(C, name="fgc49d_ledgers_preflight_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer(c_int), intent(out) :: ready
    type(fmr_groundwater_application_context_t), pointer :: context
    logical :: local_ready
    integer :: slot, status

    ready = 0_c_int
    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) then
      call context%ledgers_preflight(local_ready, status)
      if (local_ready) ready = 1_c_int
    end if
    c_status = int(status, c_int)
  end function fgc49d_ledgers_preflight_c

  integer(c_int) function fgc49d_abort_prepublication_c(handle) &
       bind(C, name="fgc49d_abort_prepublication_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) call context%abort_prepublication(status)
    c_status = int(status, c_int)
  end function fgc49d_abort_prepublication_c

  integer(c_int) function fgc49d_commit_swaps_c(handle) bind(C, name="fgc49d_commit_swaps_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) call context%commit_swaps(status)
    c_status = int(status, c_int)
  end function fgc49d_commit_swaps_c

  integer(c_int) function fgc49d_commit_ledgers_c(handle) bind(C, name="fgc49d_commit_ledgers_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer :: context
    integer :: slot, status

    call resolve_context(int(handle, int64), context, slot, status)
    if (status == FMR_GW_APP_C_API_OK) call context%commit_ledgers(status)
    c_status = int(status, c_int)
  end function fgc49d_commit_ledgers_c

  integer(c_int) function fgc49d_release_context_c(handle) bind(C, name="fgc49d_release_context_c") result(c_status)
    integer(c_int64_t), value, intent(in) :: handle
    integer :: status

    call release_fmr_groundwater_application_context(int(handle, int64), status)
    c_status = int(status, c_int)
  end function fgc49d_release_context_c

  subroutine resolve_context(handle, context, slot, status)
    integer(int64), intent(in) :: handle
    type(fmr_groundwater_application_context_t), pointer, intent(out) :: context
    integer, intent(out) :: slot
    integer, intent(out) :: status

    integer :: i

    nullify(context)
    slot = 0
    status = FMR_GW_APP_C_API_INVALID_CONTEXT
    if (handle <= 0_int64 .or. .not. allocated(slots)) return
    do i = 1, size(slots)
      if (.not. slots(i)%active) cycle
      if (slots(i)%handle_id /= handle) cycle
      if (.not. associated(slots(i)%context)) return
      if (.not. slots(i)%context%ready()) return
      context => slots(i)%context
      slot = i
      status = FMR_GW_APP_C_API_OK
      return
    end do
  end subroutine resolve_context

end module mod_fmr_groundwater_application_c_api
