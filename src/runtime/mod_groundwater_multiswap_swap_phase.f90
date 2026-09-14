module mod_groundwater_multiswap_swap_phase
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_candidate_state_t, kernel_executor_t, kernel_result_t, kernel_diagnostics_t
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, GW_SWAP_FORCING_OK
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, pair_groundwater_flux_from_swap, GW_INTERFACE_OK
  use mod_groundwater_tile_aggregation, only: groundwater_tile_exchange_t, groundwater_cell_exchange_t, &
       aggregate_groundwater_cell_tiles, GW_TILE_COMPONENT_SWAP, GW_TILE_AGG_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_groundwater_multiswap_topology, only: same_multiswap_time
  implicit none
  private

  integer, parameter, public :: GW_MULTI_PHASE_OK = 0
  integer, parameter, public :: GW_MULTI_PHASE_FORCING_FAILED = 1
  integer, parameter, public :: GW_MULTI_PHASE_SWAP_FAILED = 2
  integer, parameter, public :: GW_MULTI_PHASE_EXCHANGE_FAILED = 3
  integer, parameter, public :: GW_MULTI_PHASE_AGGREGATION_FAILED = 4

  public :: validate_multiswap_area_topology
  public :: run_multiswap_swap_phase

contains

  subroutine validate_multiswap_area_topology(bindings, origins, order, groundwater_cell_id, aggregate, status)
    type(groundwater_direct_tile_binding_t), intent(in) :: bindings(:)
    type(groundwater_coupling_origin_t), intent(in) :: origins(:)
    integer, intent(in) :: order(:)
    integer(kind=8), intent(in) :: groundwater_cell_id
    type(groundwater_cell_exchange_t), intent(out) :: aggregate
    integer, intent(out) :: status
    type(groundwater_tile_exchange_t), allocatable :: tiles(:)
    integer :: k, idx

    allocate(tiles(size(bindings)))
    do k = 1, size(order)
      idx = order(k)
      call fill_tile(bindings(idx), origins(idx), 0.0_real64, tiles(k))
    end do
    call aggregate_groundwater_cell_tiles(groundwater_cell_id, tiles, aggregate, status)
  end subroutine validate_multiswap_area_topology

  subroutine run_multiswap_swap_phase(executor, parameters, committed, checkpoints, bindings, origins, order, &
       materializer, numerical, datum, window, prescribed_head_m, candidates, results, diagnostics, aggregate, &
       failing_index, phase_status)
    type(kernel_executor_t), intent(inout) :: executor
    class(kernel_parameters_t), intent(in) :: parameters(:)
    type(kernel_committed_state_t), intent(inout) :: committed(:)
    type(kernel_checkpoint_t), intent(in) :: checkpoints(:)
    type(groundwater_direct_tile_binding_t), intent(in) :: bindings(:)
    type(groundwater_coupling_origin_t), intent(in) :: origins(:)
    integer, intent(in) :: order(:)
    class(groundwater_swap_forcing_materializer_t), intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: prescribed_head_m
    type(kernel_candidate_state_t), intent(inout) :: candidates(:)
    type(kernel_result_t), intent(out) :: results(:)
    type(kernel_diagnostics_t), intent(inout) :: diagnostics(:)
    type(groundwater_cell_exchange_t), intent(out) :: aggregate
    integer, intent(out) :: failing_index
    integer, intent(out) :: phase_status

    class(canonical_forcing_t), allocatable :: forcing
    type(groundwater_tile_exchange_t), allocatable :: tiles(:)
    real(real64) :: q_swap, q_groundwater
    integer :: k, idx, status

    phase_status = GW_MULTI_PHASE_OK
    failing_index = 0
    allocate(tiles(size(bindings)))

    do k = 1, size(order)
      idx = order(k)
      if (allocated(forcing)) deallocate(forcing)
      call materializer%materialize(prescribed_head_m, datum, forcing, status)
      if (status /= GW_SWAP_FORCING_OK .or. .not. allocated(forcing)) then
        failing_index = idx
        phase_status = GW_MULTI_PHASE_FORCING_FAILED
        return
      end if

      call executor%advance_interval(parameters(idx), committed(idx), forcing, numerical, window%t0, window%t1, &
           results(idx), candidates(idx), diagnostics(idx), checkpoint=checkpoints(idx))
      if (.not. accepted_whole_window_result(results(idx), window, candidates(idx))) then
        failing_index = idx
        phase_status = GW_MULTI_PHASE_SWAP_FAILED
        return
      end if

      call whole_window_exchange_to_flux_pair(results(idx)%bottom_outward_exchange_native, window, &
           q_swap, q_groundwater, status)
      if (status /= GW_INTERFACE_OK) then
        failing_index = idx
        phase_status = GW_MULTI_PHASE_EXCHANGE_FAILED
        return
      end if
      call fill_tile(bindings(idx), origins(idx), q_swap, tiles(k))
    end do

    call aggregate_groundwater_cell_tiles(bindings(order(1))%groundwater_cell_id, tiles, aggregate, status)
    if (status /= GW_TILE_AGG_OK) then
      phase_status = GW_MULTI_PHASE_AGGREGATION_FAILED
      return
    end if
  end subroutine run_multiswap_swap_phase

  subroutine fill_tile(binding, origin, q_swap, tile)
    type(groundwater_direct_tile_binding_t), intent(in) :: binding
    type(groundwater_coupling_origin_t), intent(in) :: origin
    real(real64), intent(in) :: q_swap
    type(groundwater_tile_exchange_t), intent(out) :: tile

    tile = groundwater_tile_exchange_t()
    tile%groundwater_cell_id = binding%groundwater_cell_id
    tile%tile_id = binding%tile_id
    tile%tile_lineage_id = origin%swap_lineage_id
    tile%component_kind = GW_TILE_COMPONENT_SWAP
    tile%area_fraction = binding%area_fraction
    tile%q_swap_m_per_s = q_swap
  end subroutine fill_tile

  logical function accepted_whole_window_result(swap_result, window, candidate) result(valid)
    type(kernel_result_t), intent(in) :: swap_result
    type(groundwater_coupling_window_t), intent(in) :: window
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64) :: candidate_t0, candidate_t1
    logical :: interval_available

    valid = .false.
    if (.not. swap_result%completed) return
    if (.not. candidate%ready()) return
    if (.not. swap_result%bottom_interface_exchange_available) return
    if (.not. ieee_is_finite(swap_result%bottom_outward_exchange_native)) return
    if (.not. ieee_is_finite(swap_result%terminal_bottom_outward_flux_native)) return
    if (.not. same_multiswap_time(swap_result%requested_t0, window%t0)) return
    if (.not. same_multiswap_time(swap_result%requested_t1, window%t1)) return
    if (.not. same_multiswap_time(swap_result%completed_t, window%t1)) return
    call candidate%origin_interval(candidate_t0, candidate_t1, interval_available)
    if (.not. interval_available) return
    if (.not. same_multiswap_time(candidate_t0, window%t0)) return
    if (.not. same_multiswap_time(candidate_t1, window%t1)) return
    valid = .true.
  end function accepted_whole_window_result

  subroutine whole_window_exchange_to_flux_pair(exchange_cm, window, q_swap_m_per_s, q_groundwater_m_per_s, status)
    real(real64), intent(in) :: exchange_cm
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(out) :: q_swap_m_per_s, q_groundwater_m_per_s
    integer, intent(out) :: status
    real(real64) :: duration_day, qbot_mean_cm_per_day

    q_swap_m_per_s = 0.0_real64
    q_groundwater_m_per_s = 0.0_real64
    status = -1
    if (.not. window%valid() .or. .not. ieee_is_finite(exchange_cm)) return
    duration_day = window%t1 - window%t0
    if (.not. ieee_is_finite(duration_day) .or. duration_day <= 0.0_real64) return
    qbot_mean_cm_per_day = -exchange_cm / duration_day
    if (.not. ieee_is_finite(qbot_mean_cm_per_day)) return
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_mean_cm_per_day, q_swap_m_per_s, status)
    if (status /= GW_INTERFACE_OK) return
    call pair_groundwater_flux_from_swap(q_swap_m_per_s, q_groundwater_m_per_s, status)
  end subroutine whole_window_exchange_to_flux_pair

end module mod_groundwater_multiswap_swap_phase
