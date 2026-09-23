program test_hydro_memory_cap01_root_active_response
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_forcing_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_derivative_coverage_t, &
       modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_DERIVATIVE_CENTERED_FD, MODFLOW6_PREDICTOR_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_UNAVAILABLE, &
       MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
       compose_modflow6_multiswap_cell_response, MODFLOW6_MULTI_CELL_OK
  implicit none

  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: DURATION_DAY = 1.0e-4_real64
  real(real64), parameter :: MASS_TOL = 1.0e-12_real64
  real(real64), parameter :: FD_EPS = 1.0e-4_real64
  real(real64), parameter :: HEAD_EPS_M = 1.0e-6_real64
  real(real64), parameter :: SLOPE_REL_TOL = 5.0e-2_real64
  real(real64), parameter :: ROOT_TOTAL = 2.0e-2_real64
  integer(int64), parameter :: COLUMN_ID = 590101_int64
  integer(int64), parameter :: COUPLING_ID = 590102_int64
  integer(int64), parameter :: GW_CELL_ID = 590103_int64
  integer(int64), parameter :: GW_SERVICE_ID = 590104_int64
  integer(int64), parameter :: GW_LINEAGE_ID = 590105_int64

  type(fmr_b110_physical_parameters_t) :: predictor_parameters, corrector_parameters
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(kernel_committed_state_t) :: committed
  type(modflow6_prescribed_qbot_bottom_face_t) :: origin_face, nominal_face, plus_face, minus_face
  type(modflow6_derivative_coverage_t) :: coverage
  type(modflow6_swap_predictor_lineage_t) :: lineage
  type(modflow6_swap_predictor_response_t) :: response(1)
  type(groundwater_direct_tile_binding_t) :: binding(1)
  type(modflow6_multiswap_cell_response_t) :: cell
  type(kernel_result_t) :: nominal_result, direction_result
  type(kernel_candidate_state_t) :: nominal_candidate, direction_candidate
  type(kernel_diagnostics_t) :: nominal_diagnostics, direction_diagnostics
  type(soil_water_physical_state_t) :: nominal_state
  type(soil_water_parameter_set_t) :: solver_parameters
  type(modflow6_swap_predictor_tangent_endpoint_t) :: blocked_endpoint
  type(fmr_groundwater_head_forcing_materializer_t) :: materializer
  type(fmr_groundwater_swap_participant_t) :: participant
  type(fmr_serialized_reference_backend_t) :: corrector_backend
  type(groundwater_swap_trial_t) :: trial_ref, trial_plus, trial_minus
  class(canonical_forcing_t), allocatable :: materialized
  real(real64) :: fd_derivative, derivative_scale
  real(real64) :: corrector_slope, slope_scale, slope_rel_error
  real(real64) :: reference_error, reference_scale, qbot_ref
  integer(int64) :: revision_before, revision_after
  integer :: status
  logical :: available

  call initialize_parameters(predictor_parameters, SW_STEP_CONTROL_BOTTOM_FLUX)
  call initialize_parameters(corrector_parameters, 5)
  call initialize_column_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, predictor_parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, DURATION_DAY)
  call derive_equilibrium_flux(qbot_ref)
  call initialize_forcing(base_forcing, qbot_ref)
  call initialize_committed_state(committed, predictor_parameters)

  datum%available = .true.
  datum%datum_id = 590106_int64
  datum%bottom_boundary_elevation_m = 0.0_real64
  window%t0 = 0.0_real64
  window%t1 = DURATION_DAY

  call characterize_net_root_execution()
  call set_root_case(ROOT_TOTAL, .false.)

  call run_root_candidate(qbot_ref, .false., nominal_result, nominal_candidate, nominal_diagnostics)
  write(*,'(a,i0,a,l1,a,es14.6,a,i0,a,i0,a,i0,a,i0,a,i0)') 'HMCAP01_NOMINAL_DIAG status=', &
       nominal_result%status, ' completed=', nominal_result%completed, ' completed_t=', nominal_result%completed_t, &
       ' retries=', nominal_diagnostics%retries, ' solver_rejections=', nominal_diagnostics%solver_rejections, &
       ' temporal_rejections=', nominal_diagnostics%temporal_rejections, ' temporal_unavailable=', &
       nominal_diagnostics%temporal_certificate_unavailable_rejections, ' mass_rejections=', nominal_diagnostics%mass_rejections
  call require(nominal_result%status == CANONICAL_STATUS_COMPLETED .and. nominal_result%completed, &
       'root-active nominal production candidate did not complete')
  call require(nominal_candidate%ready(), 'root-active nominal candidate not ready')
  call require(nominal_result%mass%complete, 'root-active nominal mass accounting incomplete')
  call require(abs(nominal_result%mass%residual) <= MASS_TOL, 'root-active nominal hard mass gate')
  call require(nominal_diagnostics%retries == 0, 'root-active nominal candidate retried')
  write(*,'(a)') 'HMCAP01_ROOT_ACTIVE_REAL_TRIAL=PASS'
  write(*,'(a)') 'HMCAP01_ROOT_ACTIVE_HARD_MASS=PASS'

  call run_root_candidate(qbot_ref, .true., direction_result, direction_candidate, direction_diagnostics)
  call require(direction_result%completed, 'root-active trajectory-requested candidate did not complete')
  call require(direction_result%accepted_trajectory_direction%requested, 'root-active trajectory was not requested')
  call require(.not. direction_result%accepted_trajectory_direction%available, &
       'root-active analytic trajectory unexpectedly became authoritative')
  call materialize_solver_view(direction_candidate, nominal_state, solver_parameters)
  call build_modflow6_swap_predictor_tangent_endpoint(nominal_state, solver_parameters, constitutive, &
       direction_result%accepted_trajectory_direction, qbot_ref, datum, .false., .true., .false., .false., &
       blocked_endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_UNAVAILABLE .or. &
       status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE, 'root-active analytic tangent did not fail closed')
  call require(.not. blocked_endpoint%authoritative, 'root-active analytic endpoint became authoritative')
  write(*,'(a)') 'HMCAP01_ANALYTIC_ROOT_TANGENT_FAIL_CLOSED=PASS'

  call materialize_candidate_face(nominal_candidate, qbot_ref, nominal_face)
  call run_endpoint_value(qbot_ref + FD_EPS, plus_face)
  call run_endpoint_value(qbot_ref - FD_EPS, minus_face)
  fd_derivative = (plus_face%pressure_head_cm - minus_face%pressure_head_cm) / (2.0_real64 * FD_EPS)
  derivative_scale = max(1.0_real64, abs(fd_derivative))
  call require(ieee_is_finite(fd_derivative), 'root-active centered-FD derivative nonfinite')
  call require(abs(fd_derivative) > 128.0_real64 * epsilon(1.0_real64) * derivative_scale, &
       'root-active centered-FD derivative ill-conditioned')
  write(*,'(a)') 'HMCAP01_ROOT_ACTIVE_CENTERED_FD=PASS'

  call materialize_origin_face(qbot_ref, origin_face)
  lineage%coupling_id = COUPLING_ID
  lineage%swap_lineage_id = COLUMN_ID
  lineage%swap_origin_revision = 0_int64
  lineage%groundwater_service_id = GW_SERVICE_ID
  lineage%groundwater_lineage_id = GW_LINEAGE_ID
  lineage%groundwater_origin_revision = 0_int64

  coverage%lower_face_head_semantics_covered = .true.
  coverage%richards_hydraulic_response_covered = .true.
  coverage%constitutive_response_covered = .true.
  coverage%root_uptake_active = .true.
  coverage%root_uptake_covered = .false.

  call compose_modflow6_swap_predictor_response(window, lineage, qbot_ref, origin_face%hydraulic_head_m, &
       nominal_face%hydraulic_head_m, fd_derivative, MODFLOW6_DERIVATIVE_CENTERED_FD, coverage, &
       'centered-finite-difference', 'root-active-full-trajectory-centered-fd', response(1), status)
  call require(status == MODFLOW6_PREDICTOR_OK .and. response(1)%valid, &
       'root-active centered-FD typed predictor response rejected')
  call require(response(1)%derivative_kind == MODFLOW6_DERIVATIVE_CENTERED_FD, &
       'root-active response derivative kind drift')
  call require(response(1)%derivative_coverage%root_uptake_active .and. &
       .not. response(1)%derivative_coverage%root_uptake_covered, &
       'root-active response coverage provenance drift')
  write(*,'(a)') 'HMCAP01_TYPED_ROOT_ACTIVE_FD_RESPONSE=PASS'

  call materializer%initialize(base_forcing)
  call assert_materialized_root_sink(materializer, nominal_face%hydraulic_head_m - HEAD_EPS_M)
  call assert_materialized_root_sink(materializer, nominal_face%hydraulic_head_m)
  call assert_materialized_root_sink(materializer, nominal_face%hydraulic_head_m + HEAD_EPS_M)
  write(*,'(a)') 'HMCAP01_ROOT_SINK_IMMUTABLE_ACROSS_HEADS=PASS'

  call corrector_backend%initialize(top)
  call participant%capture_origin(committed, status)
  call require(status == GW_SWAP_PARTICIPANT_OK, 'root-active participant origin capture')

  revision_before = committed%current_revision()
  call participant%trial_from_origin(corrector_backend, column, template, corrector_parameters, committed, &
       materializer, corrector_config(), datum, window, nominal_face%hydraulic_head_m, trial_ref, status)
  call require(status == GW_SWAP_PARTICIPANT_OK .and. trial_ref%valid, 'root-active reference-head corrector')
  call participant%discard_candidate(corrector_backend)

  call participant%trial_from_origin(corrector_backend, column, template, corrector_parameters, committed, &
       materializer, corrector_config(), datum, window, nominal_face%hydraulic_head_m + HEAD_EPS_M, trial_plus, status)
  call require(status == GW_SWAP_PARTICIPANT_OK .and. trial_plus%valid, 'root-active plus-head corrector')
  call participant%discard_candidate(corrector_backend)

  call participant%trial_from_origin(corrector_backend, column, template, corrector_parameters, committed, &
       materializer, corrector_config(), datum, window, nominal_face%hydraulic_head_m - HEAD_EPS_M, trial_minus, status)
  call require(status == GW_SWAP_PARTICIPANT_OK .and. trial_minus%valid, 'root-active minus-head corrector')
  call participant%discard_candidate(corrector_backend)

  revision_after = committed%current_revision()
  call require(revision_after == revision_before, 'same-origin root-active correctors mutated committed revision')
  call committed%current_time(reference_error, available)
  call require(available .and. abs(reference_error - window%t0) <= 64.0_real64*epsilon(1.0_real64), &
       'same-origin root-active correctors mutated committed time')
  write(*,'(a)') 'HMCAP01_SAME_ORIGIN_CORRECTORS_ZERO_MUTATION=PASS'

  binding(1)%groundwater_cell_id = GW_CELL_ID
  binding(1)%tile_id = COLUMN_ID
  binding(1)%area_fraction = 1.0_real64
  call compose_modflow6_multiswap_cell_response(binding, response, response(1)%h_bot_end_m, cell, status)
  call require(status == MODFLOW6_MULTI_CELL_OK .and. cell%valid, 'root-active cell response composition')

  corrector_slope = (trial_plus%q_swap_m_per_s - trial_minus%q_swap_m_per_s) / (2.0_real64 * HEAD_EPS_M)
  slope_scale = max(abs(corrector_slope), abs(cell%dq_u_dh_per_s), 1.0e-16_real64)
  slope_rel_error = abs(corrector_slope - cell%dq_u_dh_per_s) / slope_scale
  call require(ieee_is_finite(corrector_slope) .and. ieee_is_finite(slope_rel_error), &
       'root-active local slope nonfinite')
  call require(slope_rel_error <= SLOPE_REL_TOL, 'root-active predictor/corrector local slope exceeds 5 percent')

  reference_scale = max(abs(trial_ref%q_swap_m_per_s), abs(cell%q_u_at_reference_m_per_s), 1.0e-16_real64)
  reference_error = abs(trial_ref%q_swap_m_per_s - cell%q_u_at_reference_m_per_s) / reference_scale

  write(*,'(a,es24.16)') 'HMCAP01_FD_DH_DQ=', fd_derivative
  write(*,'(a,es24.16)') 'HMCAP01_PREDICTOR_DQ_DH=', cell%dq_u_dh_per_s
  write(*,'(a,es24.16)') 'HMCAP01_CORRECTOR_DQ_DH=', corrector_slope
  write(*,'(a,es24.16)') 'HMCAP01_SLOPE_REL_ERROR=', slope_rel_error
  write(*,'(a,es24.16)') 'HMCAP01_REFERENCE_FLUX_REL_ERROR=', reference_error
  write(*,'(a)') 'HMCAP01_ROOT_ACTIVE_LOCAL_SLOPE_AGREEMENT=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_CAP01_A_PASS_CENTERED_FD_ROUTE'

