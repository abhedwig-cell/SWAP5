program test_fgc31_qbot_drainage_projection_runtime
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
       fmr_serialized_physical_observation_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_TABULATED, FMR_DRAIN_BIND_OK
  use mod_b110_smooth_freatic_projection, only: b110_smooth_freatic_projection_diagnostics_t, &
       evaluate_b110_smooth_freatic_projection, B110_GWL_PROJECTION_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  implicit none

  real(real64), parameter :: duration=1.0e-4_real64
  real(real64), parameter :: mass_tolerance=1.0e-11_real64
  real(real64), parameter :: projected_gwl=-1.7_real64
  real(real64), parameter :: stale_gwl=-0.3_real64
  real(real64), parameter :: projected_drainage=1.8e-3_real64
  real(real64), parameter :: stale_drainage=3.0e-3_real64
  integer(int64), parameter :: column_id=531031_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top

  call initialize_parameters(parameters)
  call initialize_column_template(column,template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,duration)

  call verify_projection_enabled()
  call verify_default_off_uses_stored_gwl()
  call verify_projection_fail_closed_outside_smooth_envelope()
  call verify_projection_configuration_is_narrow()

  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_PROJECTED_GWL=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_PROJECTED_RESPONSE=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_DEFAULT_OFF_PRESERVED=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_PROJECTION_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FGC31_QBOT_DRAINAGE_CANDIDATE_GWL_REFRESH=PASS'

