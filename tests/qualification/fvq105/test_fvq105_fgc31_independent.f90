program test_fvq105_fgc31_independent
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
  use mod_b110_smooth_freatic_projection, only: b110_smooth_freatic_projection_diagnostics_t, &
       evaluate_b110_smooth_freatic_projection, B110_GWL_PROJECTION_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK, &
       MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE
  implicit none

  real(real64), parameter :: duration = 1.0e-2_real64
  real(real64), parameter :: certificate_budget = 1.0_real64
  real(real64), parameter :: mass_tolerance = 1.0e-10_real64
  real(real64), parameter :: qbot0 = 1.5e-3_real64
  real(real64), parameter :: fd_eps = 7.5e-6_real64
  real(real64), parameter :: rel_gate = 1.5e-3_real64
  integer(int64), parameter :: column_id = 510531_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(groundwater_head_datum_t) :: datum
  type(kernel_result_t) :: directional, plain, plus, minus, legacy_directional
  type(kernel_candidate_state_t) :: directional_candidate, plain_candidate, plus_candidate, minus_candidate
  type(kernel_candidate_state_t) :: legacy_candidate
  type(kernel_diagnostics_t) :: directional_diag, plain_diag, plus_diag, minus_diag, legacy_diag
  type(fmr_b110_physical_state_t) :: directional_state, plain_state, plus_state, minus_state, legacy_state
  type(soil_water_physical_state_t) :: solver_state
  type(soil_water_parameter_set_t) :: solver_parameters
  type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint, blocked_endpoint
  type(modflow6_prescribed_qbot_bottom_face_t) :: plus_face, minus_face
  real(real64), allocatable :: fd_head(:), fd_water(:)
  real(real64) :: head_error, water_error, face_fd, face_error, projected_gwl, analytic_dgwl, fd_dgwl
  real(real64) :: ignored_direction, scale
  logical :: projection_ok
  integer :: status

  call configure_parameters(parameters)
  call configure_column_template(column, template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, duration)
  datum%available = .true.
  datum%datum_id = 510531_int64
  datum%bottom_boundary_elevation_m = 0.0_real64

  ! Independent production route: active drainage, projected lagged GWL and
  ! accepted-trajectory tangent all run through the serialized backend.
  call execute_case(qbot0, .true., .true., directional, directional_candidate, directional_diag)
  call require(directional%status == CANONICAL_STATUS_COMPLETED .and. directional%completed, &
       'directional production interval completed')
  call require(directional_candidate%ready(), 'directional candidate ready')
  call require(directional_diag%accepted_substeps >= 2, 'independent route needs multiple accepted substeps')
  call require(directional%accepted_trajectory_direction%available .and. &
       directional%accepted_trajectory_direction%requested, 'accepted trajectory available')
  call require(directional%accepted_trajectory_direction%accepted_steps == directional_diag%accepted_substeps, &
       'accepted trajectory step count')
  call require(directional%accepted_trajectory_direction%source_sink_direction_coverage_complete, &
       'source/sink coverage provenance complete')
  call require(directional%accepted_trajectory_direction%additional_full_nonlinear_solves == 0, &
       'no extra nonlinear tangent solves')

  call snapshot_state(directional_candidate, directional_state)
  call materialize_solver_view(directional_state, solver_state, solver_parameters)
  call build_modflow6_swap_predictor_tangent_endpoint(solver_state, solver_parameters, constitutive, &
       directional%accepted_trajectory_direction, qbot0, datum, .false., .false., .true., .false., endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_OK .and. endpoint%authoritative .and. endpoint%available, &
       'active-drainage endpoint authoritative')
  call require(endpoint%coverage%drainage_active .and. endpoint%coverage%drainage_covered .and. &
       endpoint%coverage%tangent_complete(), 'active-drainage endpoint coverage complete')

  ! Direction publication must be observational: the same physical run without
  ! tangent publication has exactly the same accepted topology and state bits.
  call execute_case(qbot0, .false., .true., plain, plain_candidate, plain_diag)
  call require(plain%status == CANONICAL_STATUS_COMPLETED .and. plain%completed .and. plain_candidate%ready(), &
       'plain production interval completed')
  call require(plain_diag%accepted_substeps == directional_diag%accepted_substeps .and. &
       plain_diag%retries == directional_diag%retries, 'direction request changed accepted topology')
  call snapshot_state(plain_candidate, plain_state)
  call require(same_bits_vector(plain_state%pressure_head, directional_state%pressure_head), &
       'direction request changed pressure state')
  call require(same_bits_vector(plain_state%water_content, directional_state%water_content), &
       'direction request changed water state')
  call require(same_bits_scalar(plain_state%groundwater_level, directional_state%groundwater_level), &
       'direction request changed refreshed GWL')

  ! Same-backend centered FD. Both perturbations must preserve the exact accepted
  ! substep/retry topology before they are allowed to act as an oracle.
  call execute_case(qbot0+fd_eps, .false., .true., plus, plus_candidate, plus_diag)
  call execute_case(qbot0-fd_eps, .false., .true., minus, minus_candidate, minus_diag)
  call require(plus%status == CANONICAL_STATUS_COMPLETED .and. minus%status == CANONICAL_STATUS_COMPLETED .and. &
       plus_candidate%ready() .and. minus_candidate%ready(), 'FD production paths completed')
  call require(plus_diag%accepted_substeps == directional_diag%accepted_substeps .and. &
       minus_diag%accepted_substeps == directional_diag%accepted_substeps .and. &
       plus_diag%retries == directional_diag%retries .and. minus_diag%retries == directional_diag%retries, &
       'FD topology mismatch')
  call snapshot_state(plus_candidate, plus_state)
  call snapshot_state(minus_candidate, minus_state)

  allocate(fd_head(numnod), fd_water(numnod))
  fd_head = (plus_state%pressure_head-minus_state%pressure_head)/(2.0_real64*fd_eps)
  fd_water = (plus_state%water_content-minus_state%water_content)/(2.0_real64*fd_eps)
  head_error = maxval(abs(fd_head-directional%accepted_trajectory_direction%final_pressure_head_direction))
  water_error = maxval(abs(fd_water-directional%accepted_trajectory_direction%final_water_content_direction))
  scale = max(1.0_real64, maxval(abs(fd_head)), &
       maxval(abs(directional%accepted_trajectory_direction%final_pressure_head_direction)))
  call require(head_error <= rel_gate*scale, 'pressure-head tangent vs independent FD')
  scale = max(1.0e-6_real64, maxval(abs(fd_water)), &
       maxval(abs(directional%accepted_trajectory_direction%final_water_content_direction)))
  call require(water_error <= rel_gate*scale + 2.0e-9_real64, 'water-content tangent vs independent FD')

  call project_terminal_direction(directional_state, directional%accepted_trajectory_direction%final_pressure_head_direction, &
       projected_gwl, analytic_dgwl, projection_ok)
  call require(projection_ok, 'terminal GWL projection direction available')
  fd_dgwl = (plus_state%groundwater_level-minus_state%groundwater_level)/(2.0_real64*fd_eps)
  call require(abs(fd_dgwl-analytic_dgwl) <= 3.0e-6_real64 + rel_gate*max(1.0_real64,abs(analytic_dgwl)), &
       'terminal GWL direction vs independent FD')

  call materialize_face(plus_state, qbot0+fd_eps, plus_face)
  call materialize_face(minus_state, qbot0-fd_eps, minus_face)
  face_fd = (plus_face%pressure_head_cm-minus_face%pressure_head_cm)/(2.0_real64*fd_eps)
  face_error = abs(face_fd-endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day)
  scale = max(1.0_real64, abs(face_fd), abs(endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day))
  call require(face_error <= rel_gate*scale, 'bottom-face tangent vs independent FD')

  ! Default-off preservation/fail-closed check: active drainage without the
  ! F-GC31 projection remains a valid physical PM14-style route, but its
  ! trajectory does not own state-dependent drainage direction coverage and
  ! therefore cannot become an authoritative MODFLOW tangent endpoint.
  call execute_case(qbot0, .true., .false., legacy_directional, legacy_candidate, legacy_diag)
  call require(legacy_directional%status == CANONICAL_STATUS_COMPLETED .and. legacy_directional%completed .and. &
       legacy_candidate%ready(), 'default-off active drainage remains physically admitted')
  call require(legacy_directional%accepted_trajectory_direction%available, &
       'default-off directional primitive remains available')
  call require(.not. legacy_directional%accepted_trajectory_direction%source_sink_direction_coverage_complete, &
       'default-off route incorrectly claims drainage direction coverage')
  call snapshot_state(legacy_candidate, legacy_state)
  call materialize_solver_view(legacy_state, solver_state, solver_parameters)
  call build_modflow6_swap_predictor_tangent_endpoint(solver_state, solver_parameters, constitutive, &
       legacy_directional%accepted_trajectory_direction, qbot0, datum, .false., .false., .true., .false., &
       blocked_endpoint, status)
  call require(status == MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE .and. blocked_endpoint%available .and. &
       .not. blocked_endpoint%authoritative, 'default-off drainage tangent did not fail closed')

  write(*,'(A,I0)') 'FVQ105_ACCEPTED_SUBSTEPS=', directional_diag%accepted_substeps
  write(*,'(A,I0)') 'FVQ105_RETRIES=', directional_diag%retries
  write(*,'(A,1X,ES14.6)') 'FVQ105_HEAD_FD_MAX_ERROR=', head_error
  write(*,'(A,1X,ES14.6)') 'FVQ105_WATER_FD_MAX_ERROR=', water_error
  write(*,'(A,1X,ES14.6)') 'FVQ105_GWL_FD_ERROR=', abs(fd_dgwl-analytic_dgwl)
  write(*,'(A,1X,ES14.6)') 'FVQ105_FACE_FD_ERROR=', face_error
  write(*,'(A)') 'FVQ105_MULTI_SUBSTEP_ACTIVE_DRAINAGE=PASS'
  write(*,'(A)') 'FVQ105_SAME_BACKEND_FD=PASS'
  write(*,'(A)') 'FVQ105_PHYSICAL_IDENTITY=PASS'
  write(*,'(A)') 'FVQ105_GWL_DIRECTION_CHAIN=PASS'
  write(*,'(A)') 'FVQ105_DRAINAGE_COVERAGE_PROVENANCE=PASS'
  write(*,'(A)') 'FVQ105_DEFAULT_OFF_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ105_FGC31_INDEPENDENT PASS'

