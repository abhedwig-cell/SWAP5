program pub_gc_e1_primary
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_state_t, groundwater_interface_residual_t, &
       swap_bottom_pressure_head_cm_to_interface_head_m, pair_groundwater_flux_from_swap, &
       evaluate_groundwater_interface_residual, GW_INTERFACE_OK
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, groundwater_capture_checkpoint, &
       groundwater_trial_from_checkpoint, groundwater_discard_candidate, GW_EXCHANGE_OK
  use mod_pub_gc_gw_a, only: pub_gc_gw_a_service_t
  implicit none

  real(real64), parameter :: T0 = 4100.125_real64
  real(real64), parameter :: WINDOW_DAY = 0.05_real64
  real(real64), parameter :: T1 = T0 + WINDOW_DAY
  real(real64), parameter :: HEAD_A_CM = -75.0_real64
  real(real64), parameter :: HEAD_B_CM = -60.0_real64
  real(real64), parameter :: HEAD_C_CM = -90.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-10_real64
  real(real64), parameter :: TEMPORAL_HEAD_BUDGET_CM = 100.0_real64
  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  real(real64), parameter :: CM_TO_M = 0.01_real64
  real(real64), parameter :: GW_AREA_M2 = 1.0_real64
  real(real64), parameter :: GW_SY = 0.20_real64
  real(real64), parameter :: GW_REF_HEAD_M = 0.0_real64
  real(real64), parameter :: GW_EXT_MPS = 0.0_real64
  real(real64), parameter :: GW_INITIAL_HEAD_M = -0.75_real64
  integer(int64), parameter :: SWAP_ORIGIN_LINEAGE = 810001_int64
  integer(int64), parameter :: GW_SERVICE_ID = 820001_int64
  integer(int64), parameter :: GW_ORIGIN_LINEAGE = 820001_int64
  integer(int64), parameter :: DATUM_ID = 810001_int64

  type :: candidate_record_t
    character(len=8) :: symbol = ''
    real(real64) :: prescribed_head_cm = 0.0_real64
    real(real64) :: prescribed_head_m = 0.0_real64
    real(real64) :: q_swap_out_cm = 0.0_real64
    real(real64) :: terminal_bottom_outward_flux = 0.0_real64
    real(real64) :: mass_residual = 0.0_real64
    integer :: retries = 0
    character(len=192) :: endpoint_signature = ''
    real(real64) :: gw_origin_head_m = 0.0_real64
    real(real64) :: gw_candidate_head_m = 0.0_real64
    real(real64) :: gw_volume_change_m3 = 0.0_real64
    real(real64) :: head_residual_m = 0.0_real64
    real(real64) :: gw_analytic_closure_error_m = 0.0_real64
    integer(int64) :: swap_origin_lineage = 0_int64
    integer(int64) :: gw_origin_lineage = 0_int64
    logical :: synthetic_origin = .false.
  end type candidate_record_t

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: accepted_swap
  type(kernel_checkpoint_t) :: accepted_swap_checkpoint
  type(pub_gc_gw_a_service_t) :: accepted_gw
  type(groundwater_exchange_checkpoint_t) :: accepted_gw_checkpoint
  type(groundwater_head_datum_t) :: datum
  type(candidate_record_t) :: same_s1(4), same_s2(4), history_s1(4), history_s2(4)
  class(transaction_state_t), allocatable :: accepted_before, accepted_after
  real(real64) :: conductivity_reference
  real(real64) :: predecessor_right_derivative(numnod)
  real(real64), parameter :: S1_HEADS(4) = [HEAD_A_CM, HEAD_B_CM, HEAD_A_CM, HEAD_C_CM]
  real(real64), parameter :: S2_HEADS(4) = [HEAD_A_CM, HEAD_C_CM, HEAD_A_CM, HEAD_B_CM]
  character(len=1), parameter :: S1_SYMBOLS(4) = ['A','B','A','C']
  character(len=1), parameter :: S2_SYMBOLS(4) = ['A','C','A','B']
  integer :: status
  logical :: ok, available, history_order_difference

  call configure_column(column, template)
  call configure_transaction(config)
  call configure_case(parameters, initial_state, base_forcing, conductivity_reference)
  call backend%initialize(top_provider)

  predecessor_right_derivative = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(accepted_swap, SWAP_ORIGIN_LINEAGE, initial_state, T0, ok, &
       predecessor_right_derivative)
  call require(ok .and. accepted_swap%ready(), 'accepted SWAP origin initialization')
  call accepted_swap%snapshot(accepted_before, available)
  call require(available .and. allocated(accepted_before), 'accepted SWAP origin snapshot')
  call fmr_capture_checkpoint(accepted_swap, accepted_swap_checkpoint, ok)
  call require(ok .and. accepted_swap_checkpoint%ready(), 'accepted SWAP checkpoint')

  datum = groundwater_head_datum_t()
  datum%available = .true.
  datum%datum_id = DATUM_ID
  datum%bottom_boundary_elevation_m = 0.0_real64
  call require(datum%valid(), 'research datum valid')

  call accepted_gw%initialize(GW_SERVICE_ID, GW_ORIGIN_LINEAGE, GW_INITIAL_HEAD_M, T0, GW_AREA_M2, GW_SY, &
       GW_REF_HEAD_M, GW_EXT_MPS, status)
  call require(status == GW_EXCHANGE_OK .and. accepted_gw%is_configured(), 'accepted GW-A origin initialization')
  call groundwater_capture_checkpoint(accepted_gw, accepted_gw_checkpoint, status)
  call require(status == GW_EXCHANGE_OK .and. accepted_gw_checkpoint%ready(), 'accepted GW-A checkpoint')

  call run_same_sequence('S1', S1_HEADS, S1_SYMBOLS, accepted_swap, accepted_swap_checkpoint, accepted_gw, &
       accepted_gw_checkpoint, same_s1)
  call run_same_sequence('S2', S2_HEADS, S2_SYMBOLS, accepted_swap, accepted_swap_checkpoint, accepted_gw, &
       accepted_gw_checkpoint, same_s2)

  call require(records_identical(same_s1(1), same_s1(3)), 'same S1 repeated A exact identity')
  call require(records_identical(same_s1(1), same_s2(1)), 'same S1/S2 initial A exact identity')
  call require(records_identical(same_s1(1), same_s2(3)), 'same S1/S2 repeated A exact identity')
  call require(records_identical(same_s1(2), same_s2(4)), 'same B order independence')
  call require(records_identical(same_s1(4), same_s2(2)), 'same C order independence')
  call require(accepted_gw%current_revision() == 0_int64, 'same-origin GW-A revision mutation')
  call require(same_bits(accepted_gw%accepted_head_m(), GW_INITIAL_HEAD_M), 'same-origin GW-A head mutation')
  call require(same_bits(accepted_gw%accepted_time_day(), T0), 'same-origin GW-A time mutation')
  write(*,'(a)') 'PUB_GC_E1_PRIMARY_SAME_ORIGIN_ORDER_INDEPENDENCE=PASS'
  write(*,'(a)') 'PUB_GC_E1_PRIMARY_SAME_ORIGIN_GW_UNCHANGED=PASS'

  call run_history_sequence('S1', S1_HEADS, S1_SYMBOLS, 1, accepted_swap, accepted_swap_checkpoint, history_s1)
  call run_history_sequence('S2', S2_HEADS, S2_SYMBOLS, 2, accepted_swap, accepted_swap_checkpoint, history_s2)

  call accepted_swap%snapshot(accepted_after, available)
  call require(available .and. states_identical(accepted_before, accepted_after), 'primary run mutated accepted SWAP origin')
  call require(accepted_swap%current_revision() == 0_int64, 'primary run changed accepted SWAP revision')
  write(*,'(a)') 'PUB_GC_E1_PRIMARY_ACCEPTED_SWAP_UNCHANGED=PASS'

  history_order_difference = .not. records_identical(history_s1(3), history_s2(3))
  write(*,'(a,l1)') 'PUB_GC_E1_PRIMARY_HISTORY_ORDER_DIFFERENCE=', history_order_difference
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_PRIMARY_A_AFTER_B_MINUS_A_AFTER_C_Q_CM=', &
       history_s1(3)%q_swap_out_cm-history_s2(3)%q_swap_out_cm
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_PRIMARY_ABS_A_AFTER_B_MINUS_A_AFTER_C_Q_CM=', &
       abs(history_s1(3)%q_swap_out_cm-history_s2(3)%q_swap_out_cm)
  write(*,'(a,l1)') 'PUB_GC_E1_PRIMARY_A_AFTER_B_DIFFERS_FROM_SAME=', .not. records_identical(history_s1(3), same_s1(1))
  write(*,'(a,l1)') 'PUB_GC_E1_PRIMARY_A_AFTER_C_DIFFERS_FROM_SAME=', .not. records_identical(history_s2(3), same_s1(1))
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_PRIMARY_RESIDUAL_A_AFTER_B_M=', history_s1(3)%head_residual_m
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_PRIMARY_RESIDUAL_A_AFTER_C_M=', history_s2(3)%head_residual_m
  write(*,'(a)') 'PUB_GC_E1_PRIMARY_ORACLE=PASS'

