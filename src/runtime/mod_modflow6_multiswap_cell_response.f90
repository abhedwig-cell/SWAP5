module mod_modflow6_multiswap_cell_response
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_response_t, MODFLOW6_PREDICTOR_OK
  implicit none
  private

  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  integer, parameter, public :: MODFLOW6_MULTI_CELL_OK = 0
  integer, parameter, public :: MODFLOW6_MULTI_CELL_INVALID_REQUEST = 1
  integer, parameter, public :: MODFLOW6_MULTI_CELL_INVALID_REFERENCE_HEAD = 2
  integer, parameter, public :: MODFLOW6_MULTI_CELL_INVALID_BINDING = 3
  integer, parameter, public :: MODFLOW6_MULTI_CELL_WRONG_CELL = 4
  integer, parameter, public :: MODFLOW6_MULTI_CELL_DUPLICATE_TILE = 5
  integer, parameter, public :: MODFLOW6_MULTI_CELL_INVALID_RESPONSE = 6
  integer, parameter, public :: MODFLOW6_MULTI_CELL_WINDOW_MISMATCH = 7
  integer, parameter, public :: MODFLOW6_MULTI_CELL_ORIGIN_MISMATCH = 8
  integer, parameter, public :: MODFLOW6_MULTI_CELL_DUPLICATE_SWAP_LINEAGE = 9
  integer, parameter, public :: MODFLOW6_MULTI_CELL_FRACTION_SUM = 10
  integer, parameter, public :: MODFLOW6_MULTI_CELL_NONFINITE = 11
  integer, parameter, public :: MODFLOW6_MULTI_CELL_INVALID_EVALUATION = 12

  type, public :: modflow6_multiswap_tile_response_t
    type(groundwater_direct_tile_binding_t) :: binding
    type(modflow6_swap_predictor_response_t) :: response
    real(real64) :: q_u_at_reference_m_per_s = 0.0_real64
    real(real64) :: weighted_q_u_at_reference_m_per_s = 0.0_real64
    real(real64) :: weighted_u = 0.0_real64
  end type modflow6_multiswap_tile_response_t

  type, public :: modflow6_multiswap_cell_response_t
    integer :: status = MODFLOW6_MULTI_CELL_INVALID_REQUEST
    logical :: valid = .false.
    integer(int64) :: groundwater_cell_id = 0_int64
    type(groundwater_coupling_window_t) :: window
    real(real64) :: reference_head_m = 0.0_real64
    integer(int64) :: coupling_id = 0_int64
    integer(int64) :: groundwater_service_id = 0_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_origin_revision = -1_int64
    integer :: tile_count = 0
    real(real64) :: fraction_sum = 0.0_real64
    real(real64) :: area_weighted_predictor_q_u_m_per_s = 0.0_real64
    real(real64) :: q_u_at_reference_m_per_s = 0.0_real64
    real(real64) :: reference_adjustment_m_per_s = 0.0_real64
    real(real64) :: coupling_storage_coefficient_u = 0.0_real64
    real(real64) :: dq_u_dh_per_s = 0.0_real64
    type(modflow6_multiswap_tile_response_t), allocatable :: tiles(:)
  end type modflow6_multiswap_cell_response_t

  public :: compose_modflow6_multiswap_cell_response
  public :: evaluate_modflow6_multiswap_cell_response

