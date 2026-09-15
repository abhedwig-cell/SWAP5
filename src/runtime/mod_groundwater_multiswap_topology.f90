module mod_groundwater_multiswap_topology
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_trial_result_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, GW_MULTI_OK, &
       GW_MULTI_INVALID_REQUEST, GW_MULTI_PUBLICATION_PREFLIGHT_FAILED
  implicit none
  private

  public :: build_canonical_tile_order
  public :: multiswap_origins_consistent
  public :: stage_multiswap_tile_ledger
  public :: make_multiswap_next_origin
  public :: stable_ordered_sum
  public :: committed_ledger_total
  public :: same_multiswap_time
  public :: same_multiswap_mass

contains

  subroutine build_canonical_tile_order(bindings, order, status)
    type(groundwater_direct_tile_binding_t), intent(in) :: bindings(:)
    integer, intent(out) :: order(:)
    integer, intent(out) :: status
    integer :: i, j, key
    integer(int64) :: cell_id

    status = GW_MULTI_INVALID_REQUEST
    if (size(bindings) <= 0 .or. size(order) /= size(bindings)) return
    cell_id = bindings(1)%groundwater_cell_id
    if (cell_id <= 0_int64) return

    do i = 1, size(bindings)
      if (.not. bindings(i)%valid()) return
      if (bindings(i)%groundwater_cell_id /= cell_id) return
      order(i) = i
      do j = 1, i - 1
        if (bindings(j)%tile_id == bindings(i)%tile_id) return
      end do
    end do

    do i = 2, size(order)
      key = order(i)
      j = i - 1
      do while (j >= 1)
        if (bindings(order(j))%tile_id <= bindings(key)%tile_id) exit
        order(j + 1) = order(j)
        j = j - 1
      end do
      order(j + 1) = key
    end do
    status = GW_MULTI_OK
  end subroutine build_canonical_tile_order

  logical function multiswap_origins_consistent(origins, order, window) result(valid)
    type(groundwater_coupling_origin_t), intent(in) :: origins(:)
    integer, intent(in) :: order(:)
    type(groundwater_coupling_window_t), intent(in) :: window
    integer :: i, j, first

    valid = .false.
    if (size(origins) <= 0 .or. size(order) /= size(origins)) return
    first = order(1)
    do i = 1, size(origins)
      if (.not. origins(i)%finite_and_structurally_valid()) return
      if (.not. same_multiswap_time(origins(i)%accepted_time, window%t0)) return
      if (origins(i)%coupling_id /= origins(first)%coupling_id) return
      if (.not. same_real(origins(i)%accepted_h_groundwater_m, origins(first)%accepted_h_groundwater_m)) return
      if (origins(i)%groundwater_service_id /= origins(first)%groundwater_service_id) return
      if (origins(i)%groundwater_lineage_id /= origins(first)%groundwater_lineage_id) return
      if (origins(i)%groundwater_revision /= origins(first)%groundwater_revision) return
      do j = i + 1, size(origins)
        if (origins(j)%swap_lineage_id == origins(i)%swap_lineage_id) return
      end do
    end do
    valid = .true.
  end function multiswap_origins_consistent

  subroutine stage_multiswap_tile_ledger(ledger, window, origin, groundwater_result, weighted_exchange_m, status)
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledger
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_coupling_origin_t), intent(in) :: origin
    type(groundwater_exchange_trial_result_t), intent(in) :: groundwater_result
    real(real64), intent(in) :: weighted_exchange_m
    integer, intent(out) :: status
    type(groundwater_interface_lineage_t) :: lineage

    lineage = groundwater_interface_lineage_t()
    lineage%coupling_id = origin%coupling_id
    lineage%swap_lineage_id = origin%swap_lineage_id
    lineage%swap_origin_revision = origin%swap_revision
    lineage%groundwater_lineage_id = origin%groundwater_lineage_id
    lineage%groundwater_origin_revision = origin%groundwater_revision
    lineage%candidate_revision = groundwater_result%candidate_revision
    call ledger%stage_exchange(window, lineage, weighted_exchange_m, status)
  end subroutine stage_multiswap_tile_ledger

  subroutine make_multiswap_next_origin(origin, window, committed, groundwater_result, next_origin, status)
    type(groundwater_coupling_origin_t), intent(in) :: origin
    type(groundwater_coupling_window_t), intent(in) :: window
    type(kernel_committed_state_t), intent(in) :: committed
    type(groundwater_exchange_trial_result_t), intent(in) :: groundwater_result
    type(groundwater_coupling_origin_t), intent(out) :: next_origin
    integer, intent(out) :: status
    integer(int64) :: current_revision

    next_origin = groundwater_coupling_origin_t()
    status = GW_MULTI_PUBLICATION_PREFLIGHT_FAILED
    current_revision = committed%current_revision()
    if (current_revision < 0_int64 .or. current_revision >= huge(0_int64)) return
    if (.not. ieee_is_finite(groundwater_result%h_groundwater_m)) return
    if (groundwater_result%candidate_revision < 0_int64) return

    next_origin%initialized = .true.
    next_origin%coupling_id = origin%coupling_id
    next_origin%accepted_h_groundwater_m = groundwater_result%h_groundwater_m
    next_origin%accepted_time = window%t1
    next_origin%swap_lineage_id = origin%swap_lineage_id
    next_origin%swap_revision = current_revision + 1_int64
    next_origin%groundwater_service_id = origin%groundwater_service_id
    next_origin%groundwater_lineage_id = origin%groundwater_lineage_id
    next_origin%groundwater_revision = groundwater_result%candidate_revision
    if (.not. next_origin%finite_and_structurally_valid()) return
    status = GW_MULTI_OK
  end subroutine make_multiswap_next_origin

  pure real(real64) function stable_ordered_sum(values, order) result(total)
    real(real64), intent(in) :: values(:)
    integer, intent(in) :: order(:)
    real(real64) :: compensation, y, t
    integer :: k

    total = 0.0_real64
    compensation = 0.0_real64
    do k = 1, size(order)
      y = values(order(k)) - compensation
      t = total + y
      compensation = (t - total) - y
      total = t
    end do
  end function stable_ordered_sum

  real(real64) function committed_ledger_total(snapshots, order) result(total)
    type(groundwater_interface_mass_snapshot_t), intent(in) :: snapshots(:)
    integer, intent(in) :: order(:)
    real(real64), allocatable :: values(:)
    integer :: i

    allocate(values(size(snapshots)))
    do i = 1, size(snapshots)
      values(i) = snapshots(i)%committed_swap_outward_exchange_m
    end do
    total = stable_ordered_sum(values, order)
  end function committed_ledger_total

  pure logical function same_multiswap_mass(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 128.0_real64 * epsilon(1.0_real64) * scale
  end function same_multiswap_mass

  pure logical function same_multiswap_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_multiswap_time

  pure logical function same_real(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_real

end module mod_groundwater_multiswap_topology
