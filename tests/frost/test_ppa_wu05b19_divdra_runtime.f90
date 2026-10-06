program test_frost_divdra_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_temperature_contract, only: initialize_soil_temperature_state
  use mod_restricted_soil_temperature, only: initialize_soil_temperature_parameters
  use mod_soil_temperature_contract, only: copy_soil_temperature_profile
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_fmr_committed_restart, only: fmr_restart_template_identity_matches
  use mod_fmr_production_application_bootstrap
  use mod_frost_hydraulic_effect, only: frost_hydraulic_parameters_t, evaluate_frost_hydraulic_factor
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  implicit none
  real(real64),parameter::h0=-75._real64,equilibrium_dt=.25_real64,upward_dt=1.e-4_real64
  real(real64),parameter::hard_mass_gate=1.e-12_real64,qualification_head_budget=2.5e-11_real64
  integer(int64),parameter::column_id=440044_int64
  type(fmr_b110_physical_parameters_t)::parameters
  type(fmr_b110_physical_state_t)::initial,final,replay,direct,next
  type(fmr_serialized_column_result_t)::result,again
  type(fmr_serialized_physical_observation_t)::observation
  type(kernel_committed_state_t)::captured,registry(1),restored(1)
  type(fmr_logical_column_t)::columns(1)
  type(fmr_template_t)::templates(1)
  type(fmr_committed_restart_bundle_t)::bundle
  real(real64),allocatable::tf(:),td(:)
  real(real64)::raw_scalar,q,drain_bottom,dt,head_diff,temp_diff,integrated_net,max_h,max_t
  integer::family,pattern,bsign,i,status,fine_steps,patterns
  logical::low_route,ok
  character(len=32)::arg
  call get_command_argument(1,arg);read(arg,*,iostat=status)family
  call require(status==0.and.family>=1.and.family<=6,'bounded family selector')
  call get_command_argument(2,arg);call require(trim(arg)=='normal'.or.trim(arg)=='low','bounded route selector')
  low_route=trim(arg)=='low';raw_scalar=real(mod(family-1,3)-1,real64)*.01_real64
  fine_steps=merge(65536,8192,low_route);patterns=merge(3,1,low_route)
  call get_command_argument(3,arg)
  ! A smoke invocation executes primary adaptive calls only; it never qualifies the reference comparison.
  if(trim(arg)=='smoke')fine_steps=0
  max_h=0._real64;max_t=0._real64
  do pattern=1,patterns
    drain_bottom=-2._real64
    if(low_route.and.pattern==1)drain_bottom=-1._real64
    if(low_route.and.pattern==2)drain_bottom=-1.25_real64
    call initialize_parameters(parameters,2);call enable_bounded_frost(parameters);call configure_divdra(parameters)
    call initialize_physical_state(parameters,.true.,initial,-.7_real64)
    initial%groundwater_level=-.75_real64
    if(low_route)then
      call initialize_soil_temperature_state([-4._real64,-4._real64,-1._real64,1._real64],initial%soil_temperature,status)
      call require(status==0,'mixed frozen trial start')
      block
        type(b110_default_mvg_parameters_t),target::hp
        type(b110_default_mvg_provider_t)::provider
        real(real64)::w(4),k(4),c(4),dk(4)
        call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
        call bind_b110_default_mvg_provider(provider,hp,upward_dt)
        initial%pressure_head=-5._real64
        call provider%evaluate(initial%pressure_head,w,k,c,dk);initial%water_content=w
      end block
    end if
    do bsign=-1,1,2
      q=real(bsign,real64)*.001_real64
      call execute_case(2,0._real64,q,-999999._real64,upward_dt,.false.,.true.,result,observation, &
           frost_case=.true.,initial_physical_state=initial,final_physical_state=final,captured=captured)
      if(.not.result%committed)print *, 'B19_DEBUG',family,pattern,bsign,result%accepted_substeps,result%temporal_rejections, &
           observation%solver_executed,observation%frost_divdra_executed,observation%frost_divdra%status,result%mass%residual
      call require(result%completed.and.result%committed,'primary physical trajectory commits')
      call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'hard accepted mass closure')
      call require(observation%frost_divdra_executed.and.observation%frost_divdra%available,'typed proposal executed')
      call require(observation%frost_divdra%low_air.eqv.low_route,'physical air branch')
      call require(abs(sum(observation%frost_divdra%final_nodal_sink)-observation%frost_divdra%final_scalar)<=1.e-14_real64,'one nodal scalar owner')
      call require(observation%bottom_flux==observation%frost_divdra%final_bottom,'one separate bottom owner')
      print '(A,I0,A,L1,A,I0,A,I0,A,I0,A,I0,A,ES24.16,A,ES24.16)', &
           'B19_PRIMARY family=',family,' low=',low_route,' depth=',pattern,' bottom=',bsign, &
           ' substeps=',result%accepted_substeps,' rejects=',result%temporal_rejections, &
           ' scalar=',observation%frost_divdra%final_scalar,' mass=',result%mass%residual
      call execute_case(2,0._real64,q,-999999._real64,upward_dt,.false.,.true.,again,observation, &
           frost_case=.true.,initial_physical_state=initial,final_physical_state=replay)
      call require(again%committed.and.all(final%pressure_head==replay%pressure_head).and. &
           all(final%water_content==replay%water_content),'fresh worker physical identity')
      call require(result%mass%total_in==again%mass%total_in.and.result%mass%total_out==again%mass%total_out,'replay mass identity')
      if(fine_steps==0)cycle
      direct=initial;dt=upward_dt/real(fine_steps,real64);integrated_net=0._real64
      do i=1,fine_steps
        call execute_case(2,0._real64,q,-999999._real64,dt,.false.,.true.,again,observation, &
             frost_case=.true.,initial_physical_state=direct,final_physical_state=next,start_time=real(i-1,real64)*dt)
        call require(again%committed,'independent fine continuation')
        call require(abs(again%mass%storage_change-(observation%bottom_flux-observation%frost_divdra%final_scalar)*dt)<=hard_mass_gate, &
             'independent physical nodal and bottom storage owner')
        integrated_net=integrated_net+(observation%bottom_flux-observation%frost_divdra%final_scalar)*dt
        direct=next
      end do
      call copy_soil_temperature_profile(final%soil_temperature,tf,status);call require(status==0,'adaptive temperature')
      call copy_soil_temperature_profile(direct%soil_temperature,td,status);call require(status==0,'fine temperature')
      head_diff=maxval(abs(final%pressure_head-direct%pressure_head));temp_diff=maxval(abs(tf-td))
      max_h=max(max_h,head_diff);max_t=max(max_t,temp_diff)
      print '(A,I0,A,ES24.16,A,ES24.16)','B19_FINE steps=',fine_steps,' head_cm=',head_diff,' temperature_c=',temp_diff
      call require(head_diff<=1.e-6_real64.and.temp_diff<=1.e-4_real64,'unchanged reference envelope')
      call require(abs(result%mass%storage_change-integrated_net)<=1.e-10_real64,'independent cumulative physical owner')
    end do
  end do
  columns(1)%column_id=column_id;columns(1)%template_id=440001_int64
  columns(1)%parameter_ref=1_int64;columns(1)%state_handle=1_int64;columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  templates(1)%template_id=440001_int64;templates(1)%physics_topology_id=440002_int64
  templates(1)%vertical_layout_id=440003_int64;templates(1)%state_layout_id=440004_int64
  templates(1)%solver_interface_id=440005_int64
  templates(1)%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  templates(1)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  registry(1)=captured
  call fmr_export_committed_restart(columns,templates,registry,parameters%parameter_set_id,bundle,ok,status)
  call require(ok.and.status==FMR_RESTART_OK,'accepted physical restart export')
  restored=kernel_committed_state_t()
  call fmr_restore_committed_restart(bundle,parameters%parameter_set_id,columns,templates,restored,ok,status)
  call require(ok.and.status==FMR_RESTART_OK,'empty registry restart restore')
  call execute_case(2,0._real64,q,-999999._real64,upward_dt,.false.,.true.,result,observation, &
       frost_case=.true.,start_time=upward_dt,resumed=captured,final_physical_state=final)
  call execute_case(2,0._real64,q,-999999._real64,upward_dt,.false.,.true.,again,observation, &
       frost_case=.true.,start_time=upward_dt,resumed=restored(1),final_physical_state=replay)
  call require(result%committed.and.again%committed.and.all(final%pressure_head==replay%pressure_head), &
       'restored physical continuation bit identity')
  call require(result%mass%storage_change==again%mass%storage_change,'restored accepted mass identity')
  print '(A,I0,A,L1,A,ES24.16,A,ES24.16)','B19_RUNTIME_PASS family=',family,' low=',low_route,' max_head=',max_h,' max_temperature=',max_t
