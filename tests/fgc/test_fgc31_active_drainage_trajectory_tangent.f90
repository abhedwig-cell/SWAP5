program test_fgc31_active_drainage_trajectory_tangent
  use, intrinsic :: iso_fortran_env, only: int64, real64
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
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: duration = 4.0e-4_real64
  real(real64), parameter :: mass_tolerance = 1.0e-10_real64
  real(real64), parameter :: qbot0 = 0.0_real64
  real(real64), parameter :: fd_eps = 2.0e-4_real64
  integer(int64), parameter :: column_id = 531032_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(kernel_result_t) :: nominal, plus, minus
  type(kernel_candidate_state_t) :: nominal_candidate, plus_candidate, minus_candidate
  type(kernel_diagnostics_t) :: nominal_diag, plus_diag, minus_diag
  type(fmr_b110_physical_state_t) :: nominal_state, plus_state, minus_state
  real(real64) :: fd_head(n), err_head, tol_head
  real(real64) :: analytic_gwl_direction, fd_gwl_direction, ignored_gwl
  logical :: projection_ok

  call initialize_parameters(parameters)
  call initialize_column_template(column,template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,duration)

  call run_backend(qbot0,.true.,nominal,nominal_candidate,nominal_diag)
  if (.not. nominal%completed) then
    write(*,'(A,I0,A,ES14.6,A,I0,A,I0,A,I0)') 'FGC31_DEBUG_STATUS=',nominal%status, &
         ' completed_t=',nominal%completed_t,' accepted=',nominal_diag%accepted_substeps, &
         ' retries=',nominal_diag%retries,' temporal_rejections=',nominal_diag%temporal_rejections
  end if
  call require(nominal%status == CANONICAL_STATUS_COMPLETED .and. nominal%completed, 'nominal completed')
  call require(nominal_candidate%ready(), 'nominal candidate ready')
  write(*,'(A,I0)') 'FGC31_DEBUG_ACCEPTED_SUBSTEPS=',nominal_diag%accepted_substeps
  write(*,'(A,I0)') 'FGC31_DEBUG_RETRIES=',nominal_diag%retries
  write(*,'(A,1X,ES14.6)') 'FGC31_DEBUG_MAX_TEMPORAL_INDICATOR',nominal_diag%max_temporal_indicator
  call require(nominal_diag%accepted_substeps >= 2, 'oracle requires at least two accepted substeps')
  call require(nominal%accepted_trajectory_direction%requested .and. nominal%accepted_trajectory_direction%available, &
       'accepted trajectory tangent unavailable')
  call require(nominal%accepted_trajectory_direction%control_coordinate == SW_STEP_CONTROL_BOTTOM_FLUX, &
       'wrong trajectory control')
  call require(nominal%accepted_trajectory_direction%accepted_steps == nominal_diag%accepted_substeps, &
       'trajectory accepted-step count mismatch')
  call require(nominal%accepted_trajectory_direction%source_sink_direction_coverage_complete, &
       'drainage source/sink coverage not complete')
  call require(nominal%accepted_trajectory_direction%additional_full_nonlinear_solves == 0, &
       'tangent introduced extra nonlinear solve')
  call require(nominal%accepted_trajectory_direction%additional_jacobian_builds == 0, &
       'tangent introduced extra Jacobian build')

  call run_backend(qbot0+fd_eps,.false.,plus,plus_candidate,plus_diag)
  call run_backend(qbot0-fd_eps,.false.,minus,minus_candidate,minus_diag)
  call require(plus%status == CANONICAL_STATUS_COMPLETED .and. minus%status == CANONICAL_STATUS_COMPLETED, &
       'FD production paths completed')
  call require(plus_candidate%ready() .and. minus_candidate%ready(), 'FD candidates ready')
  call require(plus_diag%accepted_substeps == nominal_diag%accepted_substeps .and. &
       minus_diag%accepted_substeps == nominal_diag%accepted_substeps, 'FD accepted-substep topology changed')
  call require(plus_diag%retries == nominal_diag%retries .and. minus_diag%retries == nominal_diag%retries, &
       'FD retry topology changed')

  call snapshot_candidate(nominal_candidate,nominal_state)
  call snapshot_candidate(plus_candidate,plus_state)
  call snapshot_candidate(minus_candidate,minus_state)
  fd_head = (plus_state%pressure_head-minus_state%pressure_head)/(2.0_real64*fd_eps)
  err_head = maxval(abs(fd_head-nominal%accepted_trajectory_direction%final_pressure_head_direction))
  tol_head = 2.0e-6_real64 + 2.0e-4_real64*max(1.0_real64, &
       maxval(abs(nominal%accepted_trajectory_direction%final_pressure_head_direction)))
  call require(err_head <= tol_head, 'whole-window accepted trajectory head tangent vs same-backend FD')

  call project_direction(nominal_state,nominal%accepted_trajectory_direction%final_pressure_head_direction, &
       ignored_gwl,analytic_gwl_direction,projection_ok)
  call require(projection_ok, 'analytic terminal GWL projection available')
  fd_gwl_direction = (plus_state%groundwater_level-minus_state%groundwater_level)/(2.0_real64*fd_eps)
  call require(abs(fd_gwl_direction-analytic_gwl_direction) <= 3.0e-6_real64 + &
       2.0e-4_real64*max(1.0_real64,abs(analytic_gwl_direction)), 'terminal GWL tangent vs same-backend FD')

  call require(abs(nominal_state%groundwater_level - stale_gwl()) > 1.0e-8_real64, &
       'nominal candidate GWL was not refreshed')

  write(*,'(A,I0)') 'FGC31_ACTIVE_DRAINAGE_ACCEPTED_SUBSTEPS=',nominal_diag%accepted_substeps
  write(*,'(A,I0)') 'FGC31_ACTIVE_DRAINAGE_RETRIES=',nominal_diag%retries
  write(*,'(A,1X,ES14.6)') 'FGC31_ACTIVE_DRAINAGE_HEAD_FD_MAX_ERROR',err_head
  write(*,'(A,1X,ES14.6)') 'FGC31_ACTIVE_DRAINAGE_GWL_FD_ERROR',abs(fd_gwl_direction-analytic_gwl_direction)
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_MULTI_SUBSTEP=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_TRAJECTORY_COVERAGE=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_SAME_BACKEND_CENTERED_FD=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_TERMINAL_GWL_FD=PASS'
  write(*,'(A)') 'FGC31_ACTIVE_DRAINAGE_NO_EXTRA_NONLINEAR_SOLVE=PASS'

