program test_pub_gc_e1_primary_engine
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
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, groundwater_capture_checkpoint, &
       groundwater_trial_from_checkpoint, groundwater_discard_candidate, GW_EXCHANGE_OK
  use mod_pub_gc_gw_a, only: pub_gc_gw_a_service_t
  implicit none

  real(real64), parameter :: t0 = 4200.125_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-10_real64
  real(real64), parameter :: qualification_head_budget = 100.0_real64
  real(real64), parameter :: gw_area_m2 = 1.0_real64
  real(real64), parameter :: gw_sy = 0.2_real64
  real(real64), parameter :: day_to_s = 86400.0_real64
  integer(int64), parameter :: origin_lineage = 830001_int64
  integer(int64), parameter :: gw_service_id = 830101_int64
  integer(int64), parameter :: gw_lineage_id = 830102_int64

  type state_holder_t
    class(transaction_state_t), allocatable :: state
  end type state_holder_t

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_forcing_t) :: forcing_template
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: origin
  type(kernel_checkpoint_t) :: origin_checkpoint
  type(pub_gc_gw_a_service_t) :: gw
  type(groundwater_exchange_checkpoint_t) :: gw_checkpoint
  class(transaction_state_t), allocatable :: origin_before, origin_after
  type(kernel_result_t) :: same_result(2,4), hist_result(2,4)
  type(kernel_diagnostics_t) :: same_diag(2,4), hist_diag(2,4)
  type(state_holder_t) :: same_state(2,4), hist_state(2,4)
  real(real64) :: same_gw_head(2,4), same_gw_residual(2,4)
  real(real64) :: hist_gw_head(2,4), hist_gw_residual(2,4)
  real(real64) :: head_a, head_b, head_c, duration, t1
  real(real64) :: accepted_predecessor_right_derivative(numnod)
  real(real64) :: seq_heads(2,4)
  character(len=1) :: seq_labels(2,4)
  real(real64) :: delta_q_hist_a, delta_head_hist_a, delta_water_hist_a
  real(real64) :: delta_gw_head_hist_a, delta_gw_residual_hist_a
  logical :: ok, available
  integer :: ios, seq, idx
  character(len=128) :: arg

  call read_real_arg(1, head_a)
  call read_real_arg(2, head_b)
  call read_real_arg(3, head_c)
  call read_real_arg(4, duration)
  call require(duration > 0.0_real64, 'positive duration')
  call require(distinct_value(head_a, head_b) .and. distinct_value(head_a, head_c) .and. &
       distinct_value(head_b, head_c), 'A B C distinct')
  t1 = t0 + duration

  seq_heads(1,:) = [head_a, head_b, head_a, head_c]
  seq_heads(2,:) = [head_a, head_c, head_a, head_b]
  seq_labels(1,:) = ['A','B','A','C']
  seq_labels(2,:) = ['A','C','A','B']

  call configure_column(column, template)
  call configure_transaction(config)
  call configure_case(parameters, initial_state, forcing_template, head_a, duration)
  call backend%initialize(top_provider)

  accepted_predecessor_right_derivative = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(origin, origin_lineage, initial_state, t0, ok, &
       accepted_predecessor_right_derivative)
  call require(ok .and. origin%ready(), 'origin initialization')
  call origin%snapshot(origin_before, available)
  call require(available, 'origin snapshot')
  call fmr_capture_checkpoint(origin, origin_checkpoint, ok)
  call require(ok .and. origin_checkpoint%ready(), 'origin checkpoint')

  call initialize_gw_a_once()

  do seq = 1, 2
    do idx = 1, 4
      call evaluate_from_committed(origin, origin_checkpoint, seq_heads(seq,idx), same_result(seq,idx), &
           same_diag(seq,idx), same_state(seq,idx)%state)
      call evaluate_gw_same_checkpoint(same_result(seq,idx), seq_heads(seq,idx), head_a, &
           same_gw_head(seq,idx), same_gw_residual(seq,idx))
    end do
  end do

  call require_result_state_identity(same_result(1,1), same_state(1,1)%state, same_result(1,3), same_state(1,3)%state, &
       'same S1 A replay')
  call require_result_state_identity(same_result(1,1), same_state(1,1)%state, same_result(2,1), same_state(2,1)%state, &
       'same cross-sequence A first')
  call require_result_state_identity(same_result(1,1), same_state(1,1)%state, same_result(2,3), same_state(2,3)%state, &
       'same cross-sequence A repeated')
  call require_result_state_identity(same_result(1,2), same_state(1,2)%state, same_result(2,4), same_state(2,4)%state, &
       'same cross-sequence B')
  call require_result_state_identity(same_result(1,4), same_state(1,4)%state, same_result(2,2), same_state(2,2)%state, &
       'same cross-sequence C')

  do seq = 1, 2
    call evaluate_history_sequence(seq, seq_heads(seq,:), hist_result(seq,:), hist_diag(seq,:), hist_state(seq,:), &
         hist_gw_head(seq,:), hist_gw_residual(seq,:), head_a)
  end do

  call origin%snapshot(origin_after, available)
  call require(available .and. states_identical(origin_before, origin_after), 'engine mutated accepted origin')
  call require(origin%current_revision() == 0_int64, 'engine changed accepted revision')

  delta_q_hist_a = abs(hist_result(1,3)%bottom_outward_exchange_native - &
       hist_result(2,3)%bottom_outward_exchange_native)
  call endpoint_deltas(hist_state(1,3)%state, hist_state(2,3)%state, delta_head_hist_a, delta_water_hist_a, ok)
  call require(ok, 'history repeated-A endpoint delta')
  delta_gw_head_hist_a = abs(hist_gw_head(1,3)-hist_gw_head(2,3))
  delta_gw_residual_hist_a = abs(hist_gw_residual(1,3)-hist_gw_residual(2,3))

  do seq = 1, 2
    do idx = 1, 4
      call emit_row('SAME', seq, idx, seq_labels(seq,idx), seq_heads(seq,idx), same_result(seq,idx), &
           same_diag(seq,idx), same_state(seq,idx)%state, same_gw_head(seq,idx), same_gw_residual(seq,idx), .false., 0)
    end do
    do idx = 1, 4
      call emit_row('HISTORY_DIAG', seq, idx, seq_labels(seq,idx), seq_heads(seq,idx), hist_result(seq,idx), &
           hist_diag(seq,idx), hist_state(seq,idx)%state, hist_gw_head(seq,idx), hist_gw_residual(seq,idx), idx>1, idx-1)
    end do
  end do

  write(*,'(a,es26.17e3)') 'PUB_GC_E1_ENGINE_DELTA_Q_A_AFTER_B_VS_C=', delta_q_hist_a
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_ENGINE_DELTA_HEAD_A_AFTER_B_VS_C=', delta_head_hist_a
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_ENGINE_DELTA_WATER_A_AFTER_B_VS_C=', delta_water_hist_a
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_ENGINE_DELTA_GW_HEAD_A_AFTER_B_VS_C=', delta_gw_head_hist_a
  write(*,'(a,es26.17e3)') 'PUB_GC_E1_ENGINE_DELTA_GW_RESIDUAL_A_AFTER_B_VS_C=', delta_gw_residual_hist_a
  write(*,'(a)') 'PUB_GC_E1_ENGINE_SAME_ORIGIN_IDENTITY=PASS'
  write(*,'(a)') 'PUB_GC_E1_ENGINE_ACCEPTED_ORIGIN_UNCHANGED=PASS'
  call require(gw_checkpoint%ready(), 'GW-A checkpoint remains reusable')
  call require(gw%current_revision() == 0_int64, 'GW-A shared checkpoint revision unchanged')
  write(*,'(a)') 'PUB_GC_E1_ENGINE_GW_A_SAME_CHECKPOINT_NO_COMMIT=PASS'
  write(*,'(a)') 'PUB_GC_E1_ENGINE_HISTORY_DIAG_PRODUCTION_VALID=false'
  write(*,'(a)') 'PUB_GC_E1_PRIMARY_ENGINE_ORACLE=PASS'

