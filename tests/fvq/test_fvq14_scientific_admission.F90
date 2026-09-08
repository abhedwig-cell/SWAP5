program test_fvq14_scientific_admission
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED, &
       KERNEL_STATUS_CHECKPOINT_MISMATCH
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  integer(int64), parameter :: column_id = 41401_int64
  integer(int64), parameter :: template_id = 414_int64
  integer(int64), parameter :: lineage_id = 41401_int64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters, bad_parameters
  type(fmr_b110_physical_forcing_t) :: forcing, bad_forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_serialized_reference_backend_t), target :: backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate, replay_candidate, rejected_candidate
  type(kernel_result_t) :: result, replay_result, rejected_result
  type(kernel_diagnostics_t) :: diagnostics, replay_diagnostics, rejected_diagnostics
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_physical_observation_t) :: observation
  type(canonical_numerical_config_t) :: config

  type(soil_water_parameter_set_t), target :: ref_soil_parameters
  type(b110_default_mvg_parameters_t), target :: ref_hyd_parameters
  type(b110_default_mvg_provider_t), target :: ref_constitutive
  type(b110_source_sink_provider_t), target :: ref_source_sink
  type(reference_richards_legacy_solver_t) :: ref_solver
  type(reference_richards_legacy_workspace_t) :: ref_workspace
  type(soil_water_solve_request_t) :: ref_request
  type(soil_water_solve_result_t) :: ref_result

  class(transaction_state_t), allocatable :: candidate_snapshot
  integer(int64) :: revision0, revision1, committed_fp0, candidate_fp1, candidate_fp2
  integer(int64) :: reference_fp
  real(real64) :: committed_time, initial_storage, endpoint_storage
  real(real64) :: independent_total_in, independent_total_out, independent_balance
  logical :: ok, available, got_snapshot, did_commit, context_ok
  integer :: commit_status

  call configure_fixture(column, template, parameters, forcing, initial_state, initial_storage)
  call configure_transaction(config)
  call backend%initialize(top_provider)
  call fmr_new_b110_committed_state(committed, lineage_id, initial_state, t0, ok)
  call require(ok, 'committed state initialization')
  revision0 = committed%current_revision()
  committed_fp0 = committed_fingerprint(committed)
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'checkpoint capture')

  ! Candidate route: F-MR serialized runtime -> F-KT canonical transaction kernel -> F-SI -> real HeadCalc.
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       result, candidate, diagnostics)
  call require(result%completed .and. candidate%ready(), 'candidate physical trial completed')
  call require(result%mass%complete, 'authoritative full interval mass complete')
  call require(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'authoritative missing mask zero')
  observation = backend%observation()
  call require(observation%solver_executed, 'real HeadCalc executed in candidate route')
  call require(trim(observation%solver_diagnostics%route) == 'legacy-reference-bound', 'candidate solver route')

  ! Independent corrected-B1.10-bound reference seam: same initial state/request through the qualified F-SI route.
  call configure_reference_request(parameters, forcing, initial_state, ref_soil_parameters, ref_hyd_parameters, &
       ref_constitutive, ref_source_sink, ref_request)
  call bind_b110_serialized_legacy_context(ref_request, context_ok)
  call require(context_ok, 'reference legacy context binding')
  call ref_solver%solve(ref_request, ref_workspace, ref_result)
  call require(ref_result%status == SW_SOLVE_CONVERGED, 'reference F-SI solver converged')
  call require(trim(ref_result%diagnostics%route) == 'legacy-reference-bound', 'reference solver route')

  call candidate%snapshot(candidate_snapshot, got_snapshot)
  call require(got_snapshot, 'candidate snapshot available')
  select type (physical => candidate_snapshot)
  type is (fmr_b110_physical_state_t)
    call require(physical%active_nodes == ref_result%candidate_state%active_nodes, 'reference node count identity')
    call require(real_array_bitwise_equal(physical%pressure_head, ref_result%candidate_state%pressure_head), &
         'endpoint pressure head bitwise identity')
    call require(real_array_bitwise_equal(physical%water_content, ref_result%candidate_state%water_content), &
         'endpoint water content bitwise identity')
    call require(real_bitwise_equal(physical%ponding_depth, ref_result%candidate_state%ponding_depth), &
         'endpoint ponding bitwise identity')
    call require(real_bitwise_equal(physical%groundwater_level, ref_result%candidate_state%groundwater_level), &
         'endpoint groundwater bitwise identity')
    endpoint_storage = sum(parameters%dz*physical%water_content) + physical%ponding_depth
    reference_fp = physical_state_fingerprint(ref_result%candidate_state%active_nodes, &
         ref_result%candidate_state%pressure_head, ref_result%candidate_state%water_content, &
         ref_result%candidate_state%ponding_depth, ref_result%candidate_state%groundwater_level)
  class default
    error stop 'F-VQ14 unexpected candidate state type'
  end select

  call require(real_bitwise_equal(observation%top_flux, ref_result%top_flux), 'top flux bitwise identity')
  call require(real_bitwise_equal(observation%bottom_flux, ref_result%bottom_flux), 'bottom flux bitwise identity')
  call require(observation%solver_diagnostics%nonlinear_iterations == ref_result%diagnostics%nonlinear_iterations, &
       'nonlinear iteration identity')
  call require(observation%solver_diagnostics%jacobian_builds == ref_result%diagnostics%jacobian_builds, &
       'jacobian build identity')
  call require(observation%solver_diagnostics%linear_solves == ref_result%diagnostics%linear_solves, &
       'linear solve identity')

  candidate_fp1 = candidate_fingerprint(candidate)
  call require(candidate_fp1 == reference_fp, 'candidate/reference physical fingerprint identity')

  call independent_mass(forcing, observation, t1-t0, initial_storage, endpoint_storage, &
       independent_total_in, independent_total_out, independent_balance)
  call require(real_bitwise_equal(result%mass%storage_start, initial_storage), 'mass storage start bitwise identity')
  call require(real_bitwise_equal(result%mass%storage_end, endpoint_storage), 'mass storage end bitwise identity')
  call require(real_bitwise_equal(result%mass%total_in, independent_total_in), 'mass total inflow bitwise identity')
  call require(real_bitwise_equal(result%mass%total_out, independent_total_out), 'mass total outflow bitwise identity')
  call require(result%mass%residual == 0.0_real64, 'authoritative mass residual exact zero')
  call require(independent_balance == 0.0_real64, 'independent balance residual exact zero')

  ! Rollback and replay on the same real physical route.
  call fmr_discard_candidate(transaction_control, candidate, diagnostics)
  call require(.not. candidate%ready(), 'candidate discarded')
  call require(committed%current_revision() == revision0, 'rollback revision unchanged')
  call committed%current_time(committed_time, available)
  call require(available .and. real_bitwise_equal(committed_time,t0), 'rollback time unchanged')
  call require(committed_fingerprint(committed) == committed_fp0, 'rollback committed physics unchanged')

  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       replay_result, replay_candidate, replay_diagnostics)
  call require(replay_result%completed .and. replay_candidate%ready(), 'replay candidate materialized')
  call require(replay_result%mass%complete .and. replay_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
       'replay authoritative mass complete')
  candidate_fp2 = candidate_fingerprint(replay_candidate)
  call require(candidate_fp2 == candidate_fp1, 'replay candidate identity')
  call require(real_bitwise_equal(replay_result%mass%residual,result%mass%residual), 'replay mass identity')
  call require(real_bitwise_equal(replay_diagnostics%max_abs_step_mass_residual, diagnostics%max_abs_step_mass_residual), &
       'replay diagnostic identity')

  ! Unsupported physics remains fail closed.
  bad_parameters = parameters
  bad_parameters%root_extraction_active = .true.
  call expect_not_admitted('active-root-parameter', bad_parameters)
  bad_parameters = parameters
  bad_parameters%macropore_active = .true.
  call expect_not_admitted('macropore', bad_parameters)
  bad_parameters = parameters
  bad_parameters%snow_active = .true.
  call expect_not_admitted('snow', bad_parameters)
  bad_parameters = parameters
  bad_parameters%swkimpl = 1
  call expect_not_admitted('swkimpl1', bad_parameters)
  bad_parameters = parameters
  bad_parameters%bottom_mode = 1
  call expect_not_admitted('unsupported-bottom-mode', bad_parameters)
  bad_forcing = forcing
  bad_forcing%root_extraction_sink(1) = 1.0e-8_real64
  call backend%run_trial(column, template, parameters, committed, bad_forcing, config, t0, t1, checkpoint, &
       rejected_result, rejected_candidate, rejected_diagnostics)
  call require(.not. rejected_result%completed .and. .not. rejected_candidate%ready(), 'nonzero qrot rejected')
  call require(committed_fingerprint(committed) == committed_fp0, 'qrot rejection leaves committed state unchanged')

  ! Commit and stale checkpoint fail-closed behaviour.
  call fmr_commit_candidate(transaction_control, committed, replay_candidate, replay_diagnostics, did_commit, commit_status)
  call require(did_commit, 'commit accepted')
  revision1 = committed%current_revision()
  call require(revision1 == revision0 + 1_int64, 'commit revision increments once')
  call committed%current_time(committed_time, available)
  call require(available .and. real_bitwise_equal(committed_time,t1), 'commit time equals t1')
  call require(committed_fingerprint(committed) == candidate_fp2, 'commit endpoint identity')

  call backend%run_trial(column, template, parameters, committed, forcing, config, t1, t1+(t1-t0), checkpoint, &
       rejected_result, rejected_candidate, rejected_diagnostics)
  call require(rejected_result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'stale checkpoint rejected')
  call require(.not. rejected_candidate%ready(), 'stale checkpoint no candidate')
  call require(rejected_diagnostics%checkpoint_revision_rejections == 1, 'stale checkpoint diagnosed')

  write(*,'(A)') 'FVQ14_SOURCE_PROFILE=FMR04_RESTRICTED_DEFAULT_MVG_SWKIMPL0_ROOT0_MACRO0_SNOW0'
  write(*,'(A,F0.12)') 'FVQ14_T0=', t0
  write(*,'(A,F0.12)') 'FVQ14_T1=', t1
  write(*,'(A,F0.12)') 'FVQ14_DURATION=', t1-t0
  write(*,'(A,I0)') 'FVQ14_ACTIVE_NODES=', parameters%active_nodes
  write(*,'(A,I0)') 'FVQ14_CANDIDATE_FINGERPRINT=', candidate_fp2
  write(*,'(A,I0)') 'FVQ14_REFERENCE_FINGERPRINT=', reference_fp
  write(*,'(A,ES26.17E3)') 'FVQ14_TOP_FLUX=', observation%top_flux
  write(*,'(A,ES26.17E3)') 'FVQ14_BOTTOM_FLUX=', observation%bottom_flux
  write(*,'(A,I0)') 'FVQ14_SOLVER_ITERATIONS=', observation%solver_diagnostics%nonlinear_iterations
  write(*,'(A,A)') 'FVQ14_SOLVER_ROUTE=', trim(observation%solver_diagnostics%route)
  write(*,'(A,ES26.17E3)') 'FVQ14_STORAGE_START=', result%mass%storage_start
  write(*,'(A,ES26.17E3)') 'FVQ14_STORAGE_END=', result%mass%storage_end
  write(*,'(A,ES26.17E3)') 'FVQ14_TOTAL_IN=', result%mass%total_in
  write(*,'(A,ES26.17E3)') 'FVQ14_TOTAL_OUT=', result%mass%total_out
  write(*,'(A,ES26.17E3)') 'FVQ14_AUTHORITATIVE_RESIDUAL=', result%mass%residual
  write(*,'(A,ES26.17E3)') 'FVQ14_INDEPENDENT_BALANCE=', independent_balance
  write(*,'(A,I0)') 'FVQ14_MISSING_MASK=', result%mass%missing_contribution_mask
  write(*,'(A,L1)') 'FVQ14_MASS_COMPLETE=', result%mass%complete
  write(*,'(A)') 'FVQ14_ENDPOINT_HEAD_IDENTITY=PASS_BITWISE'
  write(*,'(A)') 'FVQ14_ENDPOINT_THETA_IDENTITY=PASS_BITWISE'
  write(*,'(A)') 'FVQ14_TOP_BOTTOM_FLUX_IDENTITY=PASS_BITWISE'
  write(*,'(A)') 'FVQ14_REFERENCE_ROUTE=PASS_CORRECTED_B110_BOUND_FSI09_REAL_HEADCALC'
  write(*,'(A)') 'FVQ14_REAL_HEADCALC_EXECUTED=TRUE'
  write(*,'(A)') 'FVQ14_ROLLBACK=PASS'
  write(*,'(A)') 'FVQ14_REPLAY=PASS'
  write(*,'(A)') 'FVQ14_COMMIT=PASS'
  write(*,'(A)') 'FVQ14_STALE_CHECKPOINT=PASS_FAIL_CLOSED'
  write(*,'(A)') 'FVQ14_GENERIC_TIME=PASS_NONMIDNIGHT_SUBDAILY'
  write(*,'(A)') 'FVQ14_UNSUPPORTED_PHYSICS=PASS_FAIL_CLOSED'
  write(*,'(A)') 'FVQ14_RETRY_SUBGATE=NOT_TESTED_NO_SAFE_PHYSICAL_FAILURE_INDUCTION'
  write(*,'(A)') 'FVQ14_SCIENTIFIC_HARNESS PASS'

