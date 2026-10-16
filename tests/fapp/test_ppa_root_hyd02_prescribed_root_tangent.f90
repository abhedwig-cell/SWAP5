program test_ppa_root_hyd02_prescribed_root_tangent
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK
  implicit none

  real(real64), parameter :: H0_CM=-75.0_real64
  real(real64), parameter :: ROOT_TOTAL=2.0e-2_real64
  real(real64), parameter :: DURATION=1.0e-1_real64
  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  real(real64), parameter :: TEMPORAL_BUDGET=1.0e-1_real64
  integer(int64), parameter :: COLUMN_ID=593001_int64

  type(fmr_b110_physical_parameters_t) :: base_parameters
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(groundwater_head_datum_t) :: datum
  type(kernel_result_t) :: root_result, generic_result
  type(kernel_candidate_state_t) :: root_candidate, generic_candidate
  type(kernel_diagnostics_t) :: root_diag, generic_diag
  type(soil_water_physical_state_t) :: root_state, generic_state
  type(soil_water_parameter_set_t) :: root_solver_parameters, generic_solver_parameters
  type(modflow6_swap_predictor_tangent_endpoint_t) :: root_endpoint, generic_endpoint
  real(real64) :: qref, head_diff, theta_diff, direction_head_diff, direction_theta_diff
  real(real64) :: exchange_direction_diff, endpoint_direction_diff
  integer :: root_endpoint_status, generic_endpoint_status

  call initialize_parameters(base_parameters)
  call initialize_column_template(column,template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,base_parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,DURATION)
  call derive_equilibrium_flux(constitutive,qref)
  datum%available=.true.
  datum%datum_id=593001_int64
  datum%bottom_boundary_elevation_m=0.0_real64

  call run_route(.true.,root_result,root_candidate,root_diag)
  call run_route(.false.,generic_result,generic_candidate,generic_diag)

  call require(root_result%status==CANONICAL_STATUS_COMPLETED .and. root_result%completed, &
       'ROOT tangent interval did not complete')
  call require(generic_result%status==CANONICAL_STATUS_COMPLETED .and. generic_result%completed, &
       'GENERIC tangent interval did not complete')
  call require(root_candidate%ready() .and. generic_candidate%ready(),'candidate not ready')
  call require(root_result%mass%complete .and. generic_result%mass%complete,'mass ledger incomplete')
  call require(abs(root_result%mass%residual)<=MASS_TOL .and. abs(generic_result%mass%residual)<=MASS_TOL, &
       'hard mass gate')
  call require(root_diag%accepted_substeps>=1 .and. generic_diag%accepted_substeps>=1,'no accepted substeps')
  call require(root_diag%accepted_substeps==generic_diag%accepted_substeps,'accepted topology divergence')
  call require(root_diag%retries==generic_diag%retries,'retry topology divergence')
  call require(root_diag%solver_rejections==generic_diag%solver_rejections,'solver rejection divergence')
  call require(root_diag%temporal_rejections==generic_diag%temporal_rejections,'temporal rejection divergence')

  call require(root_result%accepted_trajectory_direction%requested .and. &
       root_result%accepted_trajectory_direction%available,'ROOT trajectory direction unavailable')
  call require(generic_result%accepted_trajectory_direction%requested .and. &
       generic_result%accepted_trajectory_direction%available,'GENERIC trajectory direction unavailable')
  call require(root_result%accepted_trajectory_direction%root_sink_direction_coverage_complete, &
       'ROOT prescribed-root coverage incomplete')
  call require(.not.generic_result%accepted_trajectory_direction%root_sink_direction_coverage_complete, &
       'GENERIC route falsely claimed root coverage')
  call require(root_result%accepted_trajectory_direction%additional_full_nonlinear_solves==0 .and. &
       generic_result%accepted_trajectory_direction%additional_full_nonlinear_solves==0, &
       'tangent added nonlinear solve')

  call materialize_solver_view(root_candidate,root_state,root_solver_parameters)
  call materialize_solver_view(generic_candidate,generic_state,generic_solver_parameters)

  head_diff=maxval(abs(root_state%pressure_head-generic_state%pressure_head))
  theta_diff=maxval(abs(root_state%water_content-generic_state%water_content))
  direction_head_diff=maxval(abs(root_result%accepted_trajectory_direction%final_pressure_head_direction- &
       generic_result%accepted_trajectory_direction%final_pressure_head_direction))
  direction_theta_diff=maxval(abs(root_result%accepted_trajectory_direction%final_water_content_direction- &
       generic_result%accepted_trajectory_direction%final_water_content_direction))
  exchange_direction_diff=abs(root_result%accepted_trajectory_direction%accepted_bottom_exchange_derivative- &
       generic_result%accepted_trajectory_direction%accepted_bottom_exchange_derivative)

  call require(same_scaled(head_diff,0.0_real64),'ROOT/GENERIC physical head mismatch')
  call require(same_scaled(theta_diff,0.0_real64),'ROOT/GENERIC physical theta mismatch')
  call require(same_scaled(direction_head_diff,0.0_real64),'ROOT/GENERIC head-direction mismatch')
  call require(same_scaled(direction_theta_diff,0.0_real64),'ROOT/GENERIC theta-direction mismatch')
  call require(same_scaled(exchange_direction_diff,0.0_real64),'ROOT/GENERIC exchange-direction mismatch')

  call build_modflow6_swap_predictor_tangent_endpoint(root_state,root_solver_parameters,constitutive, &
       root_result%accepted_trajectory_direction,qref,datum,.false.,.true.,.false.,.false., &
       root_endpoint,root_endpoint_status)
  call require(root_endpoint_status==MODFLOW6_TANGENT_ENDPOINT_OK .and. root_endpoint%available .and. &
       root_endpoint%authoritative,'ROOT endpoint not authoritative')
  call require(root_endpoint%coverage%root_uptake_active .and. root_endpoint%coverage%root_uptake_covered, &
       'ROOT endpoint coverage provenance missing')
  call require(root_endpoint%coverage%tangent_complete(),'ROOT endpoint coverage incomplete')

  call build_modflow6_swap_predictor_tangent_endpoint(generic_state,generic_solver_parameters,constitutive, &
       generic_result%accepted_trajectory_direction,qref,datum,.false.,.false.,.false.,.false., &
       generic_endpoint,generic_endpoint_status)
  call require(generic_endpoint_status==MODFLOW6_TANGENT_ENDPOINT_OK .and. generic_endpoint%available .and. &
       generic_endpoint%authoritative,'GENERIC endpoint not authoritative')
  endpoint_direction_diff=abs(root_endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day- &
       generic_endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day)
  call require(same_scaled(endpoint_direction_diff,0.0_real64),'ROOT/GENERIC bottom-face tangent mismatch')

  write(*,'(a,es24.16)') 'PPA_ROOT_HYD02_QREF=',qref
  write(*,'(a,i0)') 'PPA_ROOT_HYD02_ACCEPTED_SUBSTEPS=',root_diag%accepted_substeps
  write(*,'(a,i0)') 'PPA_ROOT_HYD02_RETRIES=',root_diag%retries
  write(*,'(a,es24.16)') 'PPA_ROOT_HYD02_PHYSICAL_HEAD_DIFF=',head_diff
  write(*,'(a,es24.16)') 'PPA_ROOT_HYD02_DIRECTION_HEAD_DIFF=',direction_head_diff
  write(*,'(a,es24.16)') 'PPA_ROOT_HYD02_EXCHANGE_DIRECTION_DIFF=',exchange_direction_diff
  write(*,'(a,es24.16)') 'PPA_ROOT_HYD02_ENDPOINT_DIRECTION_DIFF=',endpoint_direction_diff
  write(*,'(a)') 'PPA_ROOT_HYD02_ROOT_GENERIC_PHYSICAL_IDENTITY=PASS'
  write(*,'(a)') 'PPA_ROOT_HYD02_ROOT_GENERIC_DIRECTIONAL_IDENTITY=PASS'
  write(*,'(a)') 'PPA_ROOT_HYD02_ROOT_COVERAGE_PROVENANCE=PASS'
  write(*,'(a)') 'PPA_ROOT_HYD02_MODFLOW_ENDPOINT_AUTHORITATIVE=PASS'
  write(*,'(a)') 'PPA_ROOT_HYD02_NO_EXTRA_NONLINEAR_SOLVE=PASS'
  write(*,'(a)') 'PPA_ROOT_HYD02_GATE=PASS'