contains
  subroutine configure_divdra(p)
    type(fmr_b110_physical_parameters_t),intent(inout)::p
    integer::i
    p%frost_drainage%active=.true.;p%frost_drainage%head_budget_cm=3.e-11_real64
    p%frost_drainage%temperature_budget_c=1.e-7_real64;p%frost_divdra_drainage_active=.true.
    p%frost_divdra_drainage%distribution%active_nodes=numnod
    p%frost_divdra_drainage%distribution%dz=p%dz
    allocate(p%frost_divdra_drainage%distribution%zbotcp(numnod))
    do i=1,numnod
      p%frost_divdra_drainage%distribution%zbotcp(i)=-sum(p%dz(:i))
    end do
    p%frost_divdra_drainage%distribution%saturated_conductivity=p%cofgen(3,:)
    p%frost_divdra_drainage%distribution%horizontal_anisotropy_factor=[1._real64,1._real64,1._real64,1._real64]
    p%frost_divdra_drainage%distribution%drain_spacing=20._real64
    p%frost_divdra_drainage%drain_bottom_cm=drain_bottom
    p%frost_divdra_drainage%separate_infiltration=family>3
    p%frost_divdra_drainage%surface_water_level_cm=-.25_real64
  end subroutine
  subroutine execute_case(bottom_mode, top_flux, bottom_flux, bottom_head, duration, use_certificate, hydrostatic, &
                          output, observation, frost_case, frost_temperature, final_physical_state, final_diagnostic, &
                          start_time, initial_physical_state, frost_surface_temperature, drain_case, resumed, captured)
    integer, intent(in) :: bottom_mode
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head, duration
    logical, intent(in) :: use_certificate, hydrostatic
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_serialized_physical_observation_t), intent(out) :: observation
    logical,intent(in),optional::drain_case
    type(kernel_committed_state_t),intent(in),optional::resumed
    type(kernel_committed_state_t),intent(out),optional::captured
    logical, intent(in), optional :: frost_case
    real(real64), intent(in), optional :: frost_temperature
    type(fmr_b110_physical_state_t), intent(out), optional :: final_physical_state
    type(fmr_column_diagnostics_t), intent(out), optional :: final_diagnostic
    real(real64), intent(in), optional :: start_time
    type(fmr_b110_physical_state_t), intent(in), optional :: initial_physical_state
    real(real64), intent(in), optional :: frost_surface_temperature
    class(transaction_state_t), allocatable :: snapshot
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_physical_calls
    logical :: ok
    real(real64) :: t0

    call initialize_parameters(parameters, bottom_mode)
    if (present(frost_case)) then
      if (frost_case) call enable_bounded_frost(parameters)
    end if
    call configure_divdra(parameters)
    if (use_certificate) then
      call initialize_temporal_committed(committed, parameters, hydrostatic, ok)
    else
    t0 = 0.0_real64
    if (present(start_time)) t0 = start_time
    if (present(initial_physical_state)) then
      call fmr_new_b110_committed_state(committed, column_id, initial_physical_state, t0, ok)
    else
      call initialize_committed(committed, parameters, hydrostatic, ok, frost_temperature, t0)
    end if
    end if
    call require(ok, 'committed state initialization')
    if(present(resumed))committed=resumed
    call initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)
    if(allocated(forcing%drainage_flux_by_level))deallocate(forcing%drainage_flux_by_level)

    if (parameters%soil_temperature_active) then
      allocate(forcing%soil_temperature)
      forcing%soil_temperature%prescribed_surface_temperature_c = merge(-4._real64,-.7_real64,low_route)
      if (present(frost_temperature)) forcing%soil_temperature%prescribed_surface_temperature_c = frost_temperature
      if (present(frost_surface_temperature)) &
           forcing%soil_temperature%prescribed_surface_temperature_c = frost_surface_temperature
    end if

    template%template_id = 440001_int64
    template%physics_topology_id = 440002_int64
    template%vertical_layout_id = 440003_int64
    template%state_layout_id = 440004_int64
    template%solver_interface_id = 440005_int64
    template%optional_state_layout_id = 0_int64
    if (parameters%soil_temperature_active) &
         template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    if (use_certificate) then
      template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    else
      template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    end if
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    if (use_certificate) then
      config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
      config%transaction%temporal_tolerance = 0.0_real64
      config%transaction%max_retries = 8
      config%model_temporal_indicator_budget_available = .true.
      config%model_temporal_indicator_budget = qualification_head_budget
    else
      config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
      config%transaction%temporal_tolerance = 1.0e-6_real64
      config%transaction%max_retries = 8
      config%model_temporal_indicator_budget_available = .false.
      config%model_temporal_indicator_budget = 0.0_real64
    end if
    if(parameters%frost_drainage%active)then
      config%transaction%temporal_tolerance=1._real64
      config%transaction%max_retries=20
    end if
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%max_committed_substeps = 100000
    config%progress_tolerance = 0.0_real64

    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = t0
    output%requested_t1 = t0 + duration
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_physical_calls = 0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, t0, t0+duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
    if(present(captured))captured=committed
    if (present(final_diagnostic)) final_diagnostic = diagnostic
    if (present(final_physical_state)) then
      call committed%snapshot(snapshot, ok)
      call require(ok, 'capture final committed physical state')
      select type (state => snapshot)
      type is (fmr_b110_physical_state_t)
        final_physical_state = state
      class default
        call require(.false., 'final committed state has base physical layout')
      end select
    end if
  end subroutine execute_case

  subroutine initialize_parameters(parameters, bottom_mode)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer, intent(in) :: bottom_mode
    integer :: k
    parameters%parameter_set_id = 440044_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    ! The historical FSI stub disnod is not a consistent nonuniform grid metric.
    ! This front-geometry fixture uses the actual adjacent-center distances.
    parameters%node_distance(1)=-parameters%z(1)
    do k=2,numnod
      parameters%node_distance(k)=parameters%z(k-1)-parameters%z(k)
    end do
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = bottom_mode
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters

  subroutine enable_bounded_frost(parameters)
    type(fmr_b110_physical_parameters_t), intent(inout) :: parameters
    real(real64) :: theta_sat(numnod), quartz(numnod), clay(numnod), organic(numnod)
    integer :: status
    parameters%frost_active = .true.
    parameters%frost_hydraulic%active = .true.
    parameters%frost_hydraulic%reduction_start_c = 0.0_real64
    parameters%frost_hydraulic%reduction_end_c = -2.0_real64
    parameters%soil_temperature_active = .true.
    allocate(parameters%soil_temperature)
    theta_sat = 0.45_real64
    quartz = 0.60_real64
    clay = 0.20_real64
    organic = 0.05_real64
    call initialize_soil_temperature_parameters(parameters%dz, parameters%node_distance, theta_sat, quartz, clay, &
         organic, parameters%soil_temperature, status)
    call require(status == 0, 'sensible-temperature parameter fixture')
  end subroutine enable_bounded_frost

  subroutine initialize_committed(committed, parameters, hydrostatic, ok, frost_temperature, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    logical, intent(out) :: ok
    real(real64), intent(in), optional :: frost_temperature
    real(real64), intent(in), optional :: initial_time
    type(fmr_b110_physical_state_t) :: state
    call initialize_physical_state(parameters, hydrostatic, state, frost_temperature)
    if (present(initial_time)) then
      call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
    else
      call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, ok)
    end if
  end subroutine initialize_committed

  subroutine initialize_temporal_committed(committed, parameters, hydrostatic, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: accepted_predecessor_right_derivative(numnod)
    call initialize_physical_state(parameters, hydrostatic, state)
    call require(hydrostatic, 'certificate fixture must use hydrostatic predecessor')
    accepted_predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, 0.0_real64, ok, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_temporal_committed

  subroutine initialize_physical_state(parameters, hydrostatic, state, frost_temperature)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(in), optional :: frost_temperature
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: gradient
    integer :: i
    real(real64) :: initial_temperature

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, merge(upward_dt,equilibrium_dt,hydrostatic))
    if (hydrostatic) then
      heads(1) = h0
      do i = 2, numnod
        heads(i) = heads(i-1) + parameters%node_distance(i)
        gradient = (heads(i-1)-heads(i))/parameters%node_distance(i) + 1.0_real64
        call require(abs(gradient) <= 16.0_real64*epsilon(1.0_real64), 'hydrostatic zero internal gradient')
      end do
    else
      heads = h0
    end if
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    if (parameters%soil_temperature_active) then
      initial_temperature = -4.0_real64
      if (present(frost_temperature)) initial_temperature = frost_temperature
      allocate(state%soil_temperature)
      call initialize_soil_temperature_state([initial_temperature,initial_temperature,initial_temperature,initial_temperature], &
           state%soil_temperature, i)
      call require(i == 0, 'initial soil-temperature state')
    end if
  end subroutine initialize_physical_state

  subroutine initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head
    forcing%top_flux = top_flux
    forcing%top_head = h0
    forcing%bottom_flux = bottom_flux
    forcing%bottom_head = bottom_head
    allocate(forcing%subsurface_irrigation_source(numnod), forcing%root_extraction_sink(numnod))
    forcing%subsurface_irrigation_source=0._real64
    forcing%root_extraction_sink=0._real64
    forcing%frost_divdra_scalar_rate=raw_scalar
  end subroutine initialize_forcing
  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR44R_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_frost_divdra_runtime