contains

  subroutine run_backend(qbot,request_direction,result,candidate,diagnostics)
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
    logical :: ok

    call initialize_committed(committed,ok)
    call require(ok,'committed initialized')
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call require(ok,'checkpoint captured')
    call initialize_forcing(qbot,forcing)
    call initialize_config(request_direction,config)
    call backend%initialize(top)
    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,duration, &
         checkpoint,result,candidate,diagnostics)
  end subroutine run_backend

  subroutine initialize_parameters(value)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    integer :: k
    value%parameter_set_id=531032_int64
    value%active_nodes=n
    allocate(value%z(n),value%dz(n),value%node_distance(n),value%cofgen(24,n))
    value%z=[-0.25_real64,-0.75_real64,-1.50_real64,-2.50_real64]
    value%dz=[0.50_real64,0.50_real64,1.00_real64,1.00_real64]
    value%node_distance=1.0_real64
    value%cofgen=0.0_real64
    do k=1,n
      value%cofgen(1,k)=0.032_real64; value%cofgen(2,k)=0.423_real64; value%cofgen(3,k)=4.75_real64
      value%cofgen(4,k)=0.0135_real64; value%cofgen(5,k)=0.365_real64; value%cofgen(6,k)=1.455_real64
      value%cofgen(7,k)=1.0_real64-1.0_real64/value%cofgen(6,k); value%cofgen(8,k)=value%cofgen(4,k)
      value%cofgen(9,k)=0.0_real64; value%cofgen(10,k)=value%cofgen(3,k); value%cofgen(11,k)=0.999_real64
      value%cofgen(12,k)=0.99_real64*value%cofgen(3,k); value%cofgen(22,k)=-1.0e6_real64
      value%cofgen(23,k)=1.0e-12_real64
    end do
    value%bottom_mode=SW_STEP_CONTROL_BOTTOM_FLUX
    value%swkimpl=0; value%swkmean=1; value%swsophy=0
    value%max_iterations=20; value%max_backtracking=10; value%min_step_duration=1.0e-9_real64
    value%compartment_balance_tolerance=mass_tolerance; value%total_balance_tolerance=mass_tolerance
    value%head_abs_tolerance=1.0e-11_real64; value%head_rel_tolerance=1.0e-11_real64
    value%ponding_tolerance=1.0e-11_real64
    value%root_extraction_active=.false.; value%macropore_active=.false.; value%snow_active=.false.
    value%hysteresis_active=.false.; value%tabulated_hydraulics_active=.false.
    value%elasticity_active=.false.; value%frost_active=.false.; value%soil_temperature_active=.false.
    value%drainage_response_active=.true.
    value%drainage_qbot_smooth_freatic_projection=.true.
    allocate(value%drainage_response_levels(2))
    value%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_TABULATED
    value%drainage_response_levels(2)%variant=FMR_DRAIN_VARIANT_TABULATED
    allocate(value%drainage_response_levels(1)%tabulated%groundwater_depth(2), &
         value%drainage_response_levels(1)%tabulated%signed_exchange_rate(2), &
         value%drainage_response_levels(2)%tabulated%groundwater_depth(2), &
         value%drainage_response_levels(2)%tabulated%signed_exchange_rate(2))
    value%drainage_response_levels(1)%tabulated%groundwater_depth=[0.5_real64,2.5_real64]
    value%drainage_response_levels(1)%tabulated%signed_exchange_rate=[1.0e-3_real64,1.001_real64]
    value%drainage_response_levels(2)%tabulated%groundwater_depth=[0.5_real64,2.5_real64]
    value%drainage_response_levels(2)%tabulated%signed_exchange_rate=[5.0e-4_real64,5.005e-1_real64]
  end subroutine initialize_parameters

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out) :: c
    type(fmr_template_t),intent(out) :: t
    t%template_id=5310321_int64; t%physics_topology_id=5310322_int64; t%vertical_layout_id=5310323_int64
    t%state_layout_id=5310324_int64; t%solver_interface_id=5310325_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_forcing(qbot,value)
    real(real64), intent(in) :: qbot
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    real(real64), parameter :: initial_drainage = 9.015e-1_real64
    value%top_flux=0.0_real64; value%top_head=-999.0_real64
    value%bottom_flux=qbot; value%bottom_head=-999.0_real64
    allocate(value%drainage_response_controls(2),value%subsurface_irrigation_source(n),value%root_extraction_sink(n))
    value%subsurface_irrigation_source=0.0_real64
    value%subsurface_irrigation_source(n)=initial_drainage
    value%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_config(request_direction,config)
    logical, intent(in) :: request_direction
    type(canonical_numerical_config_t),intent(out) :: config
    config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=mass_tolerance
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=10
    config%max_committed_substeps=64; config%progress_tolerance=0.0_real64
    config%model_temporal_indicator_budget_available=.true.
    config%model_temporal_indicator_budget=1.5e-14_real64
    config%accepted_trajectory_direction%requested=request_direction
    config%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
  end subroutine initialize_config

  subroutine initialize_committed(committed,ok)
    type(kernel_committed_state_t),intent(out) :: committed
    logical,intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(n),water(n),conductivity(n),capacity(n),dkdh(n),previous_right(n)
    heads=[-2.2_real64,-1.2_real64,-0.2_real64,0.8_real64]
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=n
    allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=stale_gwl()
    previous_right=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed,column_id,state,0.0_real64,ok,previous_right)
  end subroutine initialize_committed

  subroutine snapshot_candidate(candidate,state)
    type(kernel_candidate_state_t),intent(in) :: candidate
    type(fmr_b110_physical_state_t),intent(out) :: state
    class(transaction_state_t),allocatable :: snapshot
    logical :: available
    call candidate%snapshot(snapshot,available)
    call require(available,'candidate snapshot')
    select type(physical=>snapshot)
    class is(fmr_b110_physical_state_t)
      state=physical
    class default
      call require(.false.,'candidate state type')
    end select
  end subroutine snapshot_candidate

  subroutine project_direction(state,direction,gwl,dgwl,ok)
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: direction(:)
    real(real64), intent(out) :: gwl,dgwl
    logical, intent(out) :: ok
    type(b110_smooth_freatic_projection_diagnostics_t) :: d
    call evaluate_b110_smooth_freatic_projection(SW_STEP_CONTROL_BOTTOM_FLUX,.false.,parameters%z, &
         parameters%node_distance,state%pressure_head,direction,gwl,dgwl,d)
    ok=d%status==B110_GWL_PROJECTION_OK .and. d%value_defined .and. d%direction_defined
  end subroutine project_direction

  pure real(real64) function stale_gwl() result(value)
    value=-0.3_real64
  end function stale_gwl

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'FGC31_ACTIVE_DRAINAGE_TANGENT_FAIL',trim(label)
      error stop 31
    end if
  end subroutine require
end program test_fgc31_active_drainage_trajectory_tangent