contains

  subroutine configure_fixture(col, tmpl, p, f, state, storage0)
    type(fmr_logical_column_t), intent(out) :: col
    type(fmr_template_t), intent(out) :: tmpl
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: storage0
    type(b110_default_mvg_parameters_t), target :: hyd
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    col%column_id = column_id
    col%template_id = template_id
    col%parameter_ref = 1_int64
    col%state_handle = 1_int64
    col%forcing_handle = 1_int64
    col%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    tmpl%template_id = template_id
    tmpl%physics_topology_id = 41401_int64
    tmpl%vertical_layout_id = 41402_int64
    tmpl%state_layout_id = 41403_int64
    tmpl%solver_interface_id = 41404_int64
    tmpl%optional_state_layout_id = 0_int64
    tmpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    p%parameter_set_id = 41401_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do i = 1, numnod
      p%cofgen(1,i) = 0.032_real64
      p%cofgen(2,i) = 0.423_real64
      p%cofgen(3,i) = 4.75_real64
      p%cofgen(4,i) = 0.0135_real64
      p%cofgen(5,i) = 0.365_real64
      p%cofgen(6,i) = 1.455_real64
      p%cofgen(7,i) = 1.0_real64 - 1.0_real64/p%cofgen(6,i)
      p%cofgen(8,i) = p%cofgen(4,i)
      p%cofgen(9,i) = 0.0_real64
      p%cofgen(10,i) = p%cofgen(3,i)
      p%cofgen(11,i) = 0.999_real64
      p%cofgen(12,i) = 0.99_real64*p%cofgen(3,i)
      p%cofgen(22,i) = -1.0e6_real64
      p%cofgen(23,i) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
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

    call initialize_b110_default_mvg_parameters(hyd, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(conductivity == conductivity(1)), 'fixture uniform conductivity')

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    storage0 = sum(dz*water)

    f%top_flux = -conductivity(1)
    f%top_head = head0
    f%bottom_flux = -conductivity(1)
    f%bottom_head = -100.0_real64
    allocate(f%drainage_flux_by_level(2,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    do i = 1, numnod
      f%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
      f%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
      f%subsurface_irrigation_source(i) = f%drainage_flux_by_level(1,i) + f%drainage_flux_by_level(2,i)
      f%root_extraction_sink(i) = 0.0_real64
    end do
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine configure_fixture

  subroutine configure_transaction(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_tolerance = 0.0_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine configure_reference_request(p, f, state, soil, hyd, constitutive, source_sink, request)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_forcing_t), intent(in) :: f
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(soil_water_parameter_set_t), target, intent(out) :: soil
    type(b110_default_mvg_parameters_t), target, intent(out) :: hyd
    type(b110_default_mvg_provider_t), target, intent(out) :: constitutive
    type(b110_source_sink_provider_t), target, intent(out) :: source_sink
    type(soil_water_solve_request_t), intent(out) :: request

    soil%parameter_set_id = p%parameter_set_id
    soil%active_nodes = p%active_nodes
    allocate(soil%z(p%active_nodes), soil%dz(p%active_nodes), soil%node_distance(p%active_nodes))
    soil%z = p%z
    soil%dz = p%dz
    soil%node_distance = p%node_distance
    call initialize_b110_default_mvg_parameters(hyd, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd, t1-t0)
    call bind_b110_source_sink_provider(source_sink, f%drainage_flux_by_level, f%subsurface_irrigation_source, &
         f%root_extraction_sink)

    request%parameters => soil
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => top_provider
    request%step_duration = t1-t0
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = p%bottom_mode
    request%boundary%top_flux = f%top_flux
    request%boundary%top_head = f%top_head
    request%boundary%bottom_flux = f%bottom_flux
    request%boundary%bottom_head = f%bottom_head
    request%numerical%max_iterations = p%max_iterations
    request%numerical%max_backtracking = p%max_backtracking
    request%numerical%conductivity_implicit_mode = p%swkimpl
    request%numerical%conductivity_mean_method = p%swkmean
    request%numerical%min_step_duration = p%min_step_duration
    request%numerical%compartment_balance_tolerance = p%compartment_balance_tolerance
    request%numerical%total_balance_tolerance = p%total_balance_tolerance
    request%numerical%head_abs_tolerance = p%head_abs_tolerance
    request%numerical%head_rel_tolerance = p%head_rel_tolerance
    request%numerical%ponding_tolerance = p%ponding_tolerance
    request%base_state%active_nodes = state%active_nodes
    allocate(request%base_state%pressure_head(state%active_nodes), request%base_state%water_content(state%active_nodes))
    request%base_state%pressure_head = state%pressure_head
    request%base_state%water_content = state%water_content
    request%base_state%ponding_depth = state%ponding_depth
    request%base_state%groundwater_level = state%groundwater_level
  end subroutine configure_reference_request

  subroutine expect_not_admitted(label, bad)
    character(len=*), intent(in) :: label
    type(fmr_b110_physical_parameters_t), intent(in) :: bad
    call backend%run_trial(column, template, bad, committed, forcing, config, t0, t1, checkpoint, &
         rejected_result, rejected_candidate, rejected_diagnostics)
    call require(rejected_result%status == KERNEL_STATUS_NOT_ADMITTED, trim(label)//' status')
    call require(.not. rejected_candidate%ready(), trim(label)//' no candidate')
    call require(rejected_diagnostics%admission_rejections == 1, trim(label)//' admission diagnostic')
    call require(committed_fingerprint(committed) == committed_fp0, trim(label)//' committed state unchanged')
  end subroutine expect_not_admitted

  subroutine independent_mass(f, obs, duration, storage_start, storage_end, total_in, total_out, balance)
    type(fmr_b110_physical_forcing_t), intent(in) :: f
    type(fmr_serialized_physical_observation_t), intent(in) :: obs
    real(real64), intent(in) :: duration, storage_start, storage_end
    real(real64), intent(out) :: total_in, total_out, balance
    integer :: i, level
    real(real64) :: amount
    total_in = max(0.0_real64,-obs%top_flux)*duration + max(0.0_real64,obs%bottom_flux)*duration
    total_out = max(0.0_real64,obs%top_flux)*duration + max(0.0_real64,-obs%bottom_flux)*duration
    do i = 1, size(f%subsurface_irrigation_source)
      amount = f%subsurface_irrigation_source(i)*duration
      if (amount >= 0.0_real64) then
        total_in = total_in + amount
      else
        total_out = total_out - amount
      end if
    end do
    do level = 1, size(f%drainage_flux_by_level,1)
      do i = 1, size(f%drainage_flux_by_level,2)
        amount = f%drainage_flux_by_level(level,i)*duration
        if (amount >= 0.0_real64) then
          total_out = total_out + amount
        else
          total_in = total_in - amount
        end if
      end do
    end do
    balance = storage_start + total_in - total_out - storage_end
  end subroutine independent_mass

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = snapshot_fingerprint(snapshot)
  end function committed_fingerprint

  integer(int64) function candidate_fingerprint(state) result(fp)
    type(kernel_candidate_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'candidate snapshot')
    fp = snapshot_fingerprint(snapshot)
  end function candidate_fingerprint

  integer(int64) function snapshot_fingerprint(snapshot) result(fp)
    class(transaction_state_t), intent(in) :: snapshot
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = physical_state_fingerprint(physical%active_nodes, physical%pressure_head, physical%water_content, &
           physical%ponding_depth, physical%groundwater_level)
    class default
      error stop 'F-VQ14 unexpected physical state type'
    end select
  end function snapshot_fingerprint

  integer(int64) function physical_state_fingerprint(active_nodes, heads, water, pond, gwl) result(fp)
    integer, intent(in) :: active_nodes
    real(real64), intent(in) :: heads(:), water(:), pond, gwl
    integer :: i
    fp = 1469598103934665603_int64
    fp = ieor(fp, int(active_nodes,int64))
    do i = 1, active_nodes
      fp = ieor(fp, transfer(heads(i),fp))
      fp = ieor(fp, transfer(water(i),fp))
    end do
    fp = ieor(fp, transfer(pond,fp))
    fp = ieor(fp, transfer(gwl,fp))
  end function physical_state_fingerprint

  logical function real_array_bitwise_equal(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    real_array_bitwise_equal = size(a) == size(b)
    if (.not. real_array_bitwise_equal) return
    do i=1,size(a)
      if (.not. real_bitwise_equal(a(i),b(i))) then
        real_array_bitwise_equal = .false.
        return
      end if
    end do
  end function real_array_bitwise_equal

  logical function real_bitwise_equal(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    real_bitwise_equal = ia == ib
  end function real_bitwise_equal

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ14_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq14_scientific_admission
