program test_mc_irr01_allocated_root_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_temporal_indicator_state_t, &
       fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, &
       fmr_execute_serialized_resolved_physical_column
  use mod_fmr_management_irrigation_forcing_binding
  use mod_fmr_scheduled_management_irrigation_application
  use mod_fmr_irrigation_management_restart
  use mod_irrigation_process, only: IRRIGATION_APPLICATION_SSDI
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_EVENT_SCHEDULED
  use mod_fmr_irrigation_allocation_binding
  use mod_fmr_accepted_salt_irrigation_binding
  use mod_fmr_base_salt_temporal_policy, only: fmr_base_salt_temporal_policy_t
  use mod_fmr_serialized_reference_backend, only: fmr_initialize_mobile_salt_profile, fmr_new_b110_committed_state
  use mod_fmr_runtime_core, only: FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED,FMR_NUMERICAL_CONTINUATION_NONE
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_parameters_t,irrigation_management_policy_result_t
  use mod_fmr_scheduled_irrigation_forcing_binding, only: fmr_irrigation_forcing_binding_diagnostics_t
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t,fmr_export_committed_restart,fmr_restore_committed_restart
  implicit none
  real(real64), parameter :: t0 = 0.375_real64
  real(real64), parameter :: expected_depth = 1.0_real64
  real(real64), parameter :: expected_rate = 48.0_real64
  real(real64), parameter :: expected_duration = expected_depth / expected_rate
  real(real64), parameter :: t1 = t0 + expected_duration
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_forcing_t) :: base
  type(kernel_committed_state_t) :: physical, resumed(1), rejected(1)
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config,rejected_config
  type(scheduled_irrigation_parameters_t) :: sensor
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_root_zone_parameters_t) :: root
  type(irrigation_management_policy_parameters_t) :: depth
  type(irrigation_management_policy_result_t) :: selected
  type(fmr_irrigation_forcing_binding_diagnostics_t) :: binding
  type(fmr_allocated_irrigation_state_t) :: management,resumed_management
  type(fmr_irrigation_management_parameters_t) :: root_irrigation
  type(fmr_management_forcing_binding_diagnostics_t) :: root_binding
  type(fmr_allocated_irrigation_state_t) :: management_wrapper,restored_wrapper
  type(fmr_allocated_irrigation_restart_t) :: management_record
  type(fmr_irrigation_allocation_t) :: delivery
  type(fmr_committed_restart_bundle_t) :: bundle
  type(fmr_serialized_column_result_t) :: result,result_resumed
  type(fmr_serialized_batch_diagnostics_t) :: runtime
  real(real64) :: conductivity0,theta0,initial_irrigation_derivative(numnod),duration,mid,total_in
  integer :: timing,mode,layout,status,nodes,dispatch
  type(kernel_committed_state_t) :: prelude(1), before_reject
  type(fmr_serialized_column_result_t),allocatable :: prelude_result(:)
  type(fmr_column_diagnostics_t),allocatable :: prelude_diag(:)
  type(fmr_aggregate_diagnostics_t) :: prelude_aggregate
  type(fmr_base_salt_temporal_policy_t) :: salt_policy
  type(fmr_accepted_salt_irrigation_diagnostics_t) :: salt_diag
  class(transaction_state_t),allocatable :: salt_snapshot
  real(real64) :: field_deficit,initial_salt,current_salt,derived_cml
  integer(int64) :: salt_revision
  logical :: ok,accepted,exported
  salt_policy%enabled=.true.;salt_policy%head_tolerance_cm=.01_real64
  salt_policy%water_tolerance_cm=1.e-6_real64;salt_policy%salt_tolerance_mg_cm2=1.e-7_real64
  salt_policy%temperature_tolerance_c=.01_real64
  do timing=2,6
    if(timing==5)cycle
    do mode=1,3
      do layout=1,2
        call configure_column(columns(1),templates(1))
        call configure_physical_parameters(parameters(1),initial_state,conductivity0)
        call configure_control_forcing(base,conductivity0)
        call configure_transaction(config)
        theta0=initial_state%water_content(1)
        sensor=scheduled_irrigation_parameters_t()
        sensor%scheduled_irrigation_enabled=.true.
        sensor%active_nodes=numnod
        sensor%sensor_node=1
        sensor%single_ssdi_node=3
        sensor%timing_criterion=timing
        sensor%irr_rate_cm_per_day=expected_rate
        sensor%tcs7_knot_count=2; sensor%tcs7_dvs(1:2)=[0.0_real64,2.0_real64]
        sensor%tcs7_pressure_head(1:2)=-50.0_real64
        sensor%tcs8_knot_count=2; sensor%tcs8_dvs(1:2)=[0.0_real64,2.0_real64]
        sensor%tcs8_water_content(1:2)=theta0+0.01_real64
        nodes=1
        if(layout==2)then
          sensor%ssdi_first_node=2; sensor%ssdi_last_node=4; nodes=3
          initial_irrigation_derivative(2)=initial_irrigation_derivative(3)*dz(3)/dz(2)
          initial_irrigation_derivative(4)=initial_irrigation_derivative(3)*dz(3)/dz(4)
        end if
        initial_salt=sum(initial_state%salt%mass_mg_cm2)
        call fmr_new_b110_committed_state(physical,columns(1)%column_id,initial_state,t0-expected_duration,ok)
        call require(ok,'physical initialization')
        prelude(1)=physical
        call reset_legacy_globals()
        call fmr_run_serialized_physical_multiswap(columns,templates,parameters,[base],prelude,config,top_provider, &
             t0-expected_duration,t0,1,prelude_result,prelude_diag,prelude_aggregate,dispatch,runtime,base_salt_temporal_policy=salt_policy)
        call require(dispatch==FMR_SERIAL_DISPATCH_OK.and.prelude_result(1)%completed,'accepted zero-source prelude')
        physical=prelude(1)
        call require(physical%current_revision()>0_int64,'accepted salt/water provenance')
        call physical%snapshot(salt_snapshot,ok)
        call require(ok,'accepted salt snapshot')
        select type(ps=>salt_snapshot)
        class is(fmr_b110_physical_state_t)
          field_deficit=(theta0+.03_real64-ps%water_content(1))*dz(1)*.5_real64
        end select
        call fmr_read_committed_irrigation_cml(physical,parameters(1),0,t0,derived_cml,salt_revision,ok)
        call require(.not.ok,'invalid concentration node rejected')
        call fmr_read_committed_irrigation_cml(physical,parameters(1),1,t0-1.0_real64,derived_cml,salt_revision,ok)
        call require(.not.ok,'stale accepted-time concentration rejected')
        root=irrigation_root_zone_parameters_t()
        root%active_nodes=numnod; root%rooted_nodes=1; root%last_rooted_fraction=0.5_real64
        allocate(root%node_thickness_cm(numnod),root%field_capacity_water_content(numnod), &
             root%stress_water_content(numnod),root%wilting_water_content(numnod))
        root%node_thickness_cm=dz
        root%field_capacity_water_content=theta0+0.03_real64
        root%stress_water_content=theta0+0.01_real64
        root%wilting_water_content=theta0-0.05_real64
        depth=irrigation_management_policy_parameters_t()
        depth%depth_criterion=2; depth%dcs2_knot_count=2
        depth%dcs2_dvs(1:2)=[0.0_real64,2.0_real64];depth%dcs2_depth_cm(1:2)=expected_depth
        if(mode>=2)then
          depth%depth_criterion=1;depth%dcs1_knot_count=2;depth%dcs1_dvs(1:2)=[0.0_real64,2.0_real64]
          depth%dcs1_adjustment_mm(1:2)=10.0_real64*(expected_depth-field_deficit+0.02_real64)
          depth%rainfall_threshold_cm=0.01_real64
        end if
        duration=expected_duration
        if(mode==3)then
          depth%dcs1_adjustment_mm(1:2)=0.0_real64
          depth%depth_limit_enabled=.true.;depth%minimum_depth_cm=expected_depth;depth%maximum_depth_cm=expected_depth
          sensor%salinity_excess_enabled=.true.;sensor%salinity_threshold=1.0_real64;sensor%salinity_excess_percent=25.0_real64
          duration=duration*1.25_real64*0.5_real64
        end if
        request=scheduled_irrigation_request_t()
        request%t0=t0;request%t1=t0+duration*0.5_real64;mid=request%t1
        request%dvs=1.0_real64;request%selection_opportunity=.true.;request%irrigation_enabled=.true.
        request%schedule_enabled=.true.;request%crop_emerged=.true.;request%irrigation_window_open=.true.
        request%solute_enabled=.false.;request%sensor_concentration=-99.0_real64
        if(mode==3)then
          request%availability_scaling_enabled=.true.;request%availability_fraction=0.5_real64
        end if
        root_irrigation=fmr_irrigation_management_parameters_t()
        root_irrigation%root_zone=root;root_irrigation%policy=depth
        root_irrigation%active_nodes=numnod;root_irrigation%application_type=IRRIGATION_APPLICATION_SSDI
        root_irrigation%single_ssdi_node=sensor%single_ssdi_node
        root_irrigation%ssdi_first_node=sensor%ssdi_first_node;root_irrigation%ssdi_last_node=sensor%ssdi_last_node
        root_irrigation%rate_cm_per_day=expected_rate
        root_irrigation%salinity_excess_enabled=sensor%salinity_excess_enabled
        root_irrigation%salinity_threshold=sensor%salinity_threshold;root_irrigation%salinity_excess_percent=sensor%salinity_excess_percent
        root_irrigation%policy%timing_criterion=timing
        root_irrigation%policy%tcs2_knot_count=2;root_irrigation%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
        root_irrigation%policy%tcs2_fraction(1:2)=.1_real64
        root_irrigation%policy%tcs3_knot_count=2;root_irrigation%policy%tcs3_dvs(1:2)=[0.0_real64,2.0_real64]
        root_irrigation%policy%tcs3_fraction(1:2)=.1_real64
        root_irrigation%policy%tcs4_knot_count=2;root_irrigation%policy%tcs4_dvs(1:2)=[0.0_real64,2.0_real64]
        root_irrigation%policy%tcs4_depletion_mm(1:2)=.01_real64;root_irrigation%policy%tcs6_threshold_mm=.01_real64
        management=fmr_allocated_irrigation_state_t();management%management%policy%weekly_day_counter=6
        delivery%source_id=41_int64;delivery%revision=7_int64
        delivery%valid_t0=t0;delivery%valid_t1=t1;delivery%fraction=1.0_real64
        if(mode==3)delivery%fraction=.5_real64
        before_reject=physical
        rejected_config=config;rejected_config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
        call reset_legacy_globals()
        call run_root_binding(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
             0.02_real64,management,request,rejected_config,salt_policy,top_provider,result,runtime,binding,selected,salt_diag,accepted)
        call require(.not.accepted.and.physical%current_revision()==before_reject%current_revision().and.committed_physics_identical(physical,before_reject).and..not.management%management%event%active_event,'atomic reject')
        call reset_legacy_globals()
        call run_root_binding(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
             0.02_real64,management,request,config,salt_policy,top_provider,result,runtime,binding,selected,salt_diag,accepted)
        if(.not.accepted)write(*,*)'SENSOR_DIAGNOSTIC',timing,mode,layout,binding%status,result%kernel_status,result%temporal_rejections
        call require(accepted.and.management%management%event%active_event,'accepted half event')
        call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'first physical mass')
        total_in=result%mass%total_in
        call fmr_export_committed_restart(columns,templates,[physical],72001_int64,bundle,exported,status)
        call require(exported,'physical restart export')
        management_wrapper=management
        call fmr_export_allocated_irrigation_restart(management_wrapper,management_record,status)
        call require(status==FMR_IRR_ALLOCATION_OK,'management export')
        call fmr_restore_allocated_irrigation_restart(management_record,restored_wrapper,status)
        call require(status==FMR_IRR_ALLOCATION_OK,'management restore')
        resumed_management=restored_wrapper
        block
          type(kernel_committed_state_t) :: fresh(1)
          resumed=fresh
        end block
        call fmr_restore_committed_restart(bundle,72001_int64,columns,templates,resumed,ok,status)
        call require(ok.and.resumed(1)%current_revision()==physical%current_revision(),'physical restore provenance')
        call require(committed_physics_identical(physical,resumed(1)),'restored physical identity')
        call require(management%receipt%present.and.management%receipt%allocation%source_id==41_int64,'selected provider identity')
        call require(restored_wrapper%receipt%allocation%revision==7_int64,'restored provider revision')
        delivery%source_id=99_int64;delivery%revision=88_int64
        delivery%fraction=0.0_real64;delivery%valid_t0=t0-2.0_real64;delivery%valid_t1=t0-1.0_real64
        request%t0=mid;request%t1=t0+duration;request%selection_opportunity=.false.
        ! Depth inputs can change after selection; in-flight rate/end is retained.
        root%rooted_nodes=0;depth%dcs1_knot_count=0
        call reset_legacy_globals()
        call run_root_binding(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
             99.0_real64,management,request,config,salt_policy,top_provider,result,runtime,binding,selected,salt_diag,accepted)
        call require(accepted.and..not.management%management%event%active_event,'live event completes')
        call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'second physical mass')
        total_in=total_in+result%mass%total_in
        call reset_legacy_globals()
        call run_root_binding(columns(1),templates(1),parameters(1),base,resumed(1),sensor,root,depth, &
             99.0_real64,resumed_management,request,config,salt_policy,top_provider,result_resumed,runtime,binding,selected,salt_diag,accepted)
        call require(accepted,'resumed event completes')
        call require(resumed_management%receipt%allocation%source_id==41_int64,'in-flight provider never reselected')
        call require(committed_physics_identical(physical,resumed(1)),'restart hydraulic identity')
        call require(result%mass%total_in==result_resumed%mass%total_in.and.result%mass%total_out==result_resumed%mass%total_out,'restart mass identity')
        call require(physical%current_revision()==resumed(1)%current_revision(),'restart revision identity')
        call physical%snapshot(salt_snapshot,ok)
        call require(ok,'salt ledger accepted snapshot')
        select type(ps=>salt_snapshot)
        class is(fmr_b110_physical_state_t)
          current_salt=sum(ps%salt%mass_mg_cm2)
          call require(ps%salt%mass_mg_cm2(3)/(ps%water_content(3)*dz(3))<2.0_real64,'actual SSDI dilution')
        end select
        call require(abs(current_salt-initial_salt)<=256.0_real64*epsilon(1.0_real64)*initial_salt,'closed physical salt inventory')
        ! Closed top/bottom water and salt boundaries isolate the SSDI source.
        ! subtract its two-interval authoritative inflow to isolate SSDI.
        call require(abs(total_in-real(nodes,real64)*expected_rate*duration)<=128.0_real64*epsilon(1.0_real64),'nodal source total')
        if(timing==2.and.mode==1)then
          ! A later event must acquire a fresh provider record; a stale one
          ! cannot consume either committed physics or the previous receipt.
          request%t0=t0+duration;request%t1=request%t0+expected_duration*.25_real64
          request%selection_opportunity=.true.
          before_reject=physical
          call reset_legacy_globals()
          call run_root_binding(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
               0.02_real64,management,request,config,salt_policy,top_provider,result,runtime,binding,selected,salt_diag,accepted)
          call require(.not.accepted.and.committed_physics_identical(physical,before_reject),'stale next delivery rollback')
          call require(management%receipt%allocation%source_id==41_int64,'failed selection retains prior receipt')
          delivery%source_id=42_int64;delivery%revision=8_int64;delivery%fraction=.25_real64
          delivery%valid_t0=request%t0;delivery%valid_t1=request%t1+1.0_real64
          call reset_legacy_globals()
          call run_root_binding(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
               0.02_real64,management,request,config,salt_policy,top_provider,result,runtime,binding,selected,salt_diag,accepted)
          call require(accepted.and..not.management%management%event%active_event,'fresh next event accepted')
          call require(management%receipt%allocation%source_id==42_int64,'next event takes fresh provider')
          call require(abs(result%mass%total_in-real(nodes,real64)*.25_real64)<=hard_mass_gate,'fresh fraction source mass')
        end if
        write(*,'(A,3I3,A,ES24.16)')'MC_IRR01_SENSOR_DEPTH_CASE=',timing,mode,layout,' SSDI=',real(nodes,real64)*expected_rate*duration
      end do
    end do
  end do
  print '(A)','MC_IRR01_ALLOCATED_ROOT_PHYSICAL_EVENT_RESTART=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS'
  print '(A)','MC_IRR01_SENSOR_DCS1_LIMIT_SALT_AVAIL_RESTART=PASS'
