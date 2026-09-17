program test_fvq105_fgc31_active_drainage_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_TABULATED
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_smooth_freatic_projection, only: b110_smooth_freatic_projection_diagnostics_t, &
       evaluate_b110_smooth_freatic_projection, B110_GWL_PROJECTION_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK, &
       MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE
  implicit none

  real(real64), parameter :: duration = 1.0e-2_real64
  real(real64), parameter :: mass_tolerance = 1.0e-10_real64
  real(real64), parameter :: qbot0 = 1.5e-3_real64
  real(real64), parameter :: fd_h = 2.5e-6_real64
  real(real64), parameter :: fd_rel_gate = 1.25e-3_real64
  real(real64), parameter :: temporal_budget = 1.0_real64
  integer(int64), parameter :: column_id = 105031_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(groundwater_head_datum_t) :: datum
  type(kernel_result_t) :: tangent_result, plain_result
  type(kernel_candidate_state_t) :: tangent_candidate, plain_candidate
  type(kernel_diagnostics_t) :: tangent_diag, plain_diag
  type(soil_water_physical_state_t) :: tangent_state, plain_state
  type(soil_water_parameter_set_t) :: solver_parameters
  type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint, fail_endpoint
  type(accepted_trajectory_direction_result_t) :: bad_trajectory
  real(real64), allocatable :: hm2(:), hm1(:), hp1(:), hp2(:), fd_head(:)
  real(real64) :: fm2, fm1, fp1, fp2, fd_face
  real(real64) :: gm2, gm1, gp1, gp2, fd_gwl, analytic_gwl, analytic_dgwl
  real(real64) :: head_error, face_error, gwl_error, scale
  integer :: status
  logical :: ok

  call initialize_parameters(parameters)
  call initialize_column_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, duration)

  datum%available = .true.
  datum%datum_id = 105031_int64
  datum%bottom_boundary_elevation_m = 0.0_real64

  call run_candidate(qbot0, .true., tangent_result, tangent_candidate, tangent_diag)
  call require(tangent_result%status == CANONICAL_STATUS_COMPLETED .and. tangent_result%completed, &
       'tangent production interval completed')
  call require(tangent_candidate%ready(), 'tangent candidate ready')
  call require(tangent_diag%accepted_substeps >= 2, 'independent oracle requires multi-substep acceptance')
  call require(tangent_result%accepted_trajectory_direction%available, 'accepted trajectory tangent available')
  call require(tangent_result%accepted_trajectory_direction%accepted_steps == tangent_diag%accepted_substeps, &
       'accepted trajectory provenance count')
  call require(tangent_result%accepted_trajectory_direction%source_sink_direction_coverage_complete, &
       'whole-trajectory source/sink coverage complete')
  call require(tangent_result%accepted_trajectory_direction%additional_full_nonlinear_solves == 0, &
       'no additional nonlinear solves')
  call require(tangent_result%accepted_trajectory_direction%additional_jacobian_builds == 0, &
       'no additional Jacobian builds')

  call materialize_solver_view(tangent_candidate, tangent_state, solver_parameters)
  call build_modflow6_swap_predictor_tangent_endpoint(tangent_state, solver_parameters, constitutive, &
       tangent_result%accepted_trajectory_direction, qbot0, datum, .false., .false., .true., .false., endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_OK .and. endpoint%authoritative .and. endpoint%available, &
       'active-drainage endpoint authoritative')
  call require(endpoint%coverage%drainage_active .and. endpoint%coverage%drainage_covered .and. &
       endpoint%coverage%tangent_complete(), 'active drainage coverage complete')

  call run_candidate(qbot0, .false., plain_result, plain_candidate, plain_diag)
  call require(plain_result%status == CANONICAL_STATUS_COMPLETED .and. plain_result%completed, &
       'plain production interval completed')
  call require(plain_diag%accepted_substeps == tangent_diag%accepted_substeps .and. &
       plain_diag%retries == tangent_diag%retries, 'tangent request changed execution topology')
  call materialize_solver_view(plain_candidate, plain_state, solver_parameters)
  call require(bits_equal_vector(tangent_state%pressure_head, plain_state%pressure_head), &
       'tangent changed physical pressure state')
  call require(bits_equal_vector(tangent_state%water_content, plain_state%water_content), &
       'tangent changed physical water state')
  call require(bits_equal_scalar(tangent_state%groundwater_level, plain_state%groundwater_level), &
       'tangent changed physical GWL')
  call require(bits_equal_scalar(tangent_result%terminal_bottom_outward_flux_native, &
       plain_result%terminal_bottom_outward_flux_native), 'tangent changed terminal qbot')

  allocate(hm2(numnod), hm1(numnod), hp1(numnod), hp2(numnod), fd_head(numnod))
  call run_fd(qbot0-2.0_real64*fd_h, hm2, fm2, gm2, plain_diag)
  call run_fd(qbot0-fd_h, hm1, fm1, gm1, plain_diag)
  call run_fd(qbot0+fd_h, hp1, fp1, gp1, plain_diag)
  call run_fd(qbot0+2.0_real64*fd_h, hp2, fp2, gp2, plain_diag)

  fd_head = (hm2 - 8.0_real64*hm1 + 8.0_real64*hp1 - hp2)/(12.0_real64*fd_h)
  fd_face = (fm2 - 8.0_real64*fm1 + 8.0_real64*fp1 - fp2)/(12.0_real64*fd_h)
  fd_gwl = (gm2 - 8.0_real64*gm1 + 8.0_real64*gp1 - gp2)/(12.0_real64*fd_h)

  head_error = maxval(abs(fd_head - tangent_result%accepted_trajectory_direction%final_pressure_head_direction))
  scale = max(1.0_real64, maxval(abs(fd_head)), &
       maxval(abs(tangent_result%accepted_trajectory_direction%final_pressure_head_direction)))
  call require(head_error <= fd_rel_gate*scale, 'five-point final-head tangent agreement')

  face_error = abs(fd_face - endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day)
  scale = max(1.0_real64, abs(fd_face), abs(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day))
  call require(face_error <= fd_rel_gate*scale, 'five-point fixed-face tangent agreement')

  call terminal_gwl_direction(tangent_state, tangent_result%accepted_trajectory_direction%final_pressure_head_direction, &
       analytic_gwl, analytic_dgwl, ok)
  call require(ok, 'terminal GWL directional projection available')
  gwl_error = abs(fd_gwl-analytic_dgwl)
  scale = max(1.0_real64, abs(fd_gwl), abs(analytic_dgwl))
  call require(gwl_error <= fd_rel_gate*scale, 'five-point terminal GWL tangent agreement')

  bad_trajectory = tangent_result%accepted_trajectory_direction
  bad_trajectory%source_sink_direction_coverage_complete = .false.
  call build_modflow6_swap_predictor_tangent_endpoint(tangent_state, solver_parameters, constitutive, &
       bad_trajectory, qbot0, datum, .false., .false., .true., .false., fail_endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE .and. fail_endpoint%available .and. &
       .not. fail_endpoint%authoritative, 'missing drainage coverage did not fail closed')

  call build_modflow6_swap_predictor_tangent_endpoint(tangent_state, solver_parameters, constitutive, &
       tangent_result%accepted_trajectory_direction, qbot0, datum, .false., .true., .true., .false., fail_endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE .and. .not. fail_endpoint%authoritative, &
       'uncovered root uptake did not fail closed')

  write(*,'(A,I0)') 'FVQ105_ACCEPTED_SUBSTEPS=',tangent_diag%accepted_substeps
  write(*,'(A,I0)') 'FVQ105_RETRIES=',tangent_diag%retries
  write(*,'(A,1X,ES14.6)') 'FVQ105_HEAD_FIVE_POINT_MAX_ERROR=',head_error
  write(*,'(A,1X,ES14.6)') 'FVQ105_FACE_FIVE_POINT_ERROR=',face_error
  write(*,'(A,1X,ES14.6)') 'FVQ105_GWL_FIVE_POINT_ERROR=',gwl_error
  write(*,'(A)') 'FVQ105_MULTI_SUBSTEP_ACTIVE_DRAINAGE=PASS'
  write(*,'(A)') 'FVQ105_FIVE_POINT_PRODUCTION_FD=PASS'
  write(*,'(A)') 'FVQ105_TANGENT_PHYSICAL_IDENTITY=PASS'
  write(*,'(A)') 'FVQ105_DRAINAGE_COVERAGE_PROVENANCE=PASS'
  write(*,'(A)') 'FVQ105_TERMINAL_GWL_DIRECTION=PASS'
  write(*,'(A)') 'FVQ105_FAIL_CLOSED_INCOMPLETE_COVERAGE=PASS'
  write(*,'(A)') 'FVQ105_NO_EXTRA_NONLINEAR_SOLVE=PASS'
  write(*,'(A)') 'FVQ105_INDEPENDENT_ORACLE=PASS'