contains

  subroutine configure_parameters(value)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    integer :: k
    value%parameter_set_id = 510531_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z
    value%dz = dz
    value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do k=1,numnod
      value%cofgen(1,k)=0.032_real64
      value%cofgen(2,k)=0.423_real64
      value%cofgen(3,k)=4.75_real64
      value%cofgen(4,k)=0.0135_real64
      value%cofgen(5,k)=0.365_real64
      value%cofgen(6,k)=1.455_real64
      value%cofgen(7,k)=1.0_real64-1.0_real64/value%cofgen(6,k)
      value%cofgen(8,k)=value%cofgen(4,k)
      value%cofgen(9,k)=0.0_real64
      value%cofgen(10,k)=value%cofgen(3,k)
      value%cofgen(11,k)=0.999_real64
      value%cofgen(12,k)=0.99_real64*value%cofgen(3,k)
      value%cofgen(22,k)=-1.0e6_real64
      value%cofgen(23,k)=1.0e-12_real64
    end do
    value%bottom_mode = SW_STEP_CONTROL_BOTTOM_FLUX
    value%swkimpl = 0
    value%swkmean = 1
    value%swsophy = 0
    value%max_iterations = 18
    value%max_backtracking = 9
    value%min_step_duration = 1.0e-10_real64
    value%compartment_balance_tolerance = mass_tolerance
    value%total_balance_tolerance = mass_tolerance
    value%head_abs_tolerance = 1.0e-12_real64
    value%head_rel_tolerance = 1.0e-12_real64
    value%ponding_tolerance = 1.0e-12_real64
    value%root_extraction_active = .false.
    value%macropore_active = .false.
    value%snow_active = .false.
    value%hysteresis_active = .false.
    value%tabulated_hydraulics_active = .false.
    value%elasticity_active = .false.
    value%frost_active = .false.
    value%soil_temperature_active = .false.
    value%drainage_response_active = .true.
    value%drainage_qbot_smooth_freatic_projection = .true.
    allocate(value%drainage_response_levels(2))
    value%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_TABULATED
    value%drainage_response_levels(2)%variant = FMR_DRAIN_VARIANT_TABULATED
    allocate(value%drainage_response_levels(1)%tabulated%groundwater_depth(2), &
         value%drainage_response_levels(1)%tabulated%signed_exchange_rate(2), &
         value%drainage_response_levels(2)%tabulated%groundwater_depth(2), &
         value%drainage_response_levels(2)%tabulated%signed_exchange_rate(2))
    value%drainage_response_levels(1)%tabulated%groundwater_depth = [0.4_real64,2.4_real64]
    value%drainage_response_levels(1)%tabulated%signed_exchange_rate = [3.8e-3_real64,8.0e-4_real64]
    value%drainage_response_levels(2)%tabulated%groundwater_depth = [0.6_real64,2.6_real64]
    value%drainage_response_levels(2)%tabulated%signed_exchange_rate = [1.8e-3_real64,-8.0e-4_real64]
  end subroutine configure_parameters

  subroutine configure_column_template(c,t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=5105311_int64
    t%physics_topology_id=5105312_int64
    t%vertical_layout_id=5105313_int64
    t%state_layout_id=5105314_int64
    t%solver_interface_id=5105315_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id
    c%template_id=t%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column_template

  subroutine configure_forcing(qbot,value)
    real(real64), intent(in) :: qbot
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    value%top_flux = 2.5e-4_real64
    value%top_head = -999.0_real64
    value%bottom_flux = qbot
    value%bottom_head = -999.0_real64
    allocate(value%drainage_response_controls(2), value%subsurface_irrigation_source(numnod), &
         value%root_extraction_sink(numnod))
    value%subsurface_irrigation_source = 0.0_real64
    value%root_extraction_sink = 0.0_real64
  end subroutine configure_forcing

  subroutine configure_numerics(request_direction,config)
    logical, intent(in) :: request_direction
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = mass_tolerance
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 12
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = certificate_budget
    config%accepted_trajectory_direction%requested = request_direction
    config%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  end subroutine configure_numerics

  subroutine initialize_committed(committed,ok)
    type(kernel_committed_state_t), intent(out) :: committed
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),reserved(numnod)
    real(real64) :: previous_right(numnod)
    heads = [-2.15_real64,-1.15_real64,-0.15_real64,0.85_real64]
    call constitutive%evaluate(heads,water,conductivity,capacity,reserved)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-0.4_real64
    previous_right=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed,column_id,state,0.0_real64,ok,previous_right)
  end subroutine initialize_committed

  subroutine execute_case(qbot,request_direction,projection_active,result,candidate,diagnostics)
    real(real64), intent(in) :: qbot
    logical, intent(in) :: request_direction, projection_active
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    logical :: ok

    parameters%drainage_qbot_smooth_freatic_projection = projection_active
    call initialize_committed(committed,ok)
    call require(ok,'committed initialization')
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call require(ok,'checkpoint capture')
    call configure_forcing(qbot,forcing)
    call configure_numerics(request_direction,config)
    call backend%initialize(top)
    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,duration, &
         checkpoint,result,candidate,diagnostics)
    if (.not. result%completed) then
      write(*,'(A,L1,A,I0,A,I0,A,I0)') 'FVQ105_DIAG projection=',projection_active, &
           ' retries=',diagnostics%retries,' temporal=',diagnostics%temporal_rejections, &
           ' accepted=',diagnostics%accepted_substeps
    end if
  end subroutine execute_case

  subroutine snapshot_state(candidate,state)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(fmr_b110_physical_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call candidate%snapshot(snapshot,available)
    call require(available .and. allocated(snapshot),'candidate snapshot')
    select type(typed=>snapshot)
    class is(fmr_b110_physical_state_t)
      state=typed
    class default
      call require(.false.,'candidate state type')
    end select
  end subroutine snapshot_state

  subroutine materialize_solver_view(source,state,parameter_set)
    type(fmr_b110_physical_state_t), intent(in) :: source
    type(soil_water_physical_state_t), intent(out) :: state
    type(soil_water_parameter_set_t), intent(out) :: parameter_set
    state%active_nodes=source%active_nodes
    allocate(state%pressure_head(source%active_nodes),state%water_content(source%active_nodes))
    state%pressure_head=source%pressure_head
    state%water_content=source%water_content
    state%ponding_depth=source%ponding_depth
    state%groundwater_level=source%groundwater_level
    parameter_set%parameter_set_id=parameters%parameter_set_id
    parameter_set%active_nodes=parameters%active_nodes
    allocate(parameter_set%z(parameters%active_nodes),parameter_set%dz(parameters%active_nodes), &
         parameter_set%node_distance(parameters%active_nodes))
    parameter_set%z=parameters%z
    parameter_set%dz=parameters%dz
    parameter_set%node_distance=parameters%node_distance
  end subroutine materialize_solver_view

  subroutine project_terminal_direction(state,direction,gwl,dgwl,ok)
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: direction(:)
    real(real64), intent(out) :: gwl,dgwl
    logical, intent(out) :: ok
    type(b110_smooth_freatic_projection_diagnostics_t) :: diagnostics
    call evaluate_b110_smooth_freatic_projection(SW_STEP_CONTROL_BOTTOM_FLUX,.false.,parameters%z, &
         parameters%node_distance,state%pressure_head,direction,gwl,dgwl,diagnostics)
    ok=diagnostics%status==B110_GWL_PROJECTION_OK .and. diagnostics%value_defined .and. diagnostics%direction_defined
  end subroutine project_terminal_direction

  subroutine materialize_face(state,qbot,face)
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: qbot
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: face
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), reserved(numnod)
    integer :: face_status
    call constitutive%evaluate(state%pressure_head,water,conductivity,capacity,reserved)
    call materialize_modflow6_prescribed_qbot_bottom_face(state%pressure_head(numnod),conductivity(numnod),qbot, &
         0.5_real64*parameters%dz(numnod),datum,face,face_status)
    call require(face_status==MODFLOW6_BOTTOM_FACE_OK .and. face%valid,'bottom face materialization')
  end subroutine materialize_face

  logical function same_bits_scalar(a,b)
    real(real64), intent(in) :: a,b
    same_bits_scalar=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits_scalar

  logical function same_bits_vector(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same_bits_vector=size(a)==size(b)
    if(.not.same_bits_vector)return
    do i=1,size(a)
      if(.not.same_bits_scalar(a(i),b(i)))then
        same_bits_vector=.false.
        return
      end if
    end do
  end function same_bits_vector

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'FVQ105_FAIL',trim(label)
      error stop 105
    end if
  end subroutine require

end program test_fvq105_fgc31_independent