contains

  subroutine run_same_sequence(sequence_id, heads, symbols, committed, checkpoint, gw_service, gw_checkpoint, records)
    character(len=*), intent(in) :: sequence_id
    real(real64), intent(in) :: heads(4)
    character(len=1), intent(in) :: symbols(4)
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(pub_gc_gw_a_service_t), intent(inout) :: gw_service
    type(groundwater_exchange_checkpoint_t), intent(in) :: gw_checkpoint
    type(candidate_record_t), intent(out) :: records(4)
    integer :: i

    do i = 1, 4
      call evaluate_swap_candidate(committed, checkpoint, heads(i), records(i))
      records(i)%symbol = symbols(i)
      records(i)%swap_origin_lineage = SWAP_ORIGIN_LINEAGE
      records(i)%gw_origin_lineage = GW_ORIGIN_LINEAGE
      records(i)%synthetic_origin = .false.
      call evaluate_gw_same(gw_service, gw_checkpoint, records(i))
      call print_record('SAME', sequence_id, i, records(i))
    end do
  end subroutine run_same_sequence

  subroutine run_history_sequence(sequence_id, heads, symbols, sequence_number, committed, checkpoint, records)
    character(len=*), intent(in) :: sequence_id
    real(real64), intent(in) :: heads(4)
    character(len=1), intent(in) :: symbols(4)
    integer, intent(in) :: sequence_number
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(candidate_record_t), intent(out) :: records(4)
    type(kernel_committed_state_t) :: synthetic_swap
    type(kernel_checkpoint_t) :: synthetic_checkpoint
    class(transaction_state_t), allocatable :: prior_endpoint, endpoint
    real(real64) :: current_gw_head
    integer(int64) :: swap_lineage, gw_lineage
    integer :: i
    logical :: local_ok

    current_gw_head = GW_INITIAL_HEAD_M

    do i = 1, 4
      if (i == 1) then
        call evaluate_swap_candidate(committed, checkpoint, heads(i), records(i), endpoint)
        records(i)%swap_origin_lineage = SWAP_ORIGIN_LINEAGE
        swap_lineage = SWAP_ORIGIN_LINEAGE
      else
        swap_lineage = 910000_int64 + int(sequence_number*10+i, int64)
        call synthetic_swap%initialize(swap_lineage, prior_endpoint, local_ok, initial_time=T0)
        call require(local_ok .and. synthetic_swap%ready(), 'history synthetic SWAP initialization')
        call fmr_capture_checkpoint(synthetic_swap, synthetic_checkpoint, local_ok)
        call require(local_ok .and. synthetic_checkpoint%ready(), 'history synthetic SWAP checkpoint')
        call evaluate_swap_candidate(synthetic_swap, synthetic_checkpoint, heads(i), records(i), endpoint)
        records(i)%swap_origin_lineage = swap_lineage
      end if

      records(i)%symbol = symbols(i)
      records(i)%synthetic_origin = i > 1
      gw_lineage = merge(GW_ORIGIN_LINEAGE, 920000_int64 + int(sequence_number*10+i, int64), i == 1)
      records(i)%gw_origin_lineage = gw_lineage
      call evaluate_gw_fresh_origin(current_gw_head, gw_lineage, records(i))
      current_gw_head = records(i)%gw_candidate_head_m

      if (allocated(prior_endpoint)) deallocate(prior_endpoint)
      call endpoint%clone(prior_endpoint)
      call require(allocated(prior_endpoint), 'history endpoint clone')
      if (allocated(endpoint)) deallocate(endpoint)

      call print_record('HISTORY', sequence_id, i, records(i))
    end do
  end subroutine run_history_sequence

  subroutine evaluate_swap_candidate(committed, checkpoint, prescribed_head_cm, record, endpoint_out)
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: prescribed_head_cm
    type(candidate_record_t), intent(out) :: record
    class(transaction_state_t), allocatable, intent(out), optional :: endpoint_out
    type(fmr_b110_physical_forcing_t) :: forcing
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diagnostics
    type(kernel_executor_t) :: discard_executor
    class(transaction_state_t), allocatable :: endpoint
    integer :: hstatus
    logical :: endpoint_ok

    forcing = base_forcing
    forcing%bottom_head = prescribed_head_cm
    call poison_legacy_bottom_context()
    call backend%run_trial(column, template, parameters, committed, forcing, config, T0, T1, checkpoint, &
         result, candidate, diagnostics)
    call require(result%completed, 'primary SWAP trial completed')
    call require(candidate%ready(), 'primary SWAP candidate ready')
    call require(result%bottom_interface_exchange_available, 'primary whole-window exchange available')
    call require(ieee_is_finite(result%bottom_outward_exchange_native), 'primary whole-window exchange finite')
    call require(ieee_is_finite(result%terminal_bottom_outward_flux_native), 'primary terminal flux finite')
    call require(result%mass%complete .and. ieee_is_finite(result%mass%residual), 'primary mass accounting')
    call candidate%snapshot(endpoint, endpoint_ok)
    call require(endpoint_ok .and. allocated(endpoint), 'primary endpoint snapshot')

    record = candidate_record_t()
    record%prescribed_head_cm = prescribed_head_cm
    call swap_bottom_pressure_head_cm_to_interface_head_m(prescribed_head_cm, datum, record%prescribed_head_m, hstatus)
    call require(hstatus == GW_INTERFACE_OK, 'primary datum translation')
    record%q_swap_out_cm = result%bottom_outward_exchange_native
    record%terminal_bottom_outward_flux = result%terminal_bottom_outward_flux_native
    record%mass_residual = result%mass%residual
    record%retries = diagnostics%retries
    call make_state_signature(endpoint, record%endpoint_signature, endpoint_ok)
    call require(endpoint_ok, 'primary endpoint signature')

    if (present(endpoint_out)) then
      call endpoint%clone(endpoint_out)
      call require(allocated(endpoint_out), 'primary endpoint output clone')
    end if

    discard_diagnostics = diagnostics
    call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
    call require(.not. candidate%ready(), 'primary SWAP candidate discarded')
  end subroutine evaluate_swap_candidate

  subroutine evaluate_gw_same(service, checkpoint, record)
    type(pub_gc_gw_a_service_t), intent(inout) :: service
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    type(candidate_record_t), intent(inout) :: record
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    integer :: local_status

    record%gw_origin_head_m = GW_INITIAL_HEAD_M
    call evaluate_gw_on_service(service, checkpoint, record, candidate, result)
    record%gw_candidate_head_m = result%h_groundwater_m
    record%gw_volume_change_m3 = service%last_candidate_volume_change_m3()
    call complete_gw_record(record, result%q_groundwater_m_per_s)
    call groundwater_discard_candidate(service, candidate, local_status)
    call require(local_status == GW_EXCHANGE_OK, 'same-origin GW-A discard')
  end subroutine evaluate_gw_same

  subroutine evaluate_gw_fresh_origin(origin_head_m, lineage, record)
    real(real64), intent(in) :: origin_head_m
    integer(int64), intent(in) :: lineage
    type(candidate_record_t), intent(inout) :: record
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    integer :: local_status

    call service%initialize(GW_SERVICE_ID + lineage, lineage, origin_head_m, T0, GW_AREA_M2, GW_SY, GW_REF_HEAD_M, &
         GW_EXT_MPS, local_status)
    call require(local_status == GW_EXCHANGE_OK, 'history GW-A synthetic initialization')
    call groundwater_capture_checkpoint(service, checkpoint, local_status)
    call require(local_status == GW_EXCHANGE_OK .and. checkpoint%ready(), 'history GW-A checkpoint')
    record%gw_origin_head_m = origin_head_m
    call evaluate_gw_on_service(service, checkpoint, record, candidate, result)
    record%gw_candidate_head_m = result%h_groundwater_m
    record%gw_volume_change_m3 = service%last_candidate_volume_change_m3()
    call complete_gw_record(record, result%q_groundwater_m_per_s)
    call groundwater_discard_candidate(service, candidate, local_status)
    call require(local_status == GW_EXCHANGE_OK, 'history GW-A discard')
    call require(service%current_revision() == 0_int64, 'history GW-A synthetic revision mutation')
    call require(same_bits(service%accepted_head_m(), origin_head_m), 'history GW-A synthetic accepted head mutation')
    call require(same_bits(service%accepted_time_day(), T0), 'history GW-A synthetic accepted time mutation')
  end subroutine evaluate_gw_fresh_origin

  subroutine evaluate_gw_on_service(service, checkpoint, record, candidate, result)
    type(pub_gc_gw_a_service_t), intent(inout) :: service
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    type(candidate_record_t), intent(in) :: record
    type(groundwater_exchange_candidate_t), intent(out) :: candidate
    type(groundwater_exchange_trial_result_t), intent(out) :: result
    type(groundwater_coupling_window_t) :: window
    real(real64) :: q_swap_mps, q_gw_mps
    integer :: local_status

    window = groundwater_coupling_window_t()
    window%t0 = T0
    window%t1 = T1
    q_swap_mps = record%q_swap_out_cm * CM_TO_M / (WINDOW_DAY * DAY_TO_S)
    call require(ieee_is_finite(q_swap_mps), 'primary q_swap conversion finite')
    call pair_groundwater_flux_from_swap(q_swap_mps, q_gw_mps, local_status)
    call require(local_status == GW_INTERFACE_OK, 'primary action-reaction pairing')
    call require(same_bits(q_gw_mps, -q_swap_mps), 'primary action-reaction exact')
    call groundwater_trial_from_checkpoint(service, checkpoint, window, q_gw_mps, candidate, result, local_status)
    call require(local_status == GW_EXCHANGE_OK .and. candidate%ready(), 'primary GW-A trial')
  end subroutine evaluate_gw_on_service

  subroutine complete_gw_record(record, q_gw_mps)
    type(candidate_record_t), intent(inout) :: record
    real(real64), intent(in) :: q_gw_mps
    type(groundwater_interface_state_t) :: interface_state
    type(groundwater_interface_residual_t) :: residual
    real(real64) :: dt_s, delta_v, expected_head
    integer :: local_status

    dt_s = WINDOW_DAY * DAY_TO_S
    delta_v = GW_AREA_M2 * (GW_EXT_MPS - q_gw_mps) * dt_s
    expected_head = record%gw_origin_head_m + delta_v / (GW_SY * GW_AREA_M2)
    record%gw_analytic_closure_error_m = record%gw_candidate_head_m - expected_head
    call require(same_bits(record%gw_candidate_head_m, expected_head), 'GW-A analytic bitwise closure')

    interface_state = groundwater_interface_state_t()
    interface_state%h_swap_m = record%prescribed_head_m
    interface_state%h_groundwater_m = record%gw_candidate_head_m
    interface_state%q_swap_m_per_s = -q_gw_mps
    interface_state%q_groundwater_m_per_s = q_gw_mps
    call evaluate_groundwater_interface_residual(interface_state, residual, local_status)
    call require(local_status == GW_INTERFACE_OK, 'primary interface residual evaluation')
    call require(same_bits(residual%flux_residual_m_per_s, 0.0_real64), 'primary exact flux residual')
    record%head_residual_m = residual%head_residual_m
  end subroutine complete_gw_record

  subroutine print_record(policy, sequence_id, index, record)
    character(len=*), intent(in) :: policy, sequence_id
    integer, intent(in) :: index
    type(candidate_record_t), intent(in) :: record

    write(*,'(a,"|",a,"|",a,"|",i0,"|",a,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",a,"|", &
         es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",i0,"|",i0,"|",l1)') &
         'PUB_GC_E1_ROW', trim(policy), trim(sequence_id), index, trim(record%symbol), record%prescribed_head_cm, &
         record%q_swap_out_cm, record%terminal_bottom_outward_flux, trim(record%endpoint_signature), &
         record%gw_origin_head_m, record%gw_candidate_head_m, record%gw_volume_change_m3, record%head_residual_m, &
         record%gw_analytic_closure_error_m, record%mass_residual, record%swap_origin_lineage, &
         record%gw_origin_lineage, record%synthetic_origin
  end subroutine print_record

  logical function records_identical(a, b) result(equal)
    type(candidate_record_t), intent(in) :: a, b

    equal = .false.
    if (.not. same_bits(a%prescribed_head_cm, b%prescribed_head_cm)) return
    if (.not. same_bits(a%q_swap_out_cm, b%q_swap_out_cm)) return
    if (.not. same_bits(a%terminal_bottom_outward_flux, b%terminal_bottom_outward_flux)) return
    if (trim(a%endpoint_signature) /= trim(b%endpoint_signature)) return
    if (.not. same_bits(a%gw_candidate_head_m, b%gw_candidate_head_m)) return
    if (.not. same_bits(a%head_residual_m, b%head_residual_m)) return
    equal = .true.
  end function records_identical

  subroutine make_state_signature(state, signature, valid)
    class(transaction_state_t), allocatable, intent(in) :: state
    character(len=*), intent(out) :: signature
    logical, intent(out) :: valid
    character(len=16) :: part
    integer :: k, pos

    signature = ''
    valid = .false.
    if (.not. allocated(state)) return
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) return
      if (size(physical%pressure_head) /= numnod .or. size(physical%water_content) /= numnod) return
      pos = 1
      do k = 1, numnod
        write(part,'(z16.16)') transfer(physical%pressure_head(k), 0_int64)
        signature(pos:pos+15) = part
        pos = pos + 16
      end do
      do k = 1, numnod
        write(part,'(z16.16)') transfer(physical%water_content(k), 0_int64)
        signature(pos:pos+15) = part
        pos = pos + 16
      end do
      write(part,'(z16.16)') transfer(physical%ponding_depth, 0_int64)
      signature(pos:pos+15) = part
      pos = pos + 16
      write(part,'(z16.16)') transfer(physical%groundwater_level, 0_int64)
      signature(pos:pos+15) = part
      valid = .true.
    class default
      return
    end select
  end subroutine make_state_signature

  logical function states_identical(a, b) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: a, b
    character(len=192) :: sa, sb
    logical :: oka, okb

    call make_state_signature(a, sa, oka)
    call make_state_signature(b, sb, okb)
    equal = oka .and. okb .and. trim(sa) == trim(sb)
  end function states_identical

  subroutine configure_column(c, tpl)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: tpl

    tpl%template_id = 8101_int64
    tpl%physics_topology_id = 810101_int64
    tpl%vertical_layout_id = 810102_int64
    tpl%state_layout_id = 810103_int64
    tpl%solver_interface_id = 810104_int64
    tpl%optional_state_layout_id = 0_int64
    tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = SWAP_ORIGIN_LINEAGE
    c%template_id = tpl%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg

    cfg%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = HARD_MASS_GATE
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 4
    cfg%max_committed_substeps = 64
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .true.
    cfg%model_temporal_indicator_budget = TEMPORAL_HEAD_BUDGET_CM
  end subroutine configure_transaction

  subroutine configure_case(p, state, forcing, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity_reference
    real(real64) :: heads(numnod), conductivity(numnod)
    integer :: k

    call configure_base_parameters(p)
    heads = HEAD_A_CM
    call evaluate_state(p, heads, state, conductivity)
    conductivity_reference = conductivity(1)
    do k = 2, numnod
      call require(same_bits(conductivity(k), conductivity_reference), 'uniform initial conductivity')
    end do
    forcing%top_flux = -conductivity_reference
    forcing%top_head = HEAD_A_CM
    forcing%bottom_flux = 12345.0_real64
    forcing%bottom_head = HEAD_A_CM
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 810101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
    p%max_iterations = 12
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-7_real64
    p%compartment_balance_tolerance = HARD_MASS_GATE
    p%total_balance_tolerance = HARD_MASS_GATE
    p%head_abs_tolerance = 1.0e-10_real64
    p%head_rel_tolerance = 1.0e-10_real64
    p%ponding_tolerance = 1.0e-10_real64
  end subroutine configure_base_parameters

  subroutine evaluate_state(p, heads, state, conductivity)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: heads(:)
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity(:)
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), capacity(numnod), dkdh(numnod)

    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, T1-T0)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine evaluate_state

  subroutine allocate_zero_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(inout) :: f

    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
             f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine allocate_zero_forcing

  subroutine poison_legacy_bottom_context()
    swmacro = 0
    legacy_melt = 0.0_real64
    legacy_qdra = 24680.0_real64
    legacy_qssdi = -13579.0_real64
    legacy_qrot = 0.0_real64
    legacy_swbotb = 3
    legacy_hbot = 99999.0_real64
    legacy_qbot = -99999.0_real64
  end subroutine poison_legacy_bottom_context

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label

    if (.not. condition) then
      write(*,'(a)') 'PUB_GC_E1_PRIMARY_FAIL='//trim(label)
      error stop 1
    end if
  end subroutine require

end program pub_gc_e1_primary
