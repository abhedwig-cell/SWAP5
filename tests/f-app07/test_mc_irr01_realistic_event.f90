program test_mc_irr01_realistic_event
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
  type(fmr_b110_physical_forcing_t) :: forcing_control(1), forcing_irrigation(1)
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: states_control(1), states_irrigation(1)
  type(fmr_serialized_column_result_t), allocatable :: result_control(:), result_irrigation(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_control(:), diag_irrigation(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_control, aggregate_irrigation
  type(fmr_serialized_batch_diagnostics_t) :: run_control, run_irrigation
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config, rejected_config
  type(fmr_management_forcing_binding_diagnostics_t) :: irrigation_binding_diag
  type(fmr_irrigation_management_parameters_t) :: irrigation_parameters
  type(fmr_irrigation_management_request_t) :: irrigation_request, crossing_request
  type(fmr_irrigation_management_state_t) :: irrigation_committed, irrigation_candidate, restored
  type(fmr_irrigation_management_restart_record_t) :: restart
  type(fmr_serialized_column_result_t) :: managed_result
  integer :: criterion, mode, rst_status
  integer(int64) :: pre_revision
  character(len=64) :: budget_arg, scope_arg
  real(real64) :: temporal_budget
  class(transaction_state_t), allocatable :: final_snapshot
  real(real64) :: theta0
  real(real64) :: initial_irrigation_derivative(numnod)
  logical :: accepted
  type(fmr_serialized_reference_backend_t) :: debug_backend
  type(fmr_serialized_physical_observation_t) :: observation
  type(kernel_executor_t) :: debug_transaction
  type(fmr_column_diagnostics_t) :: debug_diag
  integer :: calls
  real(real64) :: conductivity0, total_in_delta, total_out_delta, tolerance
  integer :: dispatch_control, dispatch_irrigation
  logical :: ok

  call get_command_argument(1,budget_arg)
  read(budget_arg,*) temporal_budget
  call get_command_argument(2,scope_arg)
  do criterion = 2, 6
    if (trim(scope_arg) /= "cluster" .and. criterion /= 2) cycle
    if (criterion == 5) cycle
    do mode = 1, 3
      if (trim(scope_arg) /= "cluster" .and. mode /= 1) cycle
      call configure_physical_parameters(parameters(1), initial_state, conductivity0)
      call configure_column(columns(1), templates(1))
      call configure_transaction(config)
      call configure_control_forcing(forcing_control(1), conductivity0)
      call fmr_new_b110_temporal_indicator_committed_state(states_control(1), columns(1)%column_id, initial_state, t0, ok, &
           [0.0_real64,0.0_real64,0.0_real64,0.0_real64])
      call require(ok, 'control init')
      call fmr_new_b110_temporal_indicator_committed_state(states_irrigation(1), columns(1)%column_id, initial_state, t0-expected_duration, ok, &
           [0.0_real64,0.0_real64,0.0_real64,0.0_real64])
      call require(ok, 'irrigation init')
      call reset_legacy_globals()
      call fmr_run_serialized_physical_multiswap(columns,templates,parameters,forcing_control,states_irrigation,config, &
           top_provider,t0-expected_duration,t0,1,result_control,diag_control,aggregate_control,dispatch_control,run_control)
      if (.not.result_control(1)%completed) write(*,*) 'PRELUDE_DIAGNOSTIC=',dispatch_control, &
           result_control(1)%admission_status,result_control(1)%kernel_status,result_control(1)%solver_status, &
           result_control(1)%accepted_substeps,result_control(1)%temporal_rejections,result_control(1)%mass_rejections, &
           result_control(1)%solver_rejections
      call require(result_control(1)%completed .and. states_irrigation(1)%current_revision()>0_int64, 'accepted pre-event history')
      pre_revision=states_irrigation(1)%current_revision()
      theta0 = initial_state%water_content(1)
      irrigation_parameters = fmr_irrigation_management_parameters_t()
      irrigation_parameters%active_nodes = numnod
      irrigation_parameters%application_type = IRRIGATION_APPLICATION_SSDI
      irrigation_parameters%single_ssdi_node = 3
      irrigation_parameters%rate_cm_per_day = expected_rate
      irrigation_parameters%root_zone%active_nodes = numnod
      irrigation_parameters%root_zone%rooted_nodes = 1
      irrigation_parameters%root_zone%last_rooted_fraction = 0.5_real64
      allocate(irrigation_parameters%root_zone%node_thickness_cm(numnod), &
           irrigation_parameters%root_zone%field_capacity_water_content(numnod), &
           irrigation_parameters%root_zone%stress_water_content(numnod), &
           irrigation_parameters%root_zone%wilting_water_content(numnod))
      irrigation_parameters%root_zone%node_thickness_cm = parameters(1)%dz
      irrigation_parameters%root_zone%field_capacity_water_content = theta0 + 0.03_real64
      irrigation_parameters%root_zone%stress_water_content = theta0 + 0.01_real64
      irrigation_parameters%root_zone%wilting_water_content = theta0 - 0.05_real64
      irrigation_parameters%policy%timing_criterion = criterion
      irrigation_parameters%policy%tcs2_knot_count = 2
      irrigation_parameters%policy%tcs2_dvs(1:2) = [0.0_real64,2.0_real64]
      irrigation_parameters%policy%tcs2_fraction(1:2) = 0.1_real64
      irrigation_parameters%policy%tcs3_knot_count = 2
      irrigation_parameters%policy%tcs3_dvs(1:2) = [0.0_real64,2.0_real64]
      irrigation_parameters%policy%tcs3_fraction(1:2) = 0.1_real64
      irrigation_parameters%policy%tcs4_knot_count = 2
      irrigation_parameters%policy%tcs4_dvs(1:2) = [0.0_real64,2.0_real64]
      irrigation_parameters%policy%tcs4_depletion_mm(1:2) = 0.01_real64
      irrigation_parameters%policy%tcs6_threshold_mm = 0.01_real64
      irrigation_parameters%policy%depth_criterion = 2
      irrigation_parameters%policy%dcs2_knot_count = 2
      irrigation_parameters%policy%dcs2_dvs(1:2) = [0.0_real64,2.0_real64]
      irrigation_parameters%policy%dcs2_depth_cm(1:2) = expected_depth
      if (mode >= 2) then
        irrigation_parameters%policy%depth_criterion = 1
        irrigation_parameters%policy%dcs1_knot_count = 2
        irrigation_parameters%policy%dcs1_dvs(1:2) = [0.0_real64,2.0_real64]
        ! Literal DITAB mm: refill deficit + adjustment - rain = selected depth.
        irrigation_parameters%policy%dcs1_adjustment_mm(1:2) = &
             10.0_real64*(expected_depth - 0.03_real64*parameters(1)%dz(1)*0.5_real64 + 0.02_real64)
        irrigation_parameters%policy%rainfall_threshold_cm = 0.01_real64
      end if
      if (mode == 3) then
        irrigation_parameters%policy%depth_limit_enabled = .true.
        irrigation_parameters%policy%minimum_depth_cm = expected_depth
        irrigation_parameters%policy%maximum_depth_cm = expected_depth
        irrigation_parameters%policy%dcs1_adjustment_mm(1:2) = 0.0_real64
      end if
      irrigation_request = fmr_irrigation_management_request_t()
      irrigation_request%t0 = t0
      irrigation_request%t1 = t1
      irrigation_request%dvs = 1.0_real64
      irrigation_request%rainfall_cm = 0.02_real64
      irrigation_request%selection_opportunity = .true.
      irrigation_request%irrigation_enabled = .true.
      irrigation_request%schedule_enabled = .true.
      irrigation_request%crop_emerged = .true.
      irrigation_request%irrigation_window_open = .true.
      irrigation_committed = fmr_irrigation_management_state_t()
      irrigation_committed%policy%weekly_day_counter = 6

      ! Conflicting forcing must not consume the weekly opportunity or event.
      forcing_irrigation(1) = forcing_control(1)
      forcing_irrigation(1)%subsurface_irrigation_source(2) = tiny(1.0_real64)
      call fmr_prepare_management_ssdi_forcing(irrigation_parameters,irrigation_committed,irrigation_request, &
           states_irrigation(1),forcing_irrigation(1),irrigation_candidate,forcing_control(1),irrigation_binding_diag)
      call require(irrigation_binding_diag%status == FMR_MGMT_FORCING_BIND_SOURCE_CONFLICT, 'source conflict')
      call require(irrigation_candidate%policy%weekly_day_counter == 6, 'rejected policy unchanged')
      call configure_control_forcing(forcing_control(1),conductivity0)

      ! Event-end split is a rejected candidate, not a consumed weekly day.
      crossing_request = irrigation_request
      crossing_request%t1 = t1 + 0.1_real64
      call fmr_prepare_management_ssdi_forcing(irrigation_parameters,irrigation_committed,crossing_request, &
           states_irrigation(1),forcing_control(1),irrigation_candidate,forcing_irrigation(1),irrigation_binding_diag)
      call require(irrigation_binding_diag%split_required, 'explicit event-end split')
      call require(irrigation_candidate%policy%weekly_day_counter == 6 .and. &
           .not.irrigation_candidate%event%active_event, 'split does not consume management')
      ! Missing required temporal authority rejects actual physical execution;
      ! neither the live F-KT revision nor management state may be published.
      rejected_config = config
      rejected_config%model_temporal_indicator_budget_available = .false.
      call reset_legacy_globals()
      call fmr_run_management_ssdi_interval(columns(1),templates(1),parameters(1),forcing_control(1), &
           states_irrigation(1),irrigation_parameters,irrigation_committed,irrigation_request,rejected_config,top_provider, &
           managed_result,run_irrigation,irrigation_binding_diag,accepted)
      call require(.not.accepted .and. states_irrigation(1)%current_revision() == pre_revision, 'physical reject rollback')
      call require(irrigation_committed%policy%weekly_day_counter == 6 .and. &
           .not.irrigation_committed%event%active_event, 'physical reject keeps management')

      call reset_legacy_globals()
      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_control, states_control, config, &
           top_provider, t0, t1, 1, result_control, diag_control, aggregate_control, dispatch_control, run_control)
      if (.not. result_control(1)%completed) write(*,*) 'CONTROL_DIAGNOSTIC',dispatch_control, &
           result_control(1)%admission_status,result_control(1)%kernel_status,result_control(1)%solver_status, &
           result_control(1)%temporal_rejections,result_control(1)%mass_rejections
      call require(dispatch_control == FMR_SERIAL_DISPATCH_OK .and. result_control(1)%completed, 'control runtime')
      call reset_legacy_globals()
      call fmr_run_management_ssdi_interval(columns(1),templates(1),parameters(1),forcing_control(1), &
           states_irrigation(1),irrigation_parameters,irrigation_committed,irrigation_request,config,top_provider, &
           managed_result,run_irrigation,irrigation_binding_diag,accepted)
      if (.not. accepted) write(*,*) 'MANAGEMENT_DIAGNOSTIC',criterion,mode,irrigation_binding_diag%status, &
           irrigation_binding_diag%application_status,managed_result%admission_status,managed_result%kernel_status, &
           managed_result%solver_status,managed_result%temporal_rejections,managed_result%mass_rejections,managed_result%mass%residual
      if (.not.accepted) write(*,*) 'PROGRESS_DIAGNOSTIC accepted_steps, time, revision, requested_t1=', &
           managed_result%accepted_substeps,managed_result%final_committed_time,managed_result%final_revision,t1
      if (.not. accepted) then
        call fmr_prepare_management_ssdi_forcing(irrigation_parameters,irrigation_committed,irrigation_request, &
             states_irrigation(1),forcing_control(1),irrigation_candidate,forcing_irrigation(1),irrigation_binding_diag)
        call debug_backend%initialize(top_provider)
        calls=0
        call fmr_execute_serialized_resolved_physical_column(debug_backend,debug_transaction,columns(1),templates(1), &
             parameters(1),forcing_irrigation(1),states_irrigation(1),config,t0,t1,managed_result,debug_diag,run_irrigation,calls)
        observation=debug_backend%observation()
        write(*,*) 'CERTIFICATE_REASON=',observation%temporal_certificate_unavailable_reason, &
             ' ROUTE=',observation%temporal_indicator_route,' BOUND=',observation%temporal_head_inf_bound, &
             ' NORMALIZED=',observation%temporal_normalized_indicator
      end if
      call require(accepted .and. irrigation_binding_diag%source_bound, 'management physical commit')
      call require(.not. irrigation_committed%event%active_event, 'event completed')
      call require(managed_result%mass%complete .and. &
           managed_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'complete mass')
      call require(abs(managed_result%mass%residual) <= hard_mass_gate, 'real unbalanced irrigation mass')
      call require(.not. committed_physics_identical(states_control(1),states_irrigation(1)), 'irrigation changes physics')
      total_in_delta = managed_result%mass%total_in - result_control(1)%mass%total_in
      tolerance = 128.0_real64*epsilon(1.0_real64)
      call require(abs(total_in_delta-expected_depth) <= tolerance, 'selected depth counted exactly once')
      write(*,'(A,I0,A,I0,A,ES24.16)') 'MC_IRR01_PHYSICAL_TCS=',criterion,' MODE=',mode,' INFLOW=',total_in_delta
      call export_fmr_irrigation_management_restart(irrigation_committed,restart,rst_status)
      call require(rst_status == FMR_IRR_MGMT_RESTART_OK, 'restart export')
      call restore_fmr_irrigation_management_restart(restart,restored,rst_status)
      call require(rst_status == FMR_IRR_MGMT_RESTART_OK, 'restart restore')
      if (trim(scope_arg) == 'off') then
        ! A real second interval retains the accepted irrigation derivative and
        ! selects no new event. The solver must resolve the source discontinuity.
        irrigation_request%t0=t1
        irrigation_request%t1=t1+expected_duration
        irrigation_request%selection_opportunity=.false.
        pre_revision=states_irrigation(1)%current_revision()
        call reset_legacy_globals()
        call fmr_run_management_ssdi_interval(columns(1),templates(1),parameters(1),forcing_control(1), &
             states_irrigation(1),irrigation_parameters,irrigation_committed,irrigation_request,config,top_provider, &
             managed_result,run_irrigation,irrigation_binding_diag,accepted)
        if (.not.accepted) write(*,*) 'SOURCE_OFF_DIAGNOSTIC=',managed_result%kernel_status, &
             managed_result%solver_status,managed_result%temporal_rejections,managed_result%mass_rejections
        call require(accepted,'source-off real physical commit')
        call require(.not.irrigation_committed%event%active_event,'source-off no new event')
        call require(states_irrigation(1)%current_revision()>pre_revision,'source-off retained state advances')
        call require(managed_result%mass%complete .and. abs(managed_result%mass%residual)<=hard_mass_gate, &
             'source-off complete mass')
        call require(abs(managed_result%mass%total_in-abs(conductivity0)*expected_duration) <= &
             128.0_real64*epsilon(1.0_real64),'source-off no irrigation inflow')
        print '(A)', 'MC_IRR01_REALISTIC_SOURCE_OFF_RETAINED_HISTORY=PASS'
      end if
    end do
  end do
  call states_irrigation(1)%snapshot(final_snapshot,ok)
  call require(ok,'final snapshot')
  select type(p=>final_snapshot)
  class is(fmr_b110_physical_state_t)
    write(*,'(A,5ES25.16)') 'MC_IRR01_EVENT_HEAD=',temporal_budget,p%pressure_head
    write(*,'(A,5ES25.16)') 'MC_IRR01_EVENT_THETA=',temporal_budget,p%water_content
  end select
  print '(A)', 'MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS'
  print '(A)', 'MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS'
  print '(A)', 'MC_IRR01_MANAGEMENT_PHYSICAL_STATE_RESPONSE=PASS'
  print '(A)', 'MC_IRR01_MANAGEMENT_PHYSICAL_REJECTION_ROLLBACK=PASS'

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
    ! A 100-cm soil profile can store the 1-cm pulse. The historical
    ! 3-cm unit-test geometry could store only about 0.23 cm and had
    ! prescribed equal top/bottom fluxes, so full-dose completion was impossible.
    p%z = [-12.5_real64,-37.5_real64,-62.5_real64,-87.5_real64]
    p%dz = 25.0_real64
    p%node_distance = 25.0_real64
    p%node_distance(1)=12.5_real64
    call require(all(p%z==z) .and. all(p%dz==dz) .and. all(p%node_distance==disnod(1:numnod)), &
         'serialized geometry identity')
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
    write(*,'(A,3ES24.16)') 'MC_IRR01_STORAGE_PREFLIGHT=',sum(p%dz),sum((p%cofgen(2,:)-water)*p%dz),expected_depth
    call require(expected_depth < sum((p%cofgen(2,:)-water)*p%dz),'physical dose storage envelope')
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
    cfg%model_temporal_indicator_budget = temporal_budget
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

end program test_mc_irr01_realistic_event
