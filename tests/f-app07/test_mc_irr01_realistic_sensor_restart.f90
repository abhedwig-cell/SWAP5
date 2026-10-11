program test_mc_irr01_realistic_sensor_restart
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
  use mod_fmr_sensor_depth_irrigation_binding, only: fmr_run_sensor_depth_ssdi_interval
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
  type(irrigation_state_t) :: management,resumed_management
  type(fmr_irrigation_management_state_t) :: management_wrapper,restored_wrapper
  type(fmr_irrigation_management_restart_record_t) :: management_record
  type(fmr_committed_restart_bundle_t) :: bundle
  type(fmr_serialized_column_result_t) :: result,result_resumed
  type(fmr_serialized_batch_diagnostics_t) :: runtime
  real(real64) :: conductivity0,theta0,initial_irrigation_derivative(numnod),duration,mid,total_in
  integer :: timing,mode,layout,status,nodes,dispatch
  type(kernel_committed_state_t) :: prelude(1), before_reject
  type(fmr_serialized_column_result_t),allocatable :: prelude_result(:)
  type(fmr_column_diagnostics_t),allocatable :: prelude_diag(:)
  type(fmr_aggregate_diagnostics_t) :: prelude_aggregate
  logical :: ok,accepted,exported
  do timing=7,8
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
        call fmr_new_b110_temporal_indicator_committed_state(physical,columns(1)%column_id,initial_state, &
             t0-expected_duration,ok,[0.0_real64,0.0_real64,0.0_real64,0.0_real64])
        call require(ok,'physical initialization')
        prelude(1)=physical
        call reset_legacy_globals()
        call fmr_run_serialized_physical_multiswap(columns,templates,parameters,[base],prelude,config,top_provider, &
             t0-expected_duration,t0,1,prelude_result,prelude_diag,prelude_aggregate,dispatch,runtime)
        call require(dispatch==FMR_SERIAL_DISPATCH_OK.and.prelude_result(1)%completed,'accepted zero-source prelude')
        physical=prelude(1)
        call require(physical%current_revision()>0_int64,'retained accepted history provenance')
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
          depth%dcs1_adjustment_mm(1:2)=10.0_real64*(expected_depth-0.03_real64*dz(1)*0.5_real64+0.02_real64)
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
        request%solute_enabled=.true.;request%sensor_concentration=2.0_real64
        if(mode==3)then
          request%availability_scaling_enabled=.true.;request%availability_fraction=0.5_real64
        end if
        management=irrigation_state_t()
        before_reject=physical
        rejected_config=config;rejected_config%model_temporal_indicator_budget_available=.false.
        call reset_legacy_globals()
        call fmr_run_sensor_depth_ssdi_interval(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
             0.02_real64,management,request,rejected_config,top_provider,result,runtime,binding,selected,accepted)
        call require(.not.accepted.and.physical%current_revision()==before_reject%current_revision().and.committed_physics_identical(physical,before_reject).and..not.management%active_event,'atomic reject')
        call reset_legacy_globals()
        call fmr_run_sensor_depth_ssdi_interval(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
             0.02_real64,management,request,config,top_provider,result,runtime,binding,selected,accepted)
        if(.not.accepted)write(*,*)'SENSOR_DIAGNOSTIC',timing,mode,layout,binding%status,result%kernel_status,result%temporal_rejections
        call require(accepted.and.management%active_event,'accepted half event')
        call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'first physical mass')
        total_in=result%mass%total_in
        call fmr_export_committed_restart(columns,templates,[physical],72001_int64,bundle,exported,status)
        call require(exported,'physical restart export')
        management_wrapper%event=management
        call export_fmr_irrigation_management_restart(management_wrapper,management_record,status)
        call require(status==FMR_IRR_MGMT_RESTART_OK,'management export')
        call restore_fmr_irrigation_management_restart(management_record,restored_wrapper,status)
        call require(status==FMR_IRR_MGMT_RESTART_OK,'management restore')
        resumed_management=restored_wrapper%event
        block
          type(kernel_committed_state_t) :: fresh(1)
          resumed=fresh
        end block
        call fmr_restore_committed_restart(bundle,72001_int64,columns,templates,resumed,ok,status)
        call require(ok.and.resumed(1)%current_revision()==physical%current_revision(),'physical restore provenance')
        call require(committed_physics_identical(physical,resumed(1)),'restored physical identity')
        request%t0=mid;request%t1=t0+duration;request%selection_opportunity=.false.
        ! Depth inputs can change after selection; in-flight rate/end is retained.
        root%rooted_nodes=0;depth%dcs1_knot_count=0
        call reset_legacy_globals()
        call fmr_run_sensor_depth_ssdi_interval(columns(1),templates(1),parameters(1),base,physical,sensor,root,depth, &
             99.0_real64,management,request,config,top_provider,result,runtime,binding,selected,accepted)
        call require(accepted.and..not.management%active_event,'live event completes')
        call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'second physical mass')
        total_in=total_in+result%mass%total_in
        call reset_legacy_globals()
        call fmr_run_sensor_depth_ssdi_interval(columns(1),templates(1),parameters(1),base,resumed(1),sensor,root,depth, &
             99.0_real64,resumed_management,request,config,top_provider,result_resumed,runtime,binding,selected,accepted)
        call require(accepted,'resumed event completes')
        call require(committed_physics_identical(physical,resumed(1)),'restart hydraulic identity')
        call require(result%mass%total_in==result_resumed%mass%total_in.and.result%mass%total_out==result_resumed%mass%total_out,'restart mass identity')
        call require(physical%current_revision()==resumed(1)%current_revision(),'restart revision identity')
        ! Stationary matched top/bottom matrix flux is included in mass total;
        ! subtract its two-interval authoritative inflow to isolate SSDI.
        call require(abs(total_in-abs(conductivity0)*duration-real(nodes,real64)*expected_rate*duration)<=128.0_real64*epsilon(1.0_real64),'nodal source total')
        write(*,'(A,3I3,A,ES24.16)')'MC_IRR01_SENSOR_DEPTH_CASE=',timing,mode,layout,' SSDI=',real(nodes,real64)*expected_rate*duration
      end do
    end do
  end do
  print '(A)','MC_IRR01_REALISTIC_SENSOR_RETAINED_HISTORY_RESTART=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS'
  print '(A)','MC_IRR01_SENSOR_DCS1_LIMIT_SALT_AVAIL_RESTART=PASS'
contains

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 720_int64
    template%physics_topology_id = 72001_int64
    template%vertical_layout_id = 72002_int64
    template%state_layout_id = 72003_int64
    template%solver_interface_id = 72004_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
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
  end subroutine configure_physical_parameters

  subroutine configure_control_forcing(f,conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    f%top_flux = -conductivity0
    f%top_head = head0
    f%bottom_flux = -conductivity0
    f%bottom_head = -100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine configure_control_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    ! Existing F-KT history certificate, strict source-bound head budget.
    cfg%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .true.
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