contains

  subroutine verify_projection_enabled()
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: obs
    type(fmr_b110_physical_state_t) :: state
    type(b110_smooth_freatic_projection_diagnostics_t) :: projection
    real(real64), allocatable :: zero_direction(:)
    real(real64) :: expected_candidate_gwl, ignored_direction

    parameters%drainage_qbot_smooth_freatic_projection=.true.
    call run_case(.true.,result,candidate,diagnostics,obs)
    call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'projection-enabled run completed')
    call require(candidate%ready(),'projection-enabled candidate ready')
    call require(obs%drainage_qbot_projection_active .and. obs%drainage_qbot_projection_available, &
         'projection observation available')
    call require(close(obs%drainage_projected_groundwater_level,projected_gwl,1.0e-13_real64), &
         'projected groundwater level')
    call require(obs%drainage_response%status==FMR_DRAIN_BIND_OK,'projected drainage response status')
    call require(size(obs%drainage_response%level)==1,'projected drainage diagnostic shape')
    call require(close(obs%drainage_response%level(1)%signed_soil_to_drain_rate,projected_drainage,1.0e-13_real64), &
         'drainage evaluated at projected GWL')
    call snapshot_candidate(candidate,state)
    allocate(zero_direction(state%active_nodes))
    zero_direction=0.0_real64
    call evaluate_b110_smooth_freatic_projection(SW_STEP_CONTROL_BOTTOM_FLUX,.false.,parameters%z, &
         parameters%node_distance,state%pressure_head,zero_direction,expected_candidate_gwl,ignored_direction,projection)
    call require(projection%status==B110_GWL_PROJECTION_OK .and. projection%value_defined, &
         'candidate pressure profile remains in smooth projection envelope')
    call require(close(state%groundwater_level,expected_candidate_gwl,1.0e-13_real64), &
         'candidate groundwater level refreshed from accepted pressure profile')
    call require(.not. close(state%groundwater_level,stale_gwl,1.0e-12_real64), &
         'candidate groundwater level must not remain stale')
  end subroutine verify_projection_enabled

  subroutine verify_default_off_uses_stored_gwl()
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: obs

    parameters%drainage_qbot_smooth_freatic_projection=.false.
    call run_case(.true.,result,candidate,diagnostics,obs)
    call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'default-off run completed')
    call require(candidate%ready(),'default-off candidate ready')
    call require(.not. obs%drainage_qbot_projection_active .and. .not. obs%drainage_qbot_projection_available, &
         'default-off projection remains inactive')
    call require(obs%drainage_response%status==FMR_DRAIN_BIND_OK,'default-off drainage response status')
    call require(close(obs%drainage_response%level(1)%signed_soil_to_drain_rate,stale_drainage,1.0e-13_real64), &
         'default-off response still consumes stored GWL')
  end subroutine verify_default_off_uses_stored_gwl

  subroutine verify_projection_fail_closed_outside_smooth_envelope()
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: obs

    parameters%drainage_qbot_smooth_freatic_projection=.true.
    call run_case(.false.,result,candidate,diagnostics,obs)
    call require(.not. candidate%ready(),'all-unsaturated projection case publishes no candidate')
    call require(.not. result%completed,'all-unsaturated projection case fails closed')
  end subroutine verify_projection_fail_closed_outside_smooth_envelope

  subroutine verify_projection_configuration_is_narrow()
    type(fmr_b110_physical_parameters_t) :: saved
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: obs

    saved=parameters
    parameters%drainage_qbot_smooth_freatic_projection=.true.
    parameters%bottom_mode=7
    call run_case(.true.,result,candidate,diagnostics,obs)
    call require(.not. candidate%ready() .and. .not. result%completed, &
         'projection flag is rejected outside prescribed-qbot mode')
    parameters=saved
  end subroutine verify_projection_configuration_is_narrow

  subroutine run_case(smooth_profile,result,candidate,diagnostics,obs)
    logical,intent(in) :: smooth_profile
    type(kernel_result_t),intent(out) :: result
    type(kernel_candidate_state_t),intent(out) :: candidate
    type(kernel_diagnostics_t),intent(out) :: diagnostics
    type(fmr_serialized_physical_observation_t),intent(out) :: obs
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    logical :: initialized

    call initialize_committed(committed,smooth_profile,initialized)
    call require(initialized,'committed initialized')
    call fmr_capture_checkpoint(committed,checkpoint,initialized)
    call require(initialized,'checkpoint captured')
    call initialize_forcing(forcing)
    call initialize_config(config)
    call backend%initialize(top)
    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,duration, &
         checkpoint,result,candidate,diagnostics)
    obs=backend%observation()
  end subroutine run_case

  subroutine initialize_parameters(value)
    type(fmr_b110_physical_parameters_t),intent(out) :: value
    integer :: k
    value%parameter_set_id=531031_int64
    value%active_nodes=numnod
    allocate(value%z(numnod),value%dz(numnod),value%node_distance(numnod),value%cofgen(24,numnod))
    value%z=z; value%dz=dz; value%node_distance=disnod(1:numnod)
    value%cofgen=0.0_real64
    do k=1,numnod
      value%cofgen(1,k)=0.032_real64; value%cofgen(2,k)=0.423_real64; value%cofgen(3,k)=4.75_real64
      value%cofgen(4,k)=0.0135_real64; value%cofgen(5,k)=0.365_real64; value%cofgen(6,k)=1.455_real64
      value%cofgen(7,k)=1.0_real64-1.0_real64/value%cofgen(6,k); value%cofgen(8,k)=value%cofgen(4,k)
      value%cofgen(9,k)=0.0_real64; value%cofgen(10,k)=value%cofgen(3,k); value%cofgen(11,k)=0.999_real64
      value%cofgen(12,k)=0.99_real64*value%cofgen(3,k); value%cofgen(22,k)=-1.0e6_real64
      value%cofgen(23,k)=1.0e-12_real64
    end do
    value%bottom_mode=SW_STEP_CONTROL_BOTTOM_FLUX
    value%swkimpl=0; value%swkmean=1; value%swsophy=0
    value%max_iterations=16; value%max_backtracking=8; value%min_step_duration=1.0e-8_real64
    value%compartment_balance_tolerance=mass_tolerance; value%total_balance_tolerance=mass_tolerance
    value%head_abs_tolerance=mass_tolerance; value%head_rel_tolerance=mass_tolerance
    value%ponding_tolerance=mass_tolerance
    value%root_extraction_active=.false.; value%macropore_active=.false.; value%snow_active=.false.
    value%hysteresis_active=.false.; value%tabulated_hydraulics_active=.false.
    value%elasticity_active=.false.; value%frost_active=.false.; value%soil_temperature_active=.false.
    value%drainage_response_active=.true.
    allocate(value%drainage_response_levels(1))
    value%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_TABULATED
    allocate(value%drainage_response_levels(1)%tabulated%groundwater_depth(2), &
         value%drainage_response_levels(1)%tabulated%signed_exchange_rate(2))
    value%drainage_response_levels(1)%tabulated%groundwater_depth=[0.5_real64,2.5_real64]
    value%drainage_response_levels(1)%tabulated%signed_exchange_rate=[3.0e-3_real64,1.0e-3_real64]
  end subroutine initialize_parameters

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out) :: c
    type(fmr_template_t),intent(out) :: t
    t%template_id=531001_int64; t%physics_topology_id=531002_int64; t%vertical_layout_id=531003_int64
    t%state_layout_id=531004_int64; t%solver_interface_id=531005_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_forcing(value)
    type(fmr_b110_physical_forcing_t),intent(out) :: value
    value%top_flux=0.0_real64; value%top_head=-999.0_real64
    value%bottom_flux=0.0_real64; value%bottom_head=-999.0_real64
    allocate(value%drainage_response_controls(1),value%subsurface_irrigation_source(numnod), &
         value%root_extraction_sink(numnod))
    value%subsurface_irrigation_source=0.0_real64
    if (parameters%drainage_qbot_smooth_freatic_projection) then
      value%subsurface_irrigation_source(numnod)=projected_drainage
    else
      value%subsurface_irrigation_source(numnod)=stale_drainage
    end if
    value%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_config(config)
    type(canonical_numerical_config_t),intent(out) :: config
    config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=mass_tolerance
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=4
    config%max_committed_substeps=16; config%progress_tolerance=0.0_real64
    config%model_temporal_indicator_budget_available=.true.
    config%model_temporal_indicator_budget=1.0e-3_real64
    config%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initialize_committed(committed,smooth_profile,ok)
    type(kernel_committed_state_t),intent(out) :: committed
    logical,intent(in) :: smooth_profile
    logical,intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64) :: previous_right(numnod)

    if (smooth_profile) then
      heads=[-2.2_real64,-1.2_real64,-0.2_real64,0.8_real64]
    else
      heads=[-2.2_real64,-1.8_real64,-1.4_real64,-1.0_real64]
    end if
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=stale_gwl
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

  pure logical function close(a,b,tol) result(ok)
    real(real64),intent(in) :: a,b,tol
    ok=abs(a-b)<=tol
  end function close

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'FGC31_QBOT_PROJECTION_FAIL',trim(label)
      error stop 31
    end if
  end subroutine require
end program test_fgc31_qbot_drainage_projection_runtime