contains

  subroutine terminal_gwl_direction(state, direction, gwl, dgwl, available)
    type(soil_water_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: direction(:)
    real(real64), intent(out) :: gwl, dgwl
    logical, intent(out) :: available
    type(b110_smooth_freatic_projection_diagnostics_t) :: d
    call evaluate_b110_smooth_freatic_projection(SW_STEP_CONTROL_BOTTOM_FLUX, .false., solver_parameters%z, &
         solver_parameters%node_distance, state%pressure_head, direction, gwl, dgwl, d)
    available = d%status == B110_GWL_PROJECTION_OK .and. d%value_defined .and. d%direction_defined
  end subroutine terminal_gwl_direction

  subroutine run_fd(qbot, heads, face_head, gwl, expected)
    real(real64), intent(in) :: qbot
    real(real64), intent(out) :: heads(:), face_head, gwl
    type(kernel_diagnostics_t), intent(in) :: expected
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(soil_water_physical_state_t) :: state
    type(soil_water_parameter_set_t) :: p
    type(modflow6_prescribed_qbot_bottom_face_t) :: face
    real(real64) :: theta(numnod), conductivity(numnod), capacity(numnod), reserved(numnod)
    integer :: face_status

    call run_candidate(qbot, .false., result, candidate, diagnostics)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'FD production interval completed')
    call require(diagnostics%accepted_substeps == expected%accepted_substeps .and. diagnostics%retries == expected%retries, &
         'FD execution topology changed')
    call materialize_solver_view(candidate, state, p)
    heads = state%pressure_head
    gwl = state%groundwater_level
    call constitutive%evaluate(state%pressure_head, theta, conductivity, capacity, reserved)
    call materialize_modflow6_prescribed_qbot_bottom_face(state%pressure_head(numnod), conductivity(numnod), qbot, &
         0.5_real64*p%dz(numnod), datum, face, face_status)
    call require(face_status == MODFLOW6_BOTTOM_FACE_OK .and. face%valid, 'FD fixed face materialized')
    face_head = face%pressure_head_cm
  end subroutine run_fd

  subroutine run_candidate(qbot, request_direction, result, candidate, diagnostics)
    real(real64), intent(in) :: qbot
    logical, intent(in) :: request_direction
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    logical :: initialized

    call initialize_committed(committed, initialized)
    call require(initialized, 'committed state initialized')
    call fmr_capture_checkpoint(committed, checkpoint, initialized)
    call require(initialized, 'checkpoint captured')
    call initialize_forcing(forcing, qbot)
    call initialize_config(config, request_direction)
    call backend%initialize(top)
    call backend%run_trial(column, template, parameters, committed, forcing, config, 0.0_real64, duration, &
         checkpoint, result, candidate, diagnostics)
  end subroutine run_candidate

  subroutine initialize_parameters(value)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    integer :: k
    value%parameter_set_id = 105031_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z; value%dz = dz; value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do k=1,numnod
      value%cofgen(1,k)=0.032_real64; value%cofgen(2,k)=0.423_real64; value%cofgen(3,k)=4.75_real64
      value%cofgen(4,k)=0.0135_real64; value%cofgen(5,k)=0.365_real64; value%cofgen(6,k)=1.455_real64
      value%cofgen(7,k)=1.0_real64-1.0_real64/value%cofgen(6,k); value%cofgen(8,k)=value%cofgen(4,k)
      value%cofgen(9,k)=0.0_real64; value%cofgen(10,k)=value%cofgen(3,k); value%cofgen(11,k)=0.999_real64
      value%cofgen(12,k)=0.99_real64*value%cofgen(3,k); value%cofgen(22,k)=-1.0e6_real64
      value%cofgen(23,k)=1.0e-12_real64
    end do
    value%bottom_mode = SW_STEP_CONTROL_BOTTOM_FLUX
    value%swkimpl=0; value%swkmean=1; value%swsophy=0
    value%max_iterations=18; value%max_backtracking=9; value%min_step_duration=1.0e-10_real64
    value%compartment_balance_tolerance=mass_tolerance; value%total_balance_tolerance=mass_tolerance
    value%head_abs_tolerance=1.0e-12_real64; value%head_rel_tolerance=1.0e-12_real64
    value%ponding_tolerance=1.0e-12_real64
    value%root_extraction_active=.false.; value%macropore_active=.false.; value%snow_active=.false.
    value%hysteresis_active=.false.; value%tabulated_hydraulics_active=.false.
    value%elasticity_active=.false.; value%frost_active=.false.; value%soil_temperature_active=.false.
    value%drainage_response_active=.true.; value%drainage_qbot_smooth_freatic_projection=.true.
    allocate(value%drainage_response_levels(3))
    do k=1,3
      value%drainage_response_levels(k)%variant = FMR_DRAIN_VARIANT_TABULATED
      allocate(value%drainage_response_levels(k)%tabulated%groundwater_depth(2), &
           value%drainage_response_levels(k)%tabulated%signed_exchange_rate(2))
      value%drainage_response_levels(k)%tabulated%groundwater_depth=[0.5_real64,2.5_real64]
    end do
    value%drainage_response_levels(1)%tabulated%signed_exchange_rate=[3.5e-3_real64,7.5e-4_real64]
    value%drainage_response_levels(2)%tabulated%signed_exchange_rate=[1.25e-3_real64,-7.5e-4_real64]
    value%drainage_response_levels(3)%tabulated%signed_exchange_rate=[8.0e-4_real64,2.0e-4_real64]
  end subroutine initialize_parameters

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=1050311_int64; t%physics_topology_id=1050312_int64; t%vertical_layout_id=1050313_int64
    t%state_layout_id=1050314_int64; t%solver_interface_id=1050315_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_forcing(value,qbot)
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    real(real64), intent(in) :: qbot
    value%top_flux=0.0_real64; value%top_head=-999.0_real64
    value%bottom_flux=qbot; value%bottom_head=-999.0_real64
    allocate(value%drainage_response_controls(3), value%subsurface_irrigation_source(numnod), &
         value%root_extraction_sink(numnod))
    value%subsurface_irrigation_source=0.0_real64
    value%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_config(config, request_direction)
    type(canonical_numerical_config_t), intent(out) :: config
    logical, intent(in) :: request_direction
    config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=mass_tolerance
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=12
    config%max_committed_substeps=32
    config%progress_tolerance=0.0_real64
    config%model_temporal_indicator_budget_available=.true.
    config%model_temporal_indicator_budget=temporal_budget
    config%accepted_trajectory_direction%requested=request_direction
    config%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
  end subroutine initialize_config

  subroutine initialize_committed(committed, initialized)
    type(kernel_committed_state_t), intent(out) :: committed
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: previous_right(numnod)
    heads=[-2.15_real64,-1.15_real64,-0.15_real64,0.85_real64]
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-0.37_real64
    previous_right=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed,column_id,state,0.0_real64,initialized,previous_right)
  end subroutine initialize_committed

  subroutine materialize_solver_view(candidate,state,p)
    type(kernel_candidate_state_t),intent(in) :: candidate
    type(soil_water_physical_state_t),intent(out) :: state
    type(soil_water_parameter_set_t),intent(out) :: p
    class(transaction_state_t),allocatable :: snapshot
    logical :: available
    call candidate%snapshot(snapshot,available)
    call require(available .and. allocated(snapshot),'candidate snapshot')
    select type(typed=>snapshot)
    class is(fmr_b110_physical_state_t)
      state%active_nodes=typed%active_nodes
      allocate(state%pressure_head(typed%active_nodes),state%water_content(typed%active_nodes))
      state%pressure_head=typed%pressure_head; state%water_content=typed%water_content
      state%ponding_depth=typed%ponding_depth; state%groundwater_level=typed%groundwater_level
    class default
      call require(.false.,'candidate snapshot type')
    end select
    p%parameter_set_id=parameters%parameter_set_id; p%active_nodes=parameters%active_nodes
    allocate(p%z(parameters%active_nodes),p%dz(parameters%active_nodes),p%node_distance(parameters%active_nodes))
    p%z=parameters%z; p%dz=parameters%dz; p%node_distance=parameters%node_distance
  end subroutine materialize_solver_view

  pure logical function bits_equal_scalar(a,b) result(same)
    real(real64), intent(in) :: a,b
    same=transfer(a,0_int64)==transfer(b,0_int64)
  end function bits_equal_scalar

  logical function bits_equal_vector(a,b) result(same)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same=size(a)==size(b)
    if(.not.same)return
    do i=1,size(a)
      if(.not.bits_equal_scalar(a(i),b(i))) then
        same=.false.; return
      end if
    end do
  end function bits_equal_vector

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'FVQ105_FAIL',trim(label)
      error stop 105
    end if
  end subroutine require
end program test_fvq105_fgc31_active_drainage_independent