contains

  subroutine run_route(root_route,result,candidate,diagnostics)
    logical,intent(in) :: root_route
    type(kernel_result_t),intent(out) :: result
    type(kernel_candidate_state_t),intent(out) :: candidate
    type(kernel_diagnostics_t),intent(out) :: diagnostics
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    integer :: rooted
    logical :: ok

    parameters=base_parameters
    parameters%root_extraction_active=root_route
    call initialize_forcing(forcing,qref)
    rooted=min(4,numnod)
    if(root_route)then
      forcing%root_extraction_sink(1:rooted)=ROOT_TOTAL/real(rooted,real64)
    else
      forcing%drainage_flux_by_level(1,1:rooted)=ROOT_TOTAL/real(rooted,real64)
    end if
    call initialize_temporal_committed_state(committed)
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call require(ok,'checkpoint capture')
    config=numerical_config()
    call backend%initialize(top)
    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,DURATION, &
         checkpoint,result,candidate,diagnostics)
  end subroutine run_route

  function numerical_config() result(cfg)
    type(canonical_numerical_config_t) :: cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=MASS_TOL
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=8
    cfg%max_committed_substeps=32
    cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.true.
    cfg%model_temporal_indicator_budget=TEMPORAL_BUDGET
    cfg%accepted_trajectory_direction%requested=.true.
    cfg%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
  end function numerical_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=593010_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=SW_STEP_CONTROL_BOTTOM_FLUX
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=MASS_TOL; p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=MASS_TOL; p%head_rel_tolerance=MASS_TOL; p%ponding_tolerance=MASS_TOL
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,flux)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::flux
    f%top_flux=flux; f%top_head=H0_CM; f%bottom_flux=flux; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=593020_int64; t%physics_topology_id=593021_int64; t%vertical_layout_id=593022_int64
    t%state_layout_id=593023_int64; t%solver_interface_id=593024_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine derive_equilibrium_flux(provider,flux)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(out)::flux
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0_CM
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    flux=-conductivity(1)
    call require(ieee_is_finite(flux),'equilibrium flux finite')
  end subroutine derive_equilibrium_flux

  subroutine initialize_temporal_committed_state(state)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_state_t)::physical
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::previous_derivative(numnod)
    logical::ok
    heads=H0_CM
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water
    physical%ponding_depth=0.0_real64; physical%groundwater_level=-2.0_real64
    previous_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,COLUMN_ID,physical,0.0_real64,ok,previous_derivative)
    call require(ok,'temporal committed state initialization')
  end subroutine initialize_temporal_committed_state

  subroutine materialize_solver_view(candidate,state,parameter_set)
    type(kernel_candidate_state_t),intent(in)::candidate
    type(soil_water_physical_state_t),intent(out)::state
    type(soil_water_parameter_set_t),intent(out)::parameter_set
    class(transaction_state_t),allocatable::snapshot
    logical::available
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
    parameter_set%parameter_set_id=base_parameters%parameter_set_id
    parameter_set%active_nodes=base_parameters%active_nodes
    allocate(parameter_set%z(numnod),parameter_set%dz(numnod),parameter_set%node_distance(numnod))
    parameter_set%z=base_parameters%z; parameter_set%dz=base_parameters%dz
    parameter_set%node_distance=base_parameters%node_distance
  end subroutine materialize_solver_view

  pure logical function same_scaled(a,b) result(same)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    same=ieee_is_finite(a) .and. ieee_is_finite(b) .and. &
         abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function same_scaled

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_ROOT_HYD02_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_root_hyd02_prescribed_root_tangent
