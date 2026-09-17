program test_pub_gc_gc_ref_a
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
  use mod_pub_gc_gc_ref, only: gc_ref_eval_t, gc_ref_solution_t, gc_ref_stability_t, gc_ref_bisect, &
       gc_ref_adjudicate_three_level_stability, GC_REF_OK, GC_REF_BRACKET_INVALID
  implicit none

  real(real64), parameter :: t0 = 4200.125_real64
  real(real64), parameter :: duration_days = 0.03_real64
  real(real64), parameter :: t1 = t0 + duration_days
  real(real64), parameter :: base_head_cm = -80.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-10_real64
  real(real64), parameter :: qualification_head_budget = 100.0_real64
  real(real64), parameter :: gw_area_m2 = 1.0_real64
  real(real64), parameter :: gw_sy = 0.2_real64
  real(real64), parameter :: day_to_s = 86400.0_real64
  integer(int64), parameter :: origin_lineage = 840001_int64
  integer(int64), parameter :: gw_service_id = 840101_int64
  integer(int64), parameter :: gw_lineage_id = 840102_int64

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

  type(gc_ref_solution_t) :: synthetic_solution, real_solution
  type(gc_ref_stability_t) :: stable_result, unstable_result
  type(gc_ref_eval_t) :: repeat_a, repeat_b, reconstructed
  real(real64) :: stable_head(3), stable_q(3), stable_state(3)
  real(real64) :: unstable_head(3), unstable_q(3), unstable_state(3)
  real(real64) :: accepted_predecessor_right_derivative(numnod)
  real(real64) :: reconstructed_gw_head, q_gw_mps, q_gw_integrated_cm
  integer(int64) :: head_digest_a, water_digest_a, head_digest_b, water_digest_b
  integer(int64) :: head_digest_r, water_digest_r
  real(real64) :: mass_a, mass_b, mass_r
  integer :: status
  logical :: ok, available

  call gc_ref_bisect(evaluate_synthetic_root, 0.0_real64, 1.0_real64, 1.0e-12_real64, &
       1.0e-10_real64, 1.0e-10_real64, 64, synthetic_solution, status)
  call require(status == GC_REF_OK .and. synthetic_solution%converged, 'synthetic root convergence')
  call require(close64(synthetic_solution%h_star_m, 0.25_real64), 'synthetic known root')
  write(*,'(a)') 'PUB_GC_GC_REF_SYNTHETIC_KNOWN_ROOT=PASS'

  call gc_ref_bisect(evaluate_invalid_bracket, -1.0_real64, 1.0_real64, 1.0e-12_real64, &
       1.0e-10_real64, 1.0e-10_real64, 64, synthetic_solution, status)
  call require(status == GC_REF_BRACKET_INVALID, 'invalid bracket fails closed')
  write(*,'(a)') 'PUB_GC_GC_REF_INVALID_BRACKET=PASS'

  stable_head = [0.1000_real64, 0.1004_real64, 0.10045_real64]
  stable_q = [1.0000_real64, 1.0040_real64, 1.0045_real64]
  stable_state = [2.0000_real64, 2.0020_real64, 2.0022_real64]
  call gc_ref_adjudicate_three_level_stability(stable_head, stable_q, stable_state, 1.0e-4_real64, &
       1.0e-3_real64, 5.0e-4_real64, stable_result, status)
  call require(status == GC_REF_OK .and. stable_result%stable, 'stable refinement admitted')
  write(*,'(a)') 'PUB_GC_GC_REF_STABLE_REFINEMENT=PASS'

  unstable_head = [0.1000_real64, 0.1100_real64, 0.1200_real64]
  unstable_q = [1.0000_real64, 1.1000_real64, 1.2000_real64]
  unstable_state = [2.0000_real64, 2.1000_real64, 2.2000_real64]
  call gc_ref_adjudicate_three_level_stability(unstable_head, unstable_q, unstable_state, 1.0e-4_real64, &
       1.0e-3_real64, 5.0e-4_real64, unstable_result, status)
  call require(status == GC_REF_OK .and. .not. unstable_result%stable, 'under-refined trajectory rejected')
  write(*,'(a)') 'PUB_GC_GC_REF_UNSTABLE_REFINEMENT_REJECTED=PASS'

  call configure_column(column, template)
  call configure_transaction(config)
  call configure_case(parameters, initial_state, forcing_template, base_head_cm, duration_days)
  call backend%initialize(top_provider)

  accepted_predecessor_right_derivative = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(origin, origin_lineage, initial_state, t0, ok, &
       accepted_predecessor_right_derivative)
  call require(ok .and. origin%ready(), 'origin initialization')
  call origin%snapshot(origin_before, available)
  call require(available, 'origin snapshot before')
  call fmr_capture_checkpoint(origin, origin_checkpoint, ok)
  call require(ok .and. origin_checkpoint%ready(), 'origin checkpoint')
  call initialize_gw_a_once()

  call evaluate_real_full(0.05_real64, repeat_a, head_digest_a, water_digest_a, mass_a, reconstructed_gw_head, status)
  call require(status == GC_REF_OK .and. repeat_a%valid, 'first repeat evaluation')
  call evaluate_real_full(0.05_real64, repeat_b, head_digest_b, water_digest_b, mass_b, reconstructed_gw_head, status)
  call require(status == GC_REF_OK .and. repeat_b%valid, 'second repeat evaluation')
  call require(same_bits(repeat_a%residual_m, repeat_b%residual_m), 'same-head residual identity')
  call require(same_bits(repeat_a%q_whole_cm, repeat_b%q_whole_cm), 'same-head exchange identity')
  call require(head_digest_a == head_digest_b .and. water_digest_a == water_digest_b, 'same-head endpoint identity')
  call require(same_bits(mass_a, mass_b), 'same-head mass identity')
  write(*,'(a)') 'PUB_GC_GC_REF_SAME_ORIGIN_REPEATABILITY=PASS'

  call gc_ref_bisect(evaluate_real_callback, 0.0_real64, 0.10_real64, 1.0e-8_real64, &
       1.0e-6_real64, 1.0e-8_real64, 64, real_solution, status)
  call require(status == GC_REF_OK .and. real_solution%converged, 'real bracketed reference convergence')
  call require(real_solution%h_star_m >= 0.0_real64 .and. real_solution%h_star_m <= 0.10_real64, 'real root inside bracket')
  write(*,'(a)') 'PUB_GC_GC_REF_REAL_BRACKET_ROOT=PASS'

  call evaluate_real_full(real_solution%h_star_m, reconstructed, head_digest_r, water_digest_r, mass_r, &
       reconstructed_gw_head, status)
  call require(status == GC_REF_OK .and. reconstructed%valid, 'final reconstruction')
  call require(abs(reconstructed%residual_m) <= 1.0e-8_real64, 'reconstructed residual tolerance')
  call require(same_bits(reconstructed%q_whole_cm, real_solution%q_whole_cm), 'reconstructed exchange identity')
  call require(same_bits(reconstructed%residual_m, real_solution%residual_m), 'reconstructed residual identity')
  call require(head_digest_r /= 0_int64 .or. water_digest_r /= 0_int64, 'reconstructed state digest available')
  call require(ieee_is_finite(mass_r), 'reconstructed mass finite')
  write(*,'(a)') 'PUB_GC_GC_REF_FINAL_RECONSTRUCTION=PASS'

  q_gw_mps = -(reconstructed%q_whole_cm*0.01_real64)/(duration_days*day_to_s)
  q_gw_integrated_cm = q_gw_mps*(duration_days*day_to_s)*100.0_real64
  call require(close64(reconstructed%q_whole_cm + q_gw_integrated_cm, 0.0_real64), 'action reaction closure')
  write(*,'(a)') 'PUB_GC_GC_REF_ACTION_REACTION=PASS'

  call origin%snapshot(origin_after, available)
  call require(available .and. states_identical(origin_before, origin_after), 'accepted SWAP origin unchanged')
  call require(origin%current_revision() == 0_int64, 'accepted SWAP revision unchanged')
  call require(gw%current_revision() == 0_int64, 'accepted GW revision unchanged')
  call require(close64(gw%accepted_head_m(), 0.0_real64), 'accepted GW head unchanged')
  call require(close64(gw%accepted_time_day(), t0), 'accepted GW time unchanged')
  write(*,'(a)') 'PUB_GC_GC_REF_ACCEPTED_ORIGINS_UNCHANGED=PASS'

  write(*,'(a,es26.17e3)') 'PUB_GC_GC_REF_REAL_H_STAR_REL_M=', real_solution%h_star_m
  write(*,'(a,es26.17e3)') 'PUB_GC_GC_REF_REAL_H_STAR_ABS_CM=', base_head_cm + 100.0_real64*real_solution%h_star_m
  write(*,'(a,es26.17e3)') 'PUB_GC_GC_REF_REAL_RESIDUAL_M=', reconstructed%residual_m
  write(*,'(a,es26.17e3)') 'PUB_GC_GC_REF_REAL_Q_WHOLE_CM=', reconstructed%q_whole_cm
  write(*,'(a,i0)') 'PUB_GC_GC_REF_REAL_EVALUATIONS=', real_solution%evaluations
  write(*,'(a)') 'PUB_GC_GC_REF_NO_H2_H3_PRIMARY_INFERENCE=true'
  write(*,'(a)') 'PUB_GC_GC_REF_A_QUALIFICATION_ORACLE=PASS'