contains

  subroutine read_real_arg(position, value)
    integer, intent(in) :: position
    real(real64), intent(out) :: value
    if (command_argument_count() /= 4) then
      write(*,'(a)') 'PUB_GC_E1_ENGINE_INFRA_FAIL=expected A B C duration'
      error stop 2
    end if
    call get_command_argument(position, arg)
    read(arg,*,iostat=ios) value
    if (ios /= 0 .or. .not. ieee_is_finite(value)) then
      write(*,'(a,i0)') 'PUB_GC_E1_ENGINE_INFRA_FAIL=invalid_arg_', position
      error stop 2
    end if
  end subroutine read_real_arg

  subroutine evaluate_from_committed(committed, checkpoint, prescribed_head, result, diagnostics, snapshot)
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: prescribed_head
    type(kernel_result_t), intent(out) :: result
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    class(transaction_state_t), allocatable, intent(out) :: snapshot
    type(kernel_candidate_state_t) :: candidate
    type(kernel_executor_t) :: discard_executor
    type(kernel_diagnostics_t) :: discard_diag
    type(fmr_b110_physical_forcing_t) :: forcing
    logical :: snapshot_ok

    forcing = forcing_template
    forcing%bottom_head = prescribed_head
    call poison_legacy_bottom_context()
    call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
    call require(result%completed, 'trial completion')
    call require(candidate%ready(), 'candidate ready')
    call require(result%bottom_interface_exchange_available, 'whole-window exchange available')
    call require(ieee_is_finite(result%bottom_outward_exchange_native), 'finite whole-window exchange')
    call require(ieee_is_finite(result%terminal_bottom_outward_flux_native), 'finite terminal flux')
    call require(result%mass%complete .and. ieee_is_finite(result%mass%residual), 'finite complete mass accounting')
    call candidate%snapshot(snapshot, snapshot_ok)
    call require(snapshot_ok .and. allocated(snapshot), 'candidate snapshot')
    discard_diag = diagnostics
    call fmr_discard_candidate(discard_executor, candidate, discard_diag)
    call require(.not. candidate%ready(), 'candidate discard')
  end subroutine evaluate_from_committed

  subroutine evaluate_history_sequence(sequence_id, heads, results, diagnostics, states, gw_heads, gw_residuals, base_head)
    integer, intent(in) :: sequence_id
    real(real64), intent(in) :: heads(4), base_head
    type(kernel_result_t), intent(out) :: results(4)
    type(kernel_diagnostics_t), intent(out) :: diagnostics(4)
    type(state_holder_t), intent(out) :: states(4)
    real(real64), intent(out) :: gw_heads(4), gw_residuals(4)
    type(kernel_committed_state_t) :: carriers(3)
    type(kernel_checkpoint_t) :: checkpoints(3)
    integer :: j
    logical :: init_ok
    integer(int64) :: lineage

    call evaluate_from_committed(origin, origin_checkpoint, heads(1), results(1), diagnostics(1), states(1)%state)
    call evaluate_gw_same_checkpoint(results(1), heads(1), base_head, gw_heads(1), gw_residuals(1))
    do j = 2, 4
      lineage = 831000_int64 + int(sequence_id*10+j, int64)
      call carriers(j-1)%initialize(lineage, states(j-1)%state, init_ok, initial_time=t0)
      call require(init_ok .and. carriers(j-1)%ready(), 'history carrier initialize')
      call require(carriers(j-1)%current_revision() == 0_int64, 'history carrier revision zero')
      call fmr_capture_checkpoint(carriers(j-1), checkpoints(j-1), init_ok)
      call require(init_ok .and. checkpoints(j-1)%ready(), 'history checkpoint')
      call evaluate_from_committed(carriers(j-1), checkpoints(j-1), heads(j), results(j), diagnostics(j), states(j)%state)
      call require(carriers(j-1)%current_revision() == 0_int64, 'history carrier mutated')
      call evaluate_gw_same_checkpoint(results(j), heads(j), base_head, gw_heads(j), gw_residuals(j))
    end do
  end subroutine evaluate_history_sequence

  subroutine evaluate_gw_same_checkpoint(swap_result, prescribed_head_cm, base_head_cm, gw_head_m, residual_m)
    type(kernel_result_t), intent(in) :: swap_result
    real(real64), intent(in) :: prescribed_head_cm, base_head_cm
    real(real64), intent(out) :: gw_head_m, residual_m
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: trial
    type(groundwater_coupling_window_t) :: window
    real(real64) :: q_swap_m, q_gw_mps, prescribed_relative_m, expected_head_m
    integer :: status

    call require(gw%is_configured() .and. gw_checkpoint%ready(), 'GW-A frozen accepted checkpoint')
    window%t0 = t0
    window%t1 = t1
    q_swap_m = swap_result%bottom_outward_exchange_native * 0.01_real64
    q_gw_mps = -q_swap_m / ((t1-t0)*day_to_s)
    call groundwater_trial_from_checkpoint(gw, gw_checkpoint, window, q_gw_mps, candidate, trial, status)
    call require(status == GW_EXCHANGE_OK .and. candidate%ready(), 'GW-A trial')
    gw_head_m = trial%h_groundwater_m
    expected_head_m = q_swap_m / gw_sy
    call require(close64(gw_head_m, expected_head_m), 'GW-A analytic head')
    prescribed_relative_m = (prescribed_head_cm-base_head_cm) * 0.01_real64
    residual_m = prescribed_relative_m - gw_head_m
    call groundwater_discard_candidate(gw, candidate, status)
    call require(status == GW_EXCHANGE_OK .and. .not. candidate%ready(), 'GW-A discard')
    call require(close64(gw%accepted_head_m(), 0.0_real64), 'GW-A accepted head unchanged')
    call require(close64(gw%accepted_time_day(), t0), 'GW-A accepted time unchanged')
    call require(gw%current_revision() == 0_int64, 'GW-A revision unchanged')
  end subroutine evaluate_gw_same_checkpoint

  subroutine initialize_gw_a_once()
    integer :: status
    call gw%initialize(gw_service_id, gw_lineage_id, 0.0_real64, t0, gw_area_m2, gw_sy, &
         0.0_real64, 0.0_real64, status)
    call require(status == GW_EXCHANGE_OK .and. gw%is_configured(), 'GW-A initialize once')
    call groundwater_capture_checkpoint(gw, gw_checkpoint, status)
    call require(status == GW_EXCHANGE_OK .and. gw_checkpoint%ready(), 'GW-A capture once')
    call require(gw_checkpoint%origin_revision() == 0_int64, 'GW-A origin revision zero')
  end subroutine initialize_gw_a_once

  subroutine require_result_state_identity(ra, sa, rb, sb, label)
    type(kernel_result_t), intent(in) :: ra, rb
    class(transaction_state_t), allocatable, intent(in) :: sa, sb
    character(len=*), intent(in) :: label
    call require(same_bits(ra%bottom_outward_exchange_native, rb%bottom_outward_exchange_native), trim(label)//' exchange')
    call require(same_bits(ra%terminal_bottom_outward_flux_native, rb%terminal_bottom_outward_flux_native), trim(label)//' terminal')
    call require(states_identical(sa, sb), trim(label)//' endpoint')
  end subroutine require_result_state_identity

  subroutine emit_row(policy, sequence_id, candidate_index, candidate_label, prescribed_head, result, diagnostics, &
                      snapshot, gw_head_m, gw_residual_m, synthetic_origin, source_index)
    character(len=*), intent(in) :: policy
    integer, intent(in) :: sequence_id, candidate_index, source_index
    character(len=1), intent(in) :: candidate_label
    real(real64), intent(in) :: prescribed_head, gw_head_m, gw_residual_m
    type(kernel_result_t), intent(in) :: result
    type(kernel_diagnostics_t), intent(in) :: diagnostics
    class(transaction_state_t), allocatable, intent(in) :: snapshot
    logical, intent(in) :: synthetic_origin
    integer(int64) :: head_digest, water_digest, accepted_lineage
    logical :: digest_ok

    call state_digests(snapshot, head_digest, water_digest, digest_ok)
    call require(digest_ok, 'state digest')
    accepted_lineage = origin_lineage
    if (synthetic_origin) accepted_lineage = 831000_int64 + int(sequence_id*10+candidate_index, int64)
    write(*,'(a,"|S",i0,"|",a,"|",i0,"|",a,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",i0,"|",i0,"|",es26.17e3,"|",i0,"|",es26.17e3,"|",l1,"|",i0,"|",i0,"|",i0,"|",es26.17e3,"|DISCARDED")') &
         'PUB_GC_E1_ENGINE_ROW', sequence_id, trim(policy), candidate_index, candidate_label, prescribed_head, &
         result%bottom_outward_exchange_native, result%terminal_bottom_outward_flux_native, head_digest, water_digest, &
         result%mass%residual, diagnostics%retries, diagnostics%max_temporal_indicator, synthetic_origin, &
         merge(source_index,0,synthetic_origin), accepted_lineage, 0_int64, t0
    write(*,'(a,"|S",i0,"|",a,"|",i0,"|",es26.17e3,"|",es26.17e3)') &
         'PUB_GC_E1_ENGINE_GW_ROW', sequence_id, trim(policy), candidate_index, gw_head_m, gw_residual_m
  end subroutine emit_row

  subroutine endpoint_deltas(a, b, head_delta, water_delta, valid)
    class(transaction_state_t), allocatable, intent(in) :: a, b
    real(real64), intent(out) :: head_delta, water_delta
    logical, intent(out) :: valid
    valid = .false.
    head_delta = huge(0.0_real64)
    water_delta = huge(0.0_real64)
    if (.not. allocated(a) .or. .not. allocated(b)) return
    select type (pa => a)
    class is (fmr_b110_physical_state_t)
      select type (pb => b)
      class is (fmr_b110_physical_state_t)
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        if (size(pa%pressure_head) /= size(pb%pressure_head)) return
        if (size(pa%water_content) /= size(pb%water_content)) return
        head_delta = maxval(abs(pa%pressure_head-pb%pressure_head))
        water_delta = maxval(abs(pa%water_content-pb%water_content))
        valid = ieee_is_finite(head_delta) .and. ieee_is_finite(water_delta)
      end select
    end select
  end subroutine endpoint_deltas

  subroutine state_digests(state, head_digest, water_digest, valid)
    class(transaction_state_t), allocatable, intent(in) :: state
    integer(int64), intent(out) :: head_digest, water_digest
    logical, intent(out) :: valid
    integer :: k
    head_digest = 0_int64
    water_digest = 0_int64
    valid = .false.
    if (.not. allocated(state)) return
    select type (p => state)
    class is (fmr_b110_physical_state_t)
      if (.not. allocated(p%pressure_head) .or. .not. allocated(p%water_content)) return
      do k=1,size(p%pressure_head)
        head_digest = ieor(head_digest, transfer(p%pressure_head(k),0_int64))
      end do
      do k=1,size(p%water_content)
        water_digest = ieor(water_digest, transfer(p%water_content(k),0_int64))
      end do
      valid = .true.
    end select
  end subroutine state_digests

  subroutine configure_column(c, tpl)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: tpl
    tpl%template_id = 8301_int64
    tpl%physics_topology_id = 830101_int64
    tpl%vertical_layout_id = 830102_int64
    tpl%state_layout_id = 830103_int64
    tpl%solver_interface_id = 830104_int64
    tpl%optional_state_layout_id = 0_int64
    tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = origin_lineage
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
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 4
    cfg%max_committed_substeps = 64
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .true.
    cfg%model_temporal_indicator_budget = qualification_head_budget
  end subroutine configure_transaction

  subroutine configure_case(p, state, forcing, base_head, dt)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: base_head, dt
    real(real64) :: heads(numnod), conductivity(numnod), conductivity_reference
    integer :: k
    call configure_base_parameters(p)
    heads = base_head
    call evaluate_state(p, heads, state, conductivity, dt)
    conductivity_reference = conductivity(1)
    do k=2,numnod
      call require(same_bits(conductivity(k),conductivity_reference), 'uniform initial conductivity')
    end do
    forcing%top_flux = -conductivity_reference
    forcing%top_head = base_head
    forcing%bottom_flux = 12345.0_real64
    forcing%bottom_head = base_head
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 830101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5; p%swkimpl = 0; p%swkmean = 1; p%swsophy = 0
    p%root_extraction_active = .false.; p%macropore_active = .false.; p%snow_active = .false.
    p%hysteresis_active = .false.; p%tabulated_hydraulics_active = .false.; p%elasticity_active = .false.
    p%frost_active = .false.; p%soil_temperature_active = .false.; p%drainage_response_active = .false.
    p%max_iterations = 12; p%max_backtracking = 8; p%min_step_duration = 1.0e-7_real64
    p%compartment_balance_tolerance = hard_mass_gate; p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = 1.0e-10_real64; p%head_rel_tolerance = 1.0e-10_real64
    p%ponding_tolerance = 1.0e-10_real64
  end subroutine configure_base_parameters

  subroutine evaluate_state(p, heads, state, conductivity, dt)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: heads(:), dt
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity(:)
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), capacity(numnod), dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)
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
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine allocate_zero_forcing

  logical function states_identical(a,b) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: a,b
    integer :: k
    equal=.false.
    if(.not.allocated(a).or. .not.allocated(b)) return
    select type(pa=>a)
    class is(fmr_b110_physical_state_t)
      select type(pb=>b)
      class is(fmr_b110_physical_state_t)
        if(pa%active_nodes/=pb%active_nodes) return
        if(.not.allocated(pa%pressure_head).or. .not.allocated(pb%pressure_head)) return
        if(.not.allocated(pa%water_content).or. .not.allocated(pb%water_content)) return
        if(size(pa%pressure_head)/=size(pb%pressure_head).or.size(pa%water_content)/=size(pb%water_content)) return
        do k=1,pa%active_nodes
          if(.not.same_bits(pa%pressure_head(k),pb%pressure_head(k))) return
          if(.not.same_bits(pa%water_content(k),pb%water_content(k))) return
        end do
        if(.not.same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if(.not.same_bits(pa%groundwater_level,pb%groundwater_level)) return
        equal=.true.
      end select
    end select
  end function states_identical

  subroutine poison_legacy_bottom_context()
    swmacro=0; legacy_melt=0.0_real64; legacy_qdra=24680.0_real64; legacy_qssdi=-13579.0_real64
    legacy_qrot=0.0_real64; legacy_swbotb=3; legacy_hbot=99999.0_real64; legacy_qbot=-99999.0_real64
  end subroutine poison_legacy_bottom_context

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  pure logical function distinct_value(a,b) result(value)
    real(real64), intent(in) :: a,b
    value=.not.same_bits(a,b)
  end function distinct_value

  pure logical function close64(a,b) result(value)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    value=abs(a-b)<=256.0_real64*epsilon(1.0_real64)*scale
  end function close64

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a)') 'PUB_GC_E1_ENGINE_FAIL='//trim(label)
      error stop 3
    end if
  end subroutine require

end program test_pub_gc_e1_primary_engine
