program test_fpm08d7_transactional_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_optional_state_layouts, only: FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_fixed_weir_surface_water_state_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_fixed_weir_surface_water_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t
  use mod_fmr_fixed_weir_serialized_runtime, only: fmr_execute_serialized_fixed_weir_resolved_column, &
       FMR_FIXED_WEIR_CONTEXT_OK
  use mod_restricted_fixed_weir_surface_water, only: fixed_weir_surface_water_parameters_t, &
       fixed_weir_surface_water_forcing_t, fixed_weir_surface_water_numerical_config_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 8123.125_real64
  real(real64), parameter :: t1 = 8123.375_real64
  real(real64), parameter :: initial_head = -123.0_real64
  real(real64), parameter :: mass_gate = 1.0e-10_real64
  integer(int64), parameter :: column_id = 807001_int64

  call verify_internal_drainage_mass_and_single_commit()
  call verify_supply_external_in()
  call verify_discharge_external_out()
  call verify_scalar_node_mismatch_rolls_back()
  call verify_infeasible_surface_water_rolls_back()
  call verify_model_certificate_mode_is_held()

  write(*,'(A)') 'FPM08D7_TRANSACTIONAL_RUNTIME_OWNER_TEST PASS'

contains

  subroutine verify_internal_drainage_mass_and_single_commit()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_weir_surface_water_parameters_t) :: swp
    type(fixed_weir_surface_water_forcing_t) :: swf
    type(fixed_weir_surface_water_numerical_config_t) :: swn
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls, context_status
    real(real64) :: q, swst_before, swst_after

    q = 2.0e-2_real64
    call initialize_case(committed,column,template,parameters,forcing,config,swp,swn,95.0_real64,q,q)
    swf%secondary_drainage_rate = q
    swf%supply_capacity_rate = 0.0_real64
    call backend%initialize(top)
    call reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    call fmr_execute_serialized_fixed_weir_resolved_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,swp,swf,swn,t0,t1,output,diagnostic,runtime,active_calls,context_status)
    observation = backend%observation()

    call require(context_status == FMR_FIXED_WEIR_CONTEXT_OK,'internal drainage context')
    call require(output%completed .and. output%committed,'internal drainage commit')
    call require(output%final_revision == 1_int64 .and. committed%current_revision() == 1_int64,'single commit revision')
    call require(output%mass%complete .and. output%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         'internal drainage mass complete')
    call require(abs(output%mass%residual) <= mass_gate,'internal drainage hard mass closure')
    call snapshot_swst(committed,swst_after)
    swst_before = 95.0_real64
    call require(abs((swst_after-swst_before) - q*(t1-t0)) <= mass_gate,'authoritative scalar became SWST')
    call require(abs(output%mass%total_in - q*(t1-t0)) <= mass_gate,'node-balancing qssdi is external input')
    call require(abs(output%mass%total_out) <= mass_gate,'internal qdra was not external outflow')
    call require(observation%fixed_weir_surface_water_active,'surface-water observation active')
    call require(observation%fixed_weir_surface_water_discharge_rate <= mass_gate,'unexpected weir discharge')
    call require(active_calls == 0,'physical call counter restored')
    write(*,'(A)') 'FPM08D7_INTERNAL_DRAINAGE_MASS_AND_SINGLE_COMMIT=PASS'
  end subroutine verify_internal_drainage_mass_and_single_commit

  subroutine verify_supply_external_in()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_weir_surface_water_parameters_t) :: swp
    type(fixed_weir_surface_water_forcing_t) :: swf
    type(fixed_weir_surface_water_numerical_config_t) :: swn
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls, context_status
    real(real64) :: swst_after

    call initialize_case(committed,column,template,parameters,forcing,config,swp,swn,80.0_real64,0.0_real64,0.0_real64)
    swf%secondary_drainage_rate = 0.0_real64
    swf%supply_capacity_rate = 100.0_real64
    call backend%initialize(top)
    call reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    call fmr_execute_serialized_fixed_weir_resolved_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,swp,swf,swn,t0,t1,output,diagnostic,runtime,active_calls,context_status)
    observation = backend%observation()
    call require(output%committed .and. output%mass%complete,'supply committed')
    call require(abs(output%mass%residual) <= mass_gate,'supply mass closure')
    call snapshot_swst(committed,swst_after)
    call require(swst_after > 80.0_real64,'supply raised SWST')
    call require(output%mass%total_in > 0.0_real64,'supply external input missing')
    call require(abs(output%mass%total_out) <= mass_gate,'supply unexpected external out')
    call require(observation%fixed_weir_surface_water_supply_rate > 0.0_real64,'supply diagnostic')
    write(*,'(A)') 'FPM08D7_SUPPLY_EXTERNAL_IN=PASS'
  end subroutine verify_supply_external_in

  subroutine verify_discharge_external_out()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_weir_surface_water_parameters_t) :: swp
    type(fixed_weir_surface_water_forcing_t) :: swf
    type(fixed_weir_surface_water_numerical_config_t) :: swn
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls, context_status
    real(real64) :: swst_after

    call initialize_case(committed,column,template,parameters,forcing,config,swp,swn,120.0_real64,0.0_real64,0.0_real64)
    config%transaction%temporal_tolerance = 1.0e3_real64
    swf%secondary_drainage_rate = 0.0_real64
    swf%supply_capacity_rate = 0.0_real64
    call backend%initialize(top)
    call reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    call fmr_execute_serialized_fixed_weir_resolved_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,swp,swf,swn,t0,t1,output,diagnostic,runtime,active_calls,context_status)
    observation = backend%observation()
    call require(output%committed .and. output%mass%complete,'discharge committed')
    call require(abs(output%mass%residual) <= mass_gate,'discharge mass closure')
    call snapshot_swst(committed,swst_after)
    call require(swst_after < 120.0_real64,'discharge lowered SWST')
    call require(output%mass%total_out > 0.0_real64,'discharge external output missing')
    call require(abs(output%mass%total_in) <= mass_gate,'discharge unexpected external input')
    call require(observation%fixed_weir_surface_water_discharge_rate > 0.0_real64,'discharge diagnostic')
    write(*,'(A)') 'FPM08D7_DISCHARGE_EXTERNAL_OUT=PASS'
  end subroutine verify_discharge_external_out

  subroutine verify_scalar_node_mismatch_rolls_back()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_weir_surface_water_parameters_t) :: swp
    type(fixed_weir_surface_water_forcing_t) :: swf
    type(fixed_weir_surface_water_numerical_config_t) :: swn
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls, context_status
    real(real64) :: swst_after

    call initialize_case(committed,column,template,parameters,forcing,config,swp,swn,95.0_real64,2.0e-2_real64,2.0e-2_real64)
    config%transaction%max_retries = 2
    swf%secondary_drainage_rate = 3.0e-2_real64
    swf%supply_capacity_rate = 0.0_real64
    call backend%initialize(top)
    call reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    call fmr_execute_serialized_fixed_weir_resolved_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,swp,swf,swn,t0,t1,output,diagnostic,runtime,active_calls,context_status)
    call require(.not. output%committed,'scalar/node mismatch unexpectedly committed')
    call require(committed%current_revision() == 0_int64,'scalar/node mismatch mutated revision')
    call snapshot_swst(committed,swst_after)
    call require(same_bits(swst_after,95.0_real64),'scalar/node mismatch mutated committed SWST')
    call require(diagnostic%rejected == 1,'scalar/node mismatch missing rejection diagnostic')
    write(*,'(A)') 'FPM08D7_SCALAR_NODE_MISMATCH_ROLLBACK=PASS'
  end subroutine verify_scalar_node_mismatch_rolls_back

  subroutine verify_infeasible_surface_water_rolls_back()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_weir_surface_water_parameters_t) :: swp
    type(fixed_weir_surface_water_forcing_t) :: swf
    type(fixed_weir_surface_water_numerical_config_t) :: swn
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls, context_status
    real(real64) :: swst_after

    call initialize_case(committed,column,template,parameters,forcing,config,swp,swn,199.0_real64,0.0_real64,0.0_real64)
    config%transaction%max_retries = 1
    swf%secondary_drainage_rate = 1.0e6_real64
    swf%supply_capacity_rate = 0.0_real64
    call backend%initialize(top)
    call reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    call fmr_execute_serialized_fixed_weir_resolved_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,swp,swf,swn,t0,t1,output,diagnostic,runtime,active_calls,context_status)
    call require(.not. output%committed,'infeasible surface water unexpectedly committed')
    call require(committed%current_revision() == 0_int64,'infeasible surface water mutated revision')
    call snapshot_swst(committed,swst_after)
    call require(same_bits(swst_after,199.0_real64),'infeasible surface water mutated committed SWST')
    write(*,'(A)') 'FPM08D7_INFEASIBLE_TRIAL_ROLLBACK=PASS'
  end subroutine verify_infeasible_surface_water_rolls_back

  subroutine verify_model_certificate_mode_is_held()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_weir_surface_water_parameters_t) :: swp
    type(fixed_weir_surface_water_forcing_t) :: swf
    type(fixed_weir_surface_water_numerical_config_t) :: swn
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls, context_status
    real(real64) :: swst_after

    call initialize_case(committed,column,template,parameters,forcing,config,swp,swn,95.0_real64,0.0_real64,0.0_real64)
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    swf%secondary_drainage_rate = 0.0_real64
    swf%supply_capacity_rate = 0.0_real64
    call backend%initialize(top)
    call reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    call fmr_execute_serialized_fixed_weir_resolved_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,swp,swf,swn,t0,t1,output,diagnostic,runtime,active_calls,context_status)
    call require(.not. output%committed,'held model-certificate route committed')
    call require(output%kernel_status == KERNEL_STATUS_NOT_ADMITTED,'held model-certificate route status')
    call require(.not. output%solver_executed,'held model-certificate route executed solver')
    call require(committed%current_revision() == 0_int64,'held model-certificate route mutated revision')
    call snapshot_swst(committed,swst_after)
    call require(same_bits(swst_after,95.0_real64),'held model-certificate route mutated SWST')
    write(*,'(A)') 'FPM08D7_MODEL_CERTIFICATE_ROUTE_HELD=PASS'
  end subroutine verify_model_certificate_mode_is_held

  subroutine initialize_case(committed,column,template,parameters,forcing,config,swp,swn,initial_swst,qnode,qssdi_total)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    type(fixed_weir_surface_water_parameters_t), intent(out) :: swp
    type(fixed_weir_surface_water_numerical_config_t), intent(out) :: swn
    real(real64), intent(in) :: initial_swst, qnode, qssdi_total
    type(fmr_b110_fixed_weir_surface_water_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod), k0
    logical :: ok
    integer :: k

    parameters%parameter_set_id = 80701_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k=1,numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%root_extraction_active=.true.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.
    parameters%elasticity_active=.false.; parameters%frost_active=.false.

    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,t1-t0)
    heads = initial_head
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0 = conductivity(1)

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.25_real64
    state%surface_water%storage=initial_swst
    call fmr_new_b110_fixed_weir_surface_water_committed_state(committed,column_id,state,t0,ok)
    call require(ok,'D7 committed state initialization')

    template%template_id=807_int64; template%physics_topology_id=80711_int64; template%vertical_layout_id=80712_int64
    template%state_layout_id=80713_int64; template%solver_interface_id=80714_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id; column%template_id=template%template_id; column%parameter_ref=1_int64
    column%state_handle=1_int64; column%forcing_handle=1_int64; column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    forcing%top_flux=-k0; forcing%top_head=initial_head; forcing%bottom_flux=-k0; forcing%bottom_head=-321.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64; forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
    forcing%drainage_flux_by_level(1,1)=qnode
    forcing%subsurface_irrigation_source(1)=qssdi_total

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e-8_real64
    config%transaction%mass_tolerance=mass_gate
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=4
    config%max_committed_substeps=8; config%progress_tolerance=0.0_real64

    allocate(swp%level_knots(22),swp%storage_knots(22))
    do k=1,22
      swp%level_knots(k)=100.0_real64-real(k-1,real64)*(200.0_real64/21.0_real64)
      swp%storage_knots(k)=200.0_real64-real(k-1,real64)*(200.0_real64/21.0_real64)
    end do
    swp%level_knots(22)=-100.0_real64; swp%storage_knots(22)=0.0_real64
    swp%weir_head=0.0_real64; swp%rating_coefficient=0.5_real64; swp%rating_exponent=1.5_real64; swp%supply_dip=10.0_real64
    swn%max_bisection_iterations=160
    swn%rating_storage_abs_tolerance=1.0e-12_real64; swn%rating_storage_rel_tolerance=1.0e-12_real64
  end subroutine initialize_case

  subroutine reset_runtime_outputs(output,diagnostic,runtime,active_calls)
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls
    output=fmr_serialized_column_result_t(); output%column_id=column_id; output%requested_t0=t0; output%requested_t1=t1
    diagnostic=fmr_column_diagnostics_t(); diagnostic%column_id=column_id
    runtime=fmr_serialized_batch_diagnostics_t(); active_calls=0
  end subroutine reset_runtime_outputs

  subroutine snapshot_swst(committed,storage)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: storage
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call committed%snapshot(snapshot,available)
    call require(available,'committed snapshot available')
    select type (physical=>snapshot)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      storage=physical%surface_water%storage
    class default
      error stop 'F-PM08D7 unexpected committed state type'
    end select
  end subroutine snapshot_swst

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08D7_TEST_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08d7_transactional_runtime