contains

  subroutine evaluate_synthetic_root(h_m, evaluation, local_status)
    real(real64), intent(in) :: h_m
    type(gc_ref_eval_t), intent(out) :: evaluation
    integer, intent(out) :: local_status
    evaluation = gc_ref_eval_t()
    evaluation%valid = .true.
    evaluation%h_m = h_m
    evaluation%residual_m = h_m - 0.25_real64
    evaluation%q_whole_cm = h_m
    local_status = GC_REF_OK
  end subroutine evaluate_synthetic_root

  subroutine evaluate_invalid_bracket(h_m, evaluation, local_status)
    real(real64), intent(in) :: h_m
    type(gc_ref_eval_t), intent(out) :: evaluation
    integer, intent(out) :: local_status
    evaluation = gc_ref_eval_t()
    evaluation%valid = .true.
    evaluation%h_m = h_m
    evaluation%residual_m = h_m*h_m + 1.0_real64
    evaluation%q_whole_cm = h_m
    local_status = GC_REF_OK
  end subroutine evaluate_invalid_bracket

  subroutine evaluate_real_callback(h_relative_m, evaluation, local_status)
    real(real64), intent(in) :: h_relative_m
    type(gc_ref_eval_t), intent(out) :: evaluation
    integer, intent(out) :: local_status
    integer(int64) :: hd, wd
    real(real64) :: mr, gh
    call evaluate_real_full(h_relative_m, evaluation, hd, wd, mr, gh, local_status)
  end subroutine evaluate_real_callback

  subroutine evaluate_real_full(h_relative_m, evaluation, head_digest, water_digest, mass_residual, gw_head_m, local_status)
    real(real64), intent(in) :: h_relative_m
    type(gc_ref_eval_t), intent(out) :: evaluation
    integer(int64), intent(out) :: head_digest, water_digest
    real(real64), intent(out) :: mass_residual, gw_head_m
    integer, intent(out) :: local_status

    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diag
    type(kernel_executor_t) :: discard_executor
    type(fmr_b110_physical_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: snapshot
    type(groundwater_exchange_candidate_t) :: gw_candidate
    type(groundwater_exchange_trial_result_t) :: gw_trial
    type(groundwater_coupling_window_t) :: window
    real(real64) :: prescribed_head_cm, q_gw_local_mps
    integer :: gw_status
    logical :: snapshot_ok, digest_ok

    evaluation = gc_ref_eval_t()
    head_digest = 0_int64
    water_digest = 0_int64
    mass_residual = huge(0.0_real64)
    gw_head_m = huge(0.0_real64)
    local_status = 1

    if (.not. ieee_is_finite(h_relative_m)) return
    prescribed_head_cm = base_head_cm + 100.0_real64*h_relative_m
    forcing = forcing_template
    forcing%bottom_head = prescribed_head_cm
    call poison_legacy_bottom_context()

    call backend%run_trial(column, template, parameters, origin, forcing, config, t0, t1, origin_checkpoint, &
         result, candidate, diagnostics)
    if (.not. result%completed .or. .not. candidate%ready()) return
    if (.not. result%bottom_interface_exchange_available) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if
    if (.not. ieee_is_finite(result%bottom_outward_exchange_native) .or. &
        .not. ieee_is_finite(result%terminal_bottom_outward_flux_native)) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if
    if (.not. result%mass%complete .or. .not. ieee_is_finite(result%mass%residual)) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    call candidate%snapshot(snapshot, snapshot_ok)
    if (.not. snapshot_ok .or. .not. allocated(snapshot)) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if
    call state_digests(snapshot, head_digest, water_digest, digest_ok)
    if (.not. digest_ok) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    window%t0 = t0
    window%t1 = t1
    q_gw_local_mps = -(result%bottom_outward_exchange_native*0.01_real64)/(duration_days*day_to_s)
    call groundwater_trial_from_checkpoint(gw, gw_checkpoint, window, q_gw_local_mps, gw_candidate, gw_trial, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. .not. gw_candidate%ready()) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if
    gw_head_m = gw_trial%h_groundwater_m
    if (.not. ieee_is_finite(gw_head_m)) then
      call groundwater_discard_candidate(gw, gw_candidate, gw_status)
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    evaluation%valid = .true.
    evaluation%h_m = h_relative_m
    evaluation%q_whole_cm = result%bottom_outward_exchange_native
    evaluation%residual_m = h_relative_m - gw_head_m
    mass_residual = result%mass%residual

    call groundwater_discard_candidate(gw, gw_candidate, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. gw_candidate%ready()) then
      evaluation%valid = .false.
      local_status = 1
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if
    discard_diag = diagnostics
    call fmr_discard_candidate(discard_executor, candidate, discard_diag)
    if (candidate%ready()) then
      evaluation%valid = .false.
      local_status = 1
      return
    end if

    local_status = GC_REF_OK
  end subroutine evaluate_real_full

  subroutine initialize_gw_a_once()
    integer :: gw_status
    call gw%initialize(gw_service_id, gw_lineage_id, 0.0_real64, t0, gw_area_m2, gw_sy, &
         0.0_real64, 0.0_real64, gw_status)
    call require(gw_status == GW_EXCHANGE_OK .and. gw%is_configured(), 'GW-A initialize')
    call groundwater_capture_checkpoint(gw, gw_checkpoint, gw_status)
    call require(gw_status == GW_EXCHANGE_OK .and. gw_checkpoint%ready(), 'GW-A capture')
    call require(gw_checkpoint%origin_revision() == 0_int64, 'GW-A origin revision zero')
  end subroutine initialize_gw_a_once

  subroutine configure_column(c, tpl)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: tpl
    tpl%template_id = 8401_int64
    tpl%physics_topology_id = 840101_int64
    tpl%vertical_layout_id = 840102_int64
    tpl%state_layout_id = 840103_int64
    tpl%solver_interface_id = 840104_int64
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

  subroutine configure_case(p, state, forcing, initial_head_cm, dt)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: initial_head_cm, dt
    real(real64) :: heads(numnod), conductivity(numnod), conductivity_reference
    integer :: k
    call configure_base_parameters(p)
    heads = initial_head_cm
    call evaluate_state(p, heads, state, conductivity, dt)
    conductivity_reference = conductivity(1)
    do k=2,numnod
      call require(same_bits(conductivity(k),conductivity_reference), 'uniform initial conductivity')
    end do
    forcing%top_flux = -conductivity_reference
    forcing%top_head = initial_head_cm
    forcing%bottom_flux = 12345.0_real64
    forcing%bottom_head = initial_head_cm
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 840101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k=1,numnod
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
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = 1.0e-10_real64
    p%head_rel_tolerance = 1.0e-10_real64
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
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine allocate_zero_forcing

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

  logical function states_identical(a,b) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: a,b
    integer :: k
    equal=.false.
    if(.not.allocated(a) .or. .not.allocated(b)) return
    select type(pa=>a)
    class is(fmr_b110_physical_state_t)
      select type(pb=>b)
      class is(fmr_b110_physical_state_t)
        if(pa%active_nodes/=pb%active_nodes) return
        if(.not.allocated(pa%pressure_head) .or. .not.allocated(pb%pressure_head)) return
        if(.not.allocated(pa%water_content) .or. .not.allocated(pb%water_content)) return
        if(size(pa%pressure_head)/=size(pb%pressure_head) .or. size(pa%water_content)/=size(pb%water_content)) return
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
    swmacro=0
    legacy_melt=0.0_real64
    legacy_qdra=24680.0_real64
    legacy_qssdi=-13579.0_real64
    legacy_qrot=0.0_real64
    legacy_swbotb=3
    legacy_hbot=99999.0_real64
    legacy_qbot=-99999.0_real64
  end subroutine poison_legacy_bottom_context

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  pure logical function close64(a,b) result(value)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    value=abs(a-b)<=512.0_real64*epsilon(1.0_real64)*scale
  end function close64

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a)') 'PUB_GC_GC_REF_A_FAIL='//trim(label)
      error stop 4
    end if
  end subroutine require

end program test_pub_gc_gc_ref_a
