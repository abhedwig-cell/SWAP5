program test_fmr36_divdra_active_runtime_callsite_v2
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  use mod_fmr_divdra_serialized_runtime, only: fmr_divdra_serialized_column_request_t, &
       fmr_divdra_serialized_binding_record_t, fmr_run_serialized_physical_multiswap_with_divdra
  use mod_fmr_divdra_serialized_composition, only: FMR_DIVDRA_COMPOSE_OK, FMR_DIVDRA_COMPOSE_BIND_REJECTED, &
       FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: interval_t0 = 2100.375_real64
  real(real64), parameter :: interval_t1 = 2100.875_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: primary_column_id = 909001_int64
  integer :: wt_shallow, wt_deep

  call test_fvq21_control_replay()
  call test_inactive_identity()
  call test_active_equivalence(-0.25_real64, 0.04_real64, wt_shallow)
  call test_active_equivalence(-1.25_real64, 0.04_real64, wt_deep)
  call require(wt_shallow /= wt_deep, 'explicit views choose distinct water-table nodes')
  write(*,'(A,I0,A,I0)') 'FMR36_EXPLICIT_VIEW_WT_NODES=',wt_shallow,',',wt_deep
  write(*,'(A)') 'FMR36_EXPLICIT_HYDRAULIC_VIEW_NOT_SUBSTITUTED=PASS'
  call test_zero_transfer()
  call test_preflight_rejections()
  call test_shared_forcing_rejection()
  write(*,'(A)') 'FMR36_ACTIVE_RUNTIME_CALLSITE_TEST PASS'