contains

  subroutine set_root_case(total_root, balanced)
    real(real64), intent(in) :: total_root
    logical, intent(in) :: balanced
    integer :: rooted
    real(real64) :: per_node

    call require(allocated(base_forcing%root_extraction_sink), 'characterization root sink allocated')
    call require(allocated(base_forcing%subsurface_irrigation_source), 'characterization source allocated')
    base_forcing%root_extraction_sink = 0.0_real64
    base_forcing%subsurface_irrigation_source = 0.0_real64
    rooted = min(4, numnod)
    call require(rooted > 0, 'characterization rooted nodes')
    per_node = total_root / real(rooted, real64)
    base_forcing%root_extraction_sink(1:rooted) = per_node
    if (balanced) base_forcing%subsurface_irrigation_source = base_forcing%root_extraction_sink
  end subroutine set_root_case

  subroutine run_characterization_case(label, total_root, balanced, must_complete)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: total_root
    logical, intent(in) :: balanced, must_complete
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call set_root_case(total_root, balanced)
    call run_root_candidate(qbot_ref, .false., result, candidate, diagnostics)
    write(*,'(a,a,a,es14.6,a,l1,a,i0,a,i0,a,i0,a,i0,a,es14.6)') &
         'HMCAP01_A4_CASE=', trim(label), ' root_total=', total_root, ' completed=', result%completed, &
         ' status=', result%status, ' retries=', diagnostics%retries, ' solver_rejections=', diagnostics%solver_rejections, &
         ' temporal_rejections=', diagnostics%temporal_rejections, ' mass_residual=', result%mass%residual
    if (must_complete) then
      call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, &
           'CAP01 A4 required control did not complete: '//trim(label))
      call require(candidate%ready(), 'CAP01 A4 required control candidate not ready: '//trim(label))
      call require(result%mass%complete, 'CAP01 A4 required control mass incomplete: '//trim(label))
      call require(abs(result%mass%residual) <= MASS_TOL, 'CAP01 A4 required control hard mass: '//trim(label))
    end if
  end subroutine run_characterization_case

  subroutine characterize_net_root_execution()
    call run_characterization_case('Z', 0.0_real64, .false., .true.)
    call run_characterization_case('B', 2.0e-2_real64, .true., .true.)
    call run_characterization_case('U1', 2.0e-4_real64, .false., .false.)
    call run_characterization_case('U2', 2.0e-3_real64, .false., .false.)
    call run_characterization_case('U3', 2.0e-2_real64, .false., .false.)
    write(*,'(a)') 'HMCAP01_A4_DIAGNOSTIC_MATRIX_COMPLETE=PASS'
  end subroutine characterize_net_root_execution

  subroutine derive_equilibrium_flux(qref)
    real(real64), intent(out) :: qref
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = H0_CM
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    qref = -conductivity(1)
    call require(ieee_is_finite(qref) .and. abs(qref) > 0.0_real64, 'equilibrium reference flux')
    write(*,'(a,es24.16)') 'HMCAP01_EQUILIBRIUM_QBOT=', qref
  end subroutine derive_equilibrium_flux

  subroutine initialize_parameters(p, bottom_mode)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer, intent(in) :: bottom_mode
    integer :: k

    p%parameter_set_id = 590110_int64 + int(bottom_mode, int64)
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
    p%bottom_mode = bottom_mode
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = MASS_TOL
    p%total_balance_tolerance = MASS_TOL
    p%head_abs_tolerance = MASS_TOL
    p%head_rel_tolerance = MASS_TOL
    p%ponding_tolerance = MASS_TOL
    p%root_extraction_active = .true.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f, bottom_flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: bottom_flux
    integer :: rooted

    f%top_flux = bottom_flux
    f%top_head = H0_CM
    f%bottom_flux = bottom_flux
    f%bottom_head = H0_CM
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
         f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
    rooted = min(4, numnod)
    f%root_extraction_sink(1:rooted) = ROOT_TOTAL / real(rooted, real64)
  end subroutine initialize_forcing

  subroutine initialize_column_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id = 590120_int64
    t%physics_topology_id = 590121_int64
    t%vertical_layout_id = 590122_int64
    t%state_layout_id = 590123_int64
    t%solver_interface_id = 590124_int64
    t%optional_state_layout_id = 0_int64
    t%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = COLUMN_ID
    c%template_id = t%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  function corrector_config() result(cfg)
    type(canonical_numerical_config_t) :: cfg
    cfg%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance = 1.0e-6_real64
    cfg%transaction%mass_tolerance = MASS_TOL
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 8
    cfg%max_committed_substeps = 32
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .false.
    cfg%model_temporal_indicator_budget = 0.0_real64
    cfg%accepted_trajectory_direction%requested = .false.
  end function corrector_config

  subroutine initialize_committed_state(state, p)
    type(kernel_committed_state_t), intent(out) :: state
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok
    integer :: i

    heads = H0_CM
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = heads
    physical%water_content = water
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(state, COLUMN_ID, physical, 0.0_real64, ok)
    call require(ok, 'root-active committed state initialization')
  end subroutine initialize_committed_state

  subroutine run_root_candidate(bottom_flux, request_trajectory, result, candidate, diagnostics)
    real(real64), intent(in) :: bottom_flux
    logical, intent(in) :: request_trajectory
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(kernel_checkpoint_t) :: checkpoint
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_reference_backend_t) :: backend
    logical :: ok

    call fmr_capture_checkpoint(committed, checkpoint, ok)
    call require(ok, 'root-active predictor checkpoint')
    forcing = base_forcing
    forcing%bottom_flux = bottom_flux
    cfg = corrector_config()
    cfg%accepted_trajectory_direction%requested = request_trajectory
    cfg%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
    call backend%initialize(top)
    call backend%run_trial(column, template, predictor_parameters, committed, forcing, cfg, &
         window%t0, window%t1, checkpoint, result, candidate, diagnostics)
  end subroutine run_root_candidate

  subroutine materialize_solver_view(candidate, state, parameter_set)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(soil_water_physical_state_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(out) :: parameter_set
    class(transaction_state_t), allocatable :: snapshot
    logical :: ok

    call candidate%snapshot(snapshot, ok)
    call require(ok .and. allocated(snapshot), 'root-active candidate snapshot')
    select type (typed => snapshot)
    class is (fmr_b110_physical_state_t)
      state%active_nodes = typed%active_nodes
      allocate(state%pressure_head(typed%active_nodes), state%water_content(typed%active_nodes))
      state%pressure_head = typed%pressure_head
      state%water_content = typed%water_content
      state%ponding_depth = typed%ponding_depth
      state%groundwater_level = typed%groundwater_level
    class default
      call require(.false., 'root-active candidate physical type')
    end select
    parameter_set%parameter_set_id = predictor_parameters%parameter_set_id
    parameter_set%active_nodes = predictor_parameters%active_nodes
    allocate(parameter_set%z(numnod), parameter_set%dz(numnod), parameter_set%node_distance(numnod))
    parameter_set%z = predictor_parameters%z
    parameter_set%dz = predictor_parameters%dz
    parameter_set%node_distance = predictor_parameters%node_distance
  end subroutine materialize_solver_view

  subroutine materialize_candidate_face(candidate, qbot, face)
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64), intent(in) :: qbot
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    type(soil_water_physical_state_t) :: state
    type(soil_water_parameter_set_t) :: parameter_set
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: face_status

    call materialize_solver_view(candidate, state, parameter_set)
    call constitutive%evaluate(state%pressure_head, water, conductivity, capacity, dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(state%pressure_head(numnod), conductivity(numnod), &
         qbot, 0.5_real64*parameter_set%dz(numnod), datum, face, face_status)
    call require(face_status == MODFLOW6_BOTTOM_FACE_OK .and. face%valid, 'root-active candidate face')
  end subroutine materialize_candidate_face

  subroutine run_endpoint_value(qbot, face)
    real(real64), intent(in) :: qbot
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    call run_root_candidate(qbot, .false., result, candidate, diagnostics)
    call require(result%completed .and. candidate%ready(), 'root-active FD candidate')
    call require(diagnostics%retries == 0, 'root-active FD perturbation changed acceptance topology')
    call materialize_candidate_face(candidate, qbot, face)
  end subroutine run_endpoint_value

  subroutine materialize_origin_face(qbot, face)
    real(real64), intent(in) :: qbot
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: face_status, i
    heads = H0_CM
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod), conductivity(numnod), qbot, &
         0.5_real64*predictor_parameters%dz(numnod), datum, face, face_status)
    call require(face_status == MODFLOW6_BOTTOM_FACE_OK .and. face%valid, 'root-active origin face')
  end subroutine materialize_origin_face

  subroutine assert_materialized_root_sink(mat, head_m)
    type(fmr_groundwater_head_forcing_materializer_t), intent(in) :: mat
    real(real64), intent(in) :: head_m
    integer :: local_status
    if (allocated(materialized)) deallocate(materialized)
    call mat%materialize(head_m, datum, materialized, local_status)
    call require(local_status == 0 .and. allocated(materialized), 'root-active materialized forcing')
    select type (typed => materialized)
    type is (fmr_b110_physical_forcing_t)
      call require(allocated(typed%root_extraction_sink), 'root-active materialized root sink missing')
      call require(size(typed%root_extraction_sink) == size(base_forcing%root_extraction_sink), &
           'root-active materialized root sink shape')
      call require(all(typed%root_extraction_sink == base_forcing%root_extraction_sink), &
           'root-active materializer changed root sink')
    class default
      call require(.false., 'root-active materializer returned wrong forcing type')
    end select
  end subroutine assert_materialized_root_sink

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'HMCAP01_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_hydro_memory_cap01_root_active_response