contains

  subroutine compose_modflow6_multiswap_cell_response(bindings, responses, reference_head_m, cell, status)
    type(groundwater_direct_tile_binding_t), intent(in) :: bindings(:)
    type(modflow6_swap_predictor_response_t), intent(in) :: responses(:)
    real(real64), intent(in) :: reference_head_m
    type(modflow6_multiswap_cell_response_t), intent(out) :: cell
    integer, intent(out) :: status

    integer, allocatable :: order(:)
    integer :: n, i, j, k, idx, first
    real(real64) :: duration_day, duration_s
    real(real64) :: fraction_total, fraction_compensation
    real(real64) :: raw_q_total, raw_q_compensation
    real(real64) :: q_ref_total, q_ref_compensation
    real(real64) :: u_total, u_compensation
    real(real64) :: q_at_ref, weighted_q, weighted_u, fraction_scale

    cell = modflow6_multiswap_cell_response_t()
    status = MODFLOW6_MULTI_CELL_INVALID_REQUEST

    n = size(bindings)
    if (n <= 0 .or. size(responses) /= n) then
      cell%status = status
      return
    end if

    status = MODFLOW6_MULTI_CELL_INVALID_REFERENCE_HEAD
    if (.not. ieee_is_finite(reference_head_m)) then
      cell%status = status
      return
    end if

    allocate(order(n))
    do i = 1, n
      status = MODFLOW6_MULTI_CELL_INVALID_BINDING
      if (.not. bindings(i)%valid()) then
        cell%status = status
        return
      end if
      order(i) = i
      do j = 1, i - 1
        status = MODFLOW6_MULTI_CELL_DUPLICATE_TILE
        if (bindings(j)%tile_id == bindings(i)%tile_id) then
          cell%status = status
          return
        end if
      end do
    end do

    do i = 2, n
      idx = order(i)
      j = i - 1
      do while (j >= 1)
        if (bindings(order(j))%tile_id <= bindings(idx)%tile_id) exit
        order(j + 1) = order(j)
        j = j - 1
      end do
      order(j + 1) = idx
    end do

    first = order(1)
    status = MODFLOW6_MULTI_CELL_INVALID_RESPONSE
    if (.not. valid_predictor_response(responses(first))) then
      cell%status = status
      return
    end if

    duration_day = responses(first)%window%t1 - responses(first)%window%t0
    duration_s = duration_day * DAY_TO_S
    status = MODFLOW6_MULTI_CELL_NONFINITE
    if (.not. ieee_is_finite(duration_s) .or. duration_s <= 0.0_real64) then
      cell%status = status
      return
    end if

    do i = 1, n
      status = MODFLOW6_MULTI_CELL_WRONG_CELL
      if (bindings(i)%groundwater_cell_id /= bindings(first)%groundwater_cell_id) then
        cell%status = status
        return
      end if

      status = MODFLOW6_MULTI_CELL_INVALID_RESPONSE
      if (.not. valid_predictor_response(responses(i))) then
        cell%status = status
        return
      end if

      status = MODFLOW6_MULTI_CELL_WINDOW_MISMATCH
      if (.not. same_window(responses(i)%window, responses(first)%window)) then
        cell%status = status
        return
      end if

      status = MODFLOW6_MULTI_CELL_ORIGIN_MISMATCH
      if (responses(i)%lineage%coupling_id /= responses(first)%lineage%coupling_id) then
        cell%status = status
        return
      end if
      if (responses(i)%lineage%groundwater_service_id /= responses(first)%lineage%groundwater_service_id) then
        cell%status = status
        return
      end if
      if (responses(i)%lineage%groundwater_lineage_id /= responses(first)%lineage%groundwater_lineage_id) then
        cell%status = status
        return
      end if
      if (responses(i)%lineage%groundwater_origin_revision /= responses(first)%lineage%groundwater_origin_revision) then
        cell%status = status
        return
      end if

      do j = 1, i - 1
        status = MODFLOW6_MULTI_CELL_DUPLICATE_SWAP_LINEAGE
        if (responses(j)%lineage%swap_lineage_id == responses(i)%lineage%swap_lineage_id) then
          cell%status = status
          return
        end if
      end do
    end do

    allocate(cell%tiles(n))
    fraction_total = 0.0_real64
    fraction_compensation = 0.0_real64
    raw_q_total = 0.0_real64
    raw_q_compensation = 0.0_real64
    q_ref_total = 0.0_real64
    q_ref_compensation = 0.0_real64
    u_total = 0.0_real64
    u_compensation = 0.0_real64

    do k = 1, n
      idx = order(k)

      q_at_ref = responses(idx)%q_u_m_per_s + &
           (responses(idx)%coupling_storage_coefficient_u / duration_s) * &
           (reference_head_m - responses(idx)%h_bot_end_m)
      weighted_q = bindings(idx)%area_fraction * q_at_ref
      weighted_u = bindings(idx)%area_fraction * responses(idx)%coupling_storage_coefficient_u

      status = MODFLOW6_MULTI_CELL_NONFINITE
      if (.not. ieee_is_finite(q_at_ref) .or. .not. ieee_is_finite(weighted_q) .or. &
          .not. ieee_is_finite(weighted_u)) then
        cell%status = status
        return
      end if

      cell%tiles(k)%binding = bindings(idx)
      cell%tiles(k)%response = responses(idx)
      cell%tiles(k)%q_u_at_reference_m_per_s = q_at_ref
      cell%tiles(k)%weighted_q_u_at_reference_m_per_s = weighted_q
      cell%tiles(k)%weighted_u = weighted_u

      call compensated_add(fraction_total, fraction_compensation, bindings(idx)%area_fraction)
      call compensated_add(raw_q_total, raw_q_compensation, &
           bindings(idx)%area_fraction * responses(idx)%q_u_m_per_s)
      call compensated_add(q_ref_total, q_ref_compensation, weighted_q)
      call compensated_add(u_total, u_compensation, weighted_u)
    end do

    status = MODFLOW6_MULTI_CELL_FRACTION_SUM
    fraction_scale = max(1.0_real64, abs(fraction_total))
    if (abs(fraction_total - 1.0_real64) > 64.0_real64 * epsilon(1.0_real64) * fraction_scale) then
      cell%status = status
      return
    end if

    status = MODFLOW6_MULTI_CELL_NONFINITE
    if (.not. ieee_is_finite(raw_q_total) .or. .not. ieee_is_finite(q_ref_total) .or. &
        .not. ieee_is_finite(u_total) .or. .not. ieee_is_finite(u_total / duration_s)) then
      cell%status = status
      return
    end if

    cell%groundwater_cell_id = bindings(first)%groundwater_cell_id
    cell%window = responses(first)%window
    cell%reference_head_m = reference_head_m
    cell%coupling_id = responses(first)%lineage%coupling_id
    cell%groundwater_service_id = responses(first)%lineage%groundwater_service_id
    cell%groundwater_lineage_id = responses(first)%lineage%groundwater_lineage_id
    cell%groundwater_origin_revision = responses(first)%lineage%groundwater_origin_revision
    cell%tile_count = n
    cell%fraction_sum = fraction_total
    cell%area_weighted_predictor_q_u_m_per_s = raw_q_total
    cell%q_u_at_reference_m_per_s = q_ref_total
    cell%reference_adjustment_m_per_s = q_ref_total - raw_q_total
    cell%coupling_storage_coefficient_u = u_total
    cell%dq_u_dh_per_s = u_total / duration_s
    cell%status = MODFLOW6_MULTI_CELL_OK
    cell%valid = .true.
    status = MODFLOW6_MULTI_CELL_OK
  end subroutine compose_modflow6_multiswap_cell_response

  subroutine evaluate_modflow6_multiswap_cell_response(cell, hydraulic_head_m, q_u_m_per_s, status)
    type(modflow6_multiswap_cell_response_t), intent(in) :: cell
    real(real64), intent(in) :: hydraulic_head_m
    real(real64), intent(out) :: q_u_m_per_s
    integer, intent(out) :: status

    q_u_m_per_s = 0.0_real64
    status = MODFLOW6_MULTI_CELL_INVALID_EVALUATION
    if (.not. cell%valid .or. cell%status /= MODFLOW6_MULTI_CELL_OK) return
    if (.not. ieee_is_finite(hydraulic_head_m)) return
    if (.not. ieee_is_finite(cell%q_u_at_reference_m_per_s) .or. &
        .not. ieee_is_finite(cell%dq_u_dh_per_s) .or. &
        .not. ieee_is_finite(cell%reference_head_m)) return

    q_u_m_per_s = cell%q_u_at_reference_m_per_s + &
         cell%dq_u_dh_per_s * (hydraulic_head_m - cell%reference_head_m)
    if (.not. ieee_is_finite(q_u_m_per_s)) then
      q_u_m_per_s = 0.0_real64
      return
    end if
    status = MODFLOW6_MULTI_CELL_OK
  end subroutine evaluate_modflow6_multiswap_cell_response

  pure logical function valid_predictor_response(response) result(valid)
    type(modflow6_swap_predictor_response_t), intent(in) :: response

    valid = response%valid .and. response%status == MODFLOW6_PREDICTOR_OK
    if (.not. valid) return
    if (.not. response%window%valid()) then
      valid = .false.
      return
    end if
    if (.not. response%lineage%valid()) then
      valid = .false.
      return
    end if
    if (.not. ieee_is_finite(response%q_u_m_per_s) .or. &
        .not. ieee_is_finite(response%coupling_storage_coefficient_u) .or. &
        .not. ieee_is_finite(response%h_bot_end_m)) then
      valid = .false.
    end if
  end function valid_predictor_response

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

  pure subroutine compensated_add(total, compensation, term)
    real(real64), intent(inout) :: total, compensation
    real(real64), intent(in) :: term
    real(real64) :: y, t

    y = term - compensation
    t = total + y
    compensation = (t - total) - y
    total = t
  end subroutine compensated_add

end module mod_modflow6_multiswap_cell_response