contains

  subroutine test_fvq21_control_replay()
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(kernel_committed_state_t) :: states(1)
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime_diag
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    integer :: dispatch

    call initialize_case(columns,templates,parameters,forcings,states,config)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns,templates,parameters,forcings,states,config,top_provider, &
         interval_t0,interval_t1,1,results,diagnostics,aggregate,dispatch,runtime_diag)
    call require(dispatch==FMR_SERIAL_DISPATCH_OK,'F-VQ21 control dispatch')
    call require(results(1)%completed .and. results(1)%committed .and. results(1)%solver_executed,'F-VQ21 control commit')
    call require(results(1)%mass%complete .and. results(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE, &
         'F-VQ21 control mass complete')
    call require(abs(results(1)%mass%residual)<=hard_mass_gate,'F-VQ21 control hard mass')
    call require(runtime_diag%max_simultaneous_real_physical_solves==1,'F-VQ21 serialized physical solve')
    write(*,'(A)') 'FMR36_FVQ21_CONTROL_REPLAY=PASS'
  end subroutine test_fvq21_control_replay

  subroutine test_inactive_identity()
    type(fmr_logical_column_t) :: columns_a(1),columns_b(1)
    type(fmr_template_t) :: templates_a(1),templates_b(1)
    type(fmr_b110_physical_parameters_t) :: parameters_a(1),parameters_b(1)
    type(fmr_b110_physical_forcing_t) :: forcings_a(1),forcings_b(1)
    type(kernel_committed_state_t) :: states_a(1),states_b(1)
    type(canonical_numerical_config_t) :: config_a,config_b
    type(fmr_serialized_column_result_t), allocatable :: results_a(:),results_b(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics_a(:),diagnostics_b(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate_a,aggregate_b
    type(fmr_divdra_serialized_column_request_t) :: requests(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: distribution(1)
    type(process_hydraulic_view_t) :: views(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    integer :: dispatch_a,dispatch_b,compose

    call initialize_case(columns_a,templates_a,parameters_a,forcings_a,states_a,config_a)
    call initialize_case(columns_b,templates_b,parameters_b,forcings_b,states_b,config_b)
    call configure_divdra(distribution(1),views(1),-0.25_real64)
    requests(1)=fmr_divdra_serialized_column_request_t()
    requests(1)%column_id=primary_column_id

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns_a,templates_a,parameters_a,forcings_a,states_a,config_a,top_provider, &
         interval_t0,interval_t1,1,results_a,diagnostics_a,aggregate_a,dispatch_a)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(columns_b,templates_b,parameters_b,forcings_b,states_b,config_b, &
         top_provider,interval_t0,interval_t1,1,requests,distribution,views,results_b,diagnostics_b,aggregate_b,dispatch_b, &
         compose,records)

    call require(dispatch_a==FMR_SERIAL_DISPATCH_OK .and. dispatch_b==FMR_SERIAL_DISPATCH_OK,'inactive dispatch identity')
    call require(results_a(1)%committed .and. results_b(1)%committed,'inactive commit identity')
    call require(compose==FMR_DIVDRA_COMPOSE_OK .and. size(records)==0,'inactive sparse composition')
    call require(same_result(results_a(1),results_b(1)),'inactive exact result identity')
    call require(committed_fingerprint(states_a(1))==committed_fingerprint(states_b(1)),'inactive state identity')
    call require(allocated(forcings_b(1)%drainage_flux_by_level),'inactive drainage retained')
    call require(all(forcings_b(1)%drainage_flux_by_level==0.0_real64),'inactive caller forcing unchanged')
    write(*,'(A)') 'FMR36_INACTIVE_FVQ21_RUNTIME_IDENTITY=PASS'
  end subroutine test_inactive_identity

  subroutine test_active_equivalence(gwl,scalar_transfer,water_table_node)
    real(real64), intent(in) :: gwl,scalar_transfer
    integer, intent(out) :: water_table_node
    type(fmr_logical_column_t) :: columns_a(1),columns_b(1)
    type(fmr_template_t) :: templates_a(1),templates_b(1)
    type(fmr_b110_physical_parameters_t) :: parameters_a(1),parameters_b(1)
    type(fmr_b110_physical_forcing_t) :: forcings_a(1),forcings_b(1)
    type(kernel_committed_state_t) :: states_a(1),states_b(1)
    type(canonical_numerical_config_t) :: config_a,config_b
    type(fmr_serialized_column_result_t), allocatable :: results_a(:),results_b(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics_a(:),diagnostics_b(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate_a,aggregate_b
    type(fmr_divdra_serialized_column_request_t) :: requests(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: distribution(1)
    type(process_hydraulic_view_t) :: views(1)
    type(fmr_divdra_binding_diagnostics_t) :: bind_diag
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    real(real64), allocatable :: expected_row(:)
    real(real64) :: tolerance,expected_amount
    integer :: dispatch_a,dispatch_b,compose

    call initialize_case(columns_a,templates_a,parameters_a,forcings_a,states_a,config_a)
    call initialize_case(columns_b,templates_b,parameters_b,forcings_b,states_b,config_b)
    deallocate(forcings_a(1)%drainage_flux_by_level,forcings_b(1)%drainage_flux_by_level)
    call configure_divdra(distribution(1),views(1),gwl)

    call fmr_bind_single_level_positive_divdra(distribution(1),views(1),scalar_transfer, &
         forcings_a(1)%drainage_flux_by_level,bind_diag)
    call require(bind_diag%status==FMR_DIVDRA_BIND_OK .and. bind_diag%published,'manual F-MR33 binding')
    allocate(expected_row(numnod)); expected_row=forcings_a(1)%drainage_flux_by_level(1,:)
    call require(same_bits(sum(expected_row),scalar_transfer),'authoritative scalar closure')

    ! Exact F-VQ21 balancing principle: source and sink coincide per node.
    forcings_a(1)%subsurface_irrigation_source=expected_row
    forcings_b(1)%subsurface_irrigation_source=expected_row
    forcings_a(1)%root_extraction_sink=0.0_real64
    forcings_b(1)%root_extraction_sink=0.0_real64

    requests(1)=fmr_divdra_serialized_column_request_t()
    requests(1)%column_id=primary_column_id
    requests(1)%active=.true.
    requests(1)%distribution_parameter_ref=1_int64
    requests(1)%hydraulic_view_ref=1_int64
    requests(1)%scalar_transfer=scalar_transfer

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(columns_a,templates_a,parameters_a,forcings_a,states_a,config_a,top_provider, &
         interval_t0,interval_t1,1,results_a,diagnostics_a,aggregate_a,dispatch_a)
    call require(dispatch_a==FMR_SERIAL_DISPATCH_OK .and. results_a(1)%committed,'manual prepared runtime commit')
    call require(results_a(1)%mass%complete .and. abs(results_a(1)%mass%residual)<=hard_mass_gate,'manual hard mass')

    call require(.not.allocated(forcings_b(1)%drainage_flux_by_level),'active candidate starts unbound')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(columns_b,templates_b,parameters_b,forcings_b,states_b,config_b, &
         top_provider,interval_t0,interval_t1,1,requests,distribution,views,results_b,diagnostics_b,aggregate_b,dispatch_b, &
         compose,records)

    call require(compose==FMR_DIVDRA_COMPOSE_OK .and. dispatch_b==FMR_SERIAL_DISPATCH_OK,'active wrapper dispatch')
    call require(results_b(1)%committed .and. size(records)==1 .and. records(1)%binding%published,'active binding and commit')
    call require(same_bits(records(1)%binding%authoritative_scalar_transfer,scalar_transfer),'scalar diagnostic identity')
    call require(same_result(results_a(1),results_b(1)),'manual versus active exact result identity')
    call require(committed_fingerprint(states_a(1))==committed_fingerprint(states_b(1)),'manual versus active state identity')
    call require(.not.allocated(forcings_b(1)%drainage_flux_by_level),'active caller forcing restored')
    call require(results_b(1)%mass%complete .and. abs(results_b(1)%mass%residual)<=hard_mass_gate,'active hard mass')
    expected_amount=scalar_transfer*(interval_t1-interval_t0)
    tolerance=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(expected_amount))
    call require(abs(results_b(1)%mass%total_in-results_a(1)%mass%total_in)<=tolerance,'manual active total_in identity')
    call require(abs(results_b(1)%mass%total_out-results_a(1)%mass%total_out)<=tolerance,'manual active total_out identity')

    water_table_node=records(1)%binding%process%water_table_node
    write(*,'(A,ES24.16,A,I0)') 'FMR36_ACTIVE_SCALAR=',scalar_transfer,',WT=',water_table_node
    write(*,'(A)') 'FMR36_MANUAL_BINDING_RUNTIME_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR36_EXISTING_MASS_LEDGER_EXACTLY_ONCE_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR36_CALLER_FORCING_RESTORED=PASS'
  end subroutine test_active_equivalence

  subroutine test_zero_transfer()
    integer :: water_table_node
    call test_active_equivalence(-0.25_real64,0.0_real64,water_table_node)
    write(*,'(A)') 'FMR36_ZERO_TRANSFER_ACTIVE_CALLSITE=PASS'
  end subroutine test_zero_transfer

  subroutine test_preflight_rejections()
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(kernel_committed_state_t) :: states(1)
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_divdra_serialized_column_request_t) :: requests(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: distribution(1)
    type(process_hydraulic_view_t) :: views(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    integer :: dispatch,compose

    call configure_divdra(distribution(1),views(1),-0.25_real64)

    call initialize_case(columns,templates,parameters,forcings,states,config)
    deallocate(forcings(1)%drainage_flux_by_level)
    call make_active_request(requests(1),-0.04_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(columns,templates,parameters,forcings,states,config,top_provider, &
         interval_t0,interval_t1,1,requests,distribution,views,results,diagnostics,aggregate,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. dispatch==FMR_SERIAL_DISPATCH_INVALID_REQUEST, &
         'negative preflight reject')
    call require(states(1)%current_revision()==0_int64 .and. .not.allocated(forcings(1)%drainage_flux_by_level), &
         'negative reject premutation')

    call initialize_case(columns,templates,parameters,forcings,states,config)
    deallocate(forcings(1)%drainage_flux_by_level)
    call make_active_request(requests(1),1.0e-10_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(columns,templates,parameters,forcings,states,config,top_provider, &
         interval_t0,interval_t1,1,requests,distribution,views,results,diagnostics,aggregate,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. states(1)%current_revision()==0_int64, &
         'restricted seam premutation reject')
    call require(.not.allocated(forcings(1)%drainage_flux_by_level),'restricted seam no forcing mutation')

    call initialize_case(columns,templates,parameters,forcings,states,config)
    call make_active_request(requests(1),0.04_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(columns,templates,parameters,forcings,states,config,top_provider, &
         interval_t0,interval_t1,1,requests,distribution,views,results,diagnostics,aggregate,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. states(1)%current_revision()==0_int64, &
         'prebound target premutation reject')
    call require(allocated(forcings(1)%drainage_flux_by_level) .and. all(forcings(1)%drainage_flux_by_level==0.0_real64), &
         'prebound target unchanged')

    write(*,'(A)') 'FMR36_INVALID_TRANSFER_PRECOMMIT_REJECTION=PASS'
    write(*,'(A)') 'FMR36_PREBOUND_TARGET_NO_OVERWRITE=PASS'
  end subroutine test_preflight_rejections

  subroutine test_shared_forcing_rejection()
    type(fmr_logical_column_t) :: columns(2)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(kernel_committed_state_t) :: states(2)
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_divdra_serialized_column_request_t) :: requests(2)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: distribution(1)
    type(process_hydraulic_view_t) :: views(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0
    logical :: ok
    integer :: dispatch,compose

    call configure_physical_parameters(parameters(1),initial_state,conductivity0)
    parameters(1)%root_extraction_active=.true.
    call configure_column(columns(1),templates(1))
    columns(2)=columns(1); columns(2)%column_id=909002_int64; columns(2)%state_handle=2_int64
    call configure_control_forcing(forcings(1),conductivity0)
    deallocate(forcings(1)%drainage_flux_by_level)
    call configure_transaction(config)
    call fmr_new_b110_committed_state(states(1),columns(1)%column_id,initial_state,interval_t0,ok); call require(ok,'shared init 1')
    call fmr_new_b110_committed_state(states(2),columns(2)%column_id,initial_state,interval_t0,ok); call require(ok,'shared init 2')
    call configure_divdra(distribution(1),views(1),-0.25_real64)
    call make_active_request(requests(1),0.04_real64)
    requests(2)=fmr_divdra_serialized_column_request_t(); requests(2)%column_id=columns(2)%column_id

    call fmr_run_serialized_physical_multiswap_with_divdra(columns,templates,parameters,forcings,states,config,top_provider, &
         interval_t0,interval_t1,2,requests,distribution,views,results,diagnostics,aggregate,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE,'shared forcing rejected')
    call require(dispatch==FMR_SERIAL_DISPATCH_INVALID_REQUEST,'shared forcing no core dispatch')
    call require(states(1)%current_revision()==0_int64 .and. states(2)%current_revision()==0_int64,'shared premutation')
    call require(.not.allocated(forcings(1)%drainage_flux_by_level),'shared forcing no mutation')
    write(*,'(A)') 'FMR36_SHARED_FORCING_NO_CROSS_COLUMN_LEAKAGE=PASS'
  end subroutine test_shared_forcing_rejection

  subroutine initialize_case(columns,templates,parameters,forcings,states,config)
    type(fmr_logical_column_t), intent(out) :: columns(1)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcings(1)
    type(kernel_committed_state_t), intent(out) :: states(1)
    type(canonical_numerical_config_t), intent(out) :: config
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0
    logical :: ok

    call configure_physical_parameters(parameters(1),initial_state,conductivity0)
    parameters(1)%root_extraction_active=.true.
    call configure_column(columns(1),templates(1))
    call configure_control_forcing(forcings(1),conductivity0)
    call configure_transaction(config)
    call fmr_new_b110_committed_state(states(1),columns(1)%column_id,initial_state,interval_t0,ok)
    call require(ok,'committed state init')
  end subroutine initialize_case

  subroutine make_active_request(request,scalar_transfer)
    type(fmr_divdra_serialized_column_request_t), intent(out) :: request
    real(real64), intent(in) :: scalar_transfer
    request=fmr_divdra_serialized_column_request_t()
    request%column_id=primary_column_id
    request%active=.true.
    request%distribution_parameter_ref=1_int64
    request%hydraulic_view_ref=1_int64
    request%scalar_transfer=scalar_transfer
  end subroutine make_active_request

  subroutine configure_column(column,template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id=909_int64
    template%physics_topology_id=90901_int64
    template%vertical_layout_id=90902_int64
    template%state_layout_id=90903_int64
    template%solver_interface_id=90904_int64
    template%optional_state_layout_id=90905_int64
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=primary_column_id
    column%template_id=template%template_id
    column%parameter_ref=1_int64
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_physical_parameters(p,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id=90901_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.

    call initialize_b110_default_mvg_parameters(hydraulic_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,interval_t1-interval_t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_physical_parameters

  subroutine configure_control_forcing(forcing,conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0
    forcing%top_flux=-conductivity0; forcing%top_head=head0
    forcing%bottom_flux=-conductivity0; forcing%bottom_head=-100.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine configure_control_forcing

  subroutine configure_divdra(distribution,view,gwl)
    type(drainage_distribution_parameters_t), intent(out) :: distribution
    type(process_hydraulic_view_t), intent(out) :: view
    real(real64), intent(in) :: gwl
    real(real64) :: depth
    integer :: k
    distribution%active_nodes=numnod
    allocate(distribution%dz(numnod),distribution%zbotcp(numnod),distribution%saturated_conductivity(numnod), &
         distribution%horizontal_anisotropy_factor(numnod))
    distribution%dz=dz; depth=0.0_real64
    do k=1,numnod
      depth=depth+dz(k); distribution%zbotcp(k)=-depth
    end do
    distribution%saturated_conductivity=1.0_real64
    distribution%horizontal_anisotropy_factor=1.0_real64
    distribution%drain_spacing=4.0_real64
    view%active_nodes=numnod
    allocate(view%pressure_head(numnod),view%water_content(numnod))
    view%pressure_head=head0; view%water_content=0.30_real64
    view%ponding_depth=0.0_real64; view%groundwater_level=gwl
  end subroutine configure_divdra

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=hard_mass_gate
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=2
    config%max_committed_substeps=8
    config%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra=12345.0_real64; legacy_qssdi=-54321.0_real64
    legacy_qrot=-99999.0_real64; swmacro=0; legacy_melt=0.0_real64
  end subroutine reset_legacy_globals

  logical function same_result(a,b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    equal=a%column_id==b%column_id .and. a%kernel_status==b%kernel_status .and. a%commit_status==b%commit_status .and. &
      a%completed.eqv.b%completed .and. a%committed.eqv.b%committed .and. a%solver_executed.eqv.b%solver_executed .and. &
      a%solver_iterations==b%solver_iterations .and. a%initial_revision==b%initial_revision .and. &
      a%final_revision==b%final_revision .and. same_bits(a%final_committed_time,b%final_committed_time) .and. &
      a%actual_transpiration_available.eqv.b%actual_transpiration_available .and. &
      same_bits(a%actual_transpiration_amount,b%actual_transpiration_amount) .and. &
      a%mass%complete.eqv.b%mass%complete .and. a%mass%missing_contribution_mask==b%mass%missing_contribution_mask .and. &
      a%mass%origin_lineage_id==b%mass%origin_lineage_id .and. a%mass%origin_revision==b%mass%origin_revision .and. &
      a%mass%accepted_transaction_count==b%mass%accepted_transaction_count .and. &
      same_bits(a%mass%interval_t0,b%mass%interval_t0) .and. same_bits(a%mass%interval_t1,b%mass%interval_t1) .and. &
      same_bits(a%mass%storage_start,b%mass%storage_start) .and. same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
      same_bits(a%mass%storage_change,b%mass%storage_change) .and. same_bits(a%mass%total_in,b%mass%total_in) .and. &
      same_bits(a%mass%total_out,b%mass%total_out) .and. same_bits(a%mass%residual,b%mass%residual)
  end function same_result

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: k
    call state%snapshot(snapshot,got); call require(got,'committed snapshot')
    fp=1469598103934665603_int64
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do k=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(k),fp)); fp=ieor(fp,transfer(physical%water_content(k),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp)); fp=ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR36 unexpected state type'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FMR36_TEST_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr36_divdra_active_runtime_callsite_v2