contains

  subroutine run_root_binding(column,template,params,forcing,state,ignored_sensor,ignored_root,ignored_depth,rain, &
       mgmt,req,cfg,policy,top,res,rt,bind,depth_result,sd,accept)
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),intent(in)::params
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(kernel_committed_state_t),intent(inout)::state
    type(scheduled_irrigation_parameters_t),intent(in)::ignored_sensor
    type(irrigation_root_zone_parameters_t),intent(in)::ignored_root
    type(irrigation_management_policy_parameters_t),intent(in)::ignored_depth
    real(real64),intent(in)::rain
    type(fmr_allocated_irrigation_state_t),intent(inout)::mgmt
    type(scheduled_irrigation_request_t),intent(in)::req
    type(canonical_numerical_config_t),intent(in)::cfg
    type(fmr_base_salt_temporal_policy_t),intent(in)::policy
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top
    type(fmr_serialized_column_result_t),intent(out)::res
    type(fmr_serialized_batch_diagnostics_t),intent(out)::rt
    type(fmr_irrigation_forcing_binding_diagnostics_t),intent(out)::bind
    type(irrigation_management_policy_result_t),intent(out)::depth_result
    type(fmr_accepted_salt_irrigation_diagnostics_t),intent(out)::sd
    logical,intent(out)::accept
    type(fmr_irrigation_management_request_t)::rr
    rr%t0=req%t0;rr%t1=req%t1;rr%dvs=req%dvs;rr%rainfall_cm=rain
    rr%selection_opportunity=req%selection_opportunity;rr%irrigation_enabled=req%irrigation_enabled
    rr%schedule_enabled=req%schedule_enabled;rr%crop_emerged=req%crop_emerged
    rr%irrigation_window_open=req%irrigation_window_open
    rr%availability_scaling_enabled=req%availability_scaling_enabled;rr%availability_fraction=req%availability_fraction
    rr%solute_enabled=req%solute_enabled;rr%sensor_concentration=req%sensor_concentration
    call fmr_run_allocated_root_irrigation(column,template,params,forcing,state,root_irrigation,1,mgmt,rr,delivery,cfg, &
         policy,top,res,rt,root_binding,accept)
    sd=fmr_accepted_salt_irrigation_diagnostics_t()
    bind=fmr_irrigation_forcing_binding_diagnostics_t();bind%status=root_binding%status
    depth_result=irrigation_management_policy_result_t()
  end subroutine

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 720_int64
    template%physics_topology_id = 72001_int64
    template%vertical_layout_id = 72002_int64
    template%state_layout_id = 72003_int64
    template%solver_interface_id = 72004_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 720001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_physical_parameters(p,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 72001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%max_iterations=80; p%max_backtracking=20; p%min_step_duration=1.0e-13_real64
    p%bottom_mode=2; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.

    call initialize_b110_default_mvg_parameters(hyd_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads = head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0 = conductivity(1)
    ! Source-bound initial RIGHT derivative for the test's irrigation forcing.
    ! Uniform heads and equal prescribed boundary fluxes cancel matrix flux;
    ! the only remaining rate is qssdi/(C*dz) at compartment 3.
    initial_irrigation_derivative = 0.0_real64
    initial_irrigation_derivative(3) = expected_rate/(capacity(3)*p%dz(3))
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    call fmr_initialize_mobile_salt_profile(state,p%dz,[2.0_real64,2.0_real64,2.0_real64,2.0_real64],status)
    call require(status==0,'existing salt profile initializer')
  end subroutine configure_physical_parameters

  subroutine configure_control_forcing(f,conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    f%top_flux = 0.0_real64
    f%top_head = head0
    f%bottom_flux = 0.0_real64
    f%bottom_head = -100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
    allocate(f%c_drain_salt,f%soil_salt_boundary)
    f%c_drain_salt%available=.true.;f%c_drain_salt%source_id=1_int64;f%c_drain_salt%revision=0_int64
    f%c_drain_salt%unit_id=1;f%c_drain_salt%valid_t0=t0-expected_duration;f%c_drain_salt%valid_t1=t0+2*expected_duration
    f%c_drain_salt%concentration_mg_cm3=2.0_real64
    f%soil_salt_boundary%available=.true.;f%soil_salt_boundary%source_id=1_int64;f%soil_salt_boundary%revision=0_int64
    f%soil_salt_boundary%unit_id=1;f%soil_salt_boundary%valid_t0=t0-expected_duration
    f%soil_salt_boundary%valid_t1=t0+2*expected_duration
    f%soil_salt_boundary%matrix_top_mg_cm3=2.0_real64;f%soil_salt_boundary%matrix_bottom_mg_cm3=2.0_real64
  end subroutine configure_control_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    ! Existing F-KT history certificate, strict source-bound head budget.
    cfg%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance = 1.0_real64
    cfg%model_temporal_indicator_budget_available = .false.
    cfg%model_temporal_indicator_budget = 1.0e-6_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 40
    cfg%max_committed_substeps = 500000
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    legacy_melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function committed_physics_identical(a,b)
    type(kernel_committed_state_t), intent(in) :: a,b
    class(transaction_state_t), allocatable :: sa,sb
    logical :: oka,okb
    integer :: i
    committed_physics_identical = .false.
    call a%snapshot(sa,oka)
    call b%snapshot(sb,okb)
    if (.not. oka .or. .not. okb) return
    select type (pa=>sa)
    class is (fmr_b110_physical_state_t)
      select type (pb=>sb)
      class is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        if (size(pa%pressure_head) /= size(pb%pressure_head) .or. size(pa%water_content) /= size(pb%water_content)) return
        do i=1,pa%active_nodes
          if (.not. same_bits(pa%pressure_head(i),pb%pressure_head(i))) return
          if (.not. same_bits(pa%water_content(i),pb%water_content(i))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        if (.not.allocated(pa%salt).or..not.allocated(pb%salt)) return
        if (any(pa%salt%mass_mg_cm2/=pb%salt%mass_mg_cm2)) return
        committed_physics_identical = .true.
      end select
    end select
  end function committed_physics_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ20_SCHEDULED_RUNTIME_MASS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program
