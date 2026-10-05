program test_frost_composed_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  use mod_root_uptake_compensation,only:ROOT_COMP_JARVIS,ROOT_COMP_WALSUM,ROOT_COMP_FROST,root_walsum_geometry_t
  use mod_fmr_production_application_bootstrap
  use mod_frost_hydraulic_effect, only: frost_hydraulic_parameters_t, evaluate_frost_hydraulic_factor
  implicit none
  real(real64),parameter::h0=-75._real64,equilibrium_dt=.25_real64,upward_dt=1.e-4_real64
  real(real64),parameter::hard_mass_gate=1.e-12_real64,qualification_head_budget=2.5e-11_real64
  integer(int64),parameter::column_id=440044_int64
  type(fmr_b110_physical_parameters_t)::parameters
  type(fmr_b110_physical_state_t)::initial,wet,final,replay,direct,next,restored_state
  type(fmr_serialized_column_result_t)::result,again
  type(fmr_serialized_physical_observation_t)::observation
  type(kernel_committed_state_t)::captured,registry(1)
  type(kernel_committed_state_t)::restored(1)
  type(fmr_logical_column_t)::columns(1)
  type(fmr_template_t)::templates(1)
  type(fmr_committed_restart_bundle_t)::bundle
  class(transaction_state_t),allocatable::snapshot
  real(real64),allocatable::tf(:),td(:)
  real(real64)::q,dt,head_diff,temp_diff
  integer::status,i,signum,method,regime
  real(real64)::uptake,expected_bottom
  type(fmr_b110_physical_state_t)::frozen,moist
  logical::ok
  call initialize_parameters(parameters,2)
  call enable_bounded_frost(parameters)
  call initialize_physical_state(parameters,.true.,initial,1._real64)
  call initialize_soil_temperature_state([-4._real64,-4._real64,1._real64,1._real64],initial%soil_temperature,status)
  call require(status==0,'joint mixed thermal profile')
  frozen=initial;frozen%pressure_head=[0._real64,1._real64,2._real64,3._real64]
  frozen%water_content=parameters%cofgen(2,:)
  call initialize_soil_temperature_state([-4._real64,-4._real64,-4._real64,-4._real64],frozen%soil_temperature,status)
  call require(status==0,'joint fully frozen profile')
  moist=initial
  block
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::w(4),k(4),c(4),dk(4)
    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,upward_dt)
    moist%pressure_head=-5._real64
    call provider%evaluate(moist%pressure_head,w,k,c,dk)
    moist%water_content=w
  end block
  do method=0,2
    uptake=.01_real64
    if(method/=0)uptake=uptake/.7_real64
    do regime=1,3
      wet=initial
      if(regime==2)wet=frozen
      if(regime==3)wet=moist
      do signum=-1,1,2
        q=real(signum,real64)*1.e-3_real64
        expected_bottom=q
        if(regime/=1)expected_bottom=0._real64
        call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,result,observation, &
             frost_case=.true.,frost_temperature=-4._real64,initial_physical_state=wet, &
             final_physical_state=final,bottom_case=.true.,root_case=.true.,root_method=method,captured=captured)
        call require(result%completed.and.result%committed,'joint signed/root method commits')
        call require(observation%root_frost_executed.and.observation%frost_bottom_executed,'both policies execute')
        call require(abs(observation%bottom_flux-expected_bottom)<=1.e-14_real64,'joint actual bottom flux oracle')
        call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'joint hard mass closure')
        call require(result%actual_transpiration_available,'joint accepted root publication')
        if(regime/=2)then
          call require(abs(result%actual_transpiration_amount-uptake*1.e-4_real64)<=1.e-14_real64,'joint root amount oracle')
          call require(abs(result%mass%storage_change-(expected_bottom-uptake)*1.e-4_real64)<=hard_mass_gate,'net storage oracle')
          if(regime==1)call require(result%temporal_rejections>0,'joint actual retry')
          call require(observation%root_frost_final_sink(1)==0._real64.and. &
               observation%root_frost_final_sink(2)==0._real64,'frozen roots not resurrected')
        else
          call require(result%actual_transpiration_amount==0._real64,'all frozen root uptake zero')
          call require(result%mass%total_in==0._real64.and.result%mass%total_out==0._real64,'blocked all-frozen exchanges zero')
        end if
        print '(A,I0,A,I0,A,I0)','PPA-WU05B4_CASE method=',method,' regime=',regime,' sign=',signum
      end do
    end do
  end do
  ! Independent top-only and warm cases: no deep-freeze bottom blocking.
  do regime=4,5
    wet=moist
    call initialize_soil_temperature_state([-4._real64,1._real64,1._real64,1._real64],wet%soil_temperature,status)
    uptake=.02_real64/.7_real64
    if(regime==5)then
      call initialize_soil_temperature_state([1._real64,1._real64,1._real64,1._real64],wet%soil_temperature,status)
      uptake=.03_real64
    end if
    call require(status==0,'joint top-only/warm profile')
    do signum=-1,1,2
      q=real(signum,real64)*1.e-3_real64
      call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,result,observation, &
           frost_case=.true.,frost_temperature=merge(-4._real64,1._real64,regime==4), &
           initial_physical_state=wet,final_physical_state=final,bottom_case=.true.,root_case=.true.,root_method=2)
      call require(result%completed.and.result%committed,'top-only/warm joint trajectory commits')
      call require(.not.observation%frost_bottom%blocked,'top-only/warm cannot block bottom')
      call require(abs(observation%bottom_flux-q)<=1.e-14_real64,'top-only/warm bottom flux oracle')
      call require(result%actual_transpiration_available,'top-only/warm uptake publication')
      call require(abs(result%actual_transpiration_amount-uptake*1.e-4_real64)<=1.e-14_real64,'top-only/warm root oracle')
      call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'top-only/warm hard mass')
      call require(abs(result%mass%storage_change-(q-uptake)*1.e-4_real64)<=hard_mass_gate,'top-only/warm net storage')
      print '(A,I0,A,I0)','PPA-WU05B4_THERMAL regime=',regime,' sign=',signum
    end do
  end do
  ! Mixed nonzero trajectory: fine direct refinement and actual committed restart.
  q=1.e-3_real64
  call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,result,observation, &
       frost_case=.true.,frost_temperature=-4._real64,initial_physical_state=initial, &
       final_physical_state=final,bottom_case=.true.,root_case=.true.,root_method=2,captured=captured)
  call require(result%committed,'restart source joint trajectory')
  direct=initial;dt=1.e-4_real64/2048._real64
  do i=1,2048
    call execute_case(2,0._real64,q,-999999._real64,dt,.false.,.true.,again,observation, &
         frost_case=.true.,frost_temperature=-4._real64,initial_physical_state=direct, &
         final_physical_state=next,start_time=real(i-1,real64)*dt, &
         bottom_case=.true.,root_case=.true.,root_method=2)
    call require(again%committed,'joint fine direct continuation')
    direct=next
  end do
  call copy_soil_temperature_profile(final%soil_temperature,tf,status)
  call require(status==0,'joint retried thermal profile')
  call copy_soil_temperature_profile(direct%soil_temperature,td,status)
  call require(status==0,'joint fine thermal profile')
  head_diff=maxval(abs(final%pressure_head-direct%pressure_head));temp_diff=maxval(abs(tf-td))
  print '(A,ES14.6,A,ES14.6)','PPA-WU05B4_FINE head_cm=',head_diff,' temperature_c=',temp_diff
  call require(head_diff<=1.e-6_real64.and.temp_diff<=1.e-4_real64,'joint cumulative horizon envelope')
  call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,again,observation, &
       frost_case=.true.,frost_temperature=-4._real64,initial_physical_state=initial, &
       final_physical_state=replay,bottom_case=.true.,root_case=.true.,root_method=2)
  call require(again%committed.and.all(final%pressure_head==replay%pressure_head),'joint fresh worker replay identity')
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
  call require(ok.and.status==FMR_RESTART_OK,'joint accepted restart export')
  call fmr_restore_committed_restart(bundle,parameters%parameter_set_id,columns,templates,restored,ok,status)
  call require(ok.and.status==FMR_RESTART_OK,'joint empty-registry restore')
  call require(restored(1)%current_revision()==captured%current_revision(),'joint restart revision')
  call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,result,observation, &
       frost_case=.true.,frost_temperature=-4._real64,start_time=1.e-4_real64, &
       bottom_case=.true.,root_case=.true.,root_method=2,resumed=captured,final_physical_state=final)
  call require(result%committed,'joint source continuation')
  call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,again,observation, &
       frost_case=.true.,frost_temperature=-4._real64,start_time=1.e-4_real64, &
       bottom_case=.true.,root_case=.true.,root_method=2,resumed=restored(1),final_physical_state=replay)
  call require(again%committed.and.all(final%pressure_head==replay%pressure_head),'joint fresh restart identity')
  call require(result%actual_transpiration_amount==again%actual_transpiration_amount,'joint restart uptake identity')
  call require(result%mass%storage_change==again%mass%storage_change,'joint restart water receipt identity')
  call require(observation%root_frost_executed.and.observation%frost_bottom_executed,'restart recomputes both policies')
  call verify_application(initial,moist)
  print '(A)','PPA-WU05B4_ROOT_BOTTOM_FROST_RUNTIME=PASS'
contains
  subroutine verify_application(dry,wet)
    type(fmr_b110_physical_state_t),intent(in)::dry,wet
    type(fmr_production_application_config_t)::cfg,bad
    type(fmr_production_application_bootstrap_t)::app,rejected
    type(fmr_serialized_column_result_t),allocatable::out(:)
    integer::status,method,regime
    real(real64)::uptake,q
    allocate(cfg%tiles(1))
    cfg%tiles(1)%tile_id=column_id;cfg%tiles(1)%ledger_id=440045_int64
    cfg%tiles(1)%template=templates(1)
    call initialize_parameters(cfg%tiles(1)%parameters,2)
    call enable_bounded_frost(cfg%tiles(1)%parameters)
    cfg%tiles(1)%parameters%frost_bottom%active=.true.
    cfg%tiles(1)%parameters%frost_bottom%head_budget_cm=1.e-6_real64
    cfg%tiles(1)%parameters%frost_bottom%temperature_budget_c=1.e-7_real64
    cfg%tiles(1)%parameters%head_abs_tolerance=1.e-8_real64
    cfg%tiles(1)%parameters%head_rel_tolerance=1.e-8_real64
    cfg%tiles(1)%parameters%root_extraction_active=.true.
    cfg%tiles(1)%parameters%root_frost%active=.true.
    cfg%tiles(1)%parameters%root_frost%rooted_nodes=3
    cfg%tiles(1)%parameters%root_frost_head_budget_cm=1.e-6_real64
    cfg%tiles(1)%parameters%root_frost_temperature_budget_c=1.e-7_real64
    cfg%tiles(1)%parameters%root_compensation%alpha_critical=.7_real64
    call initialize_forcing(cfg%tiles(1)%base_forcing,0._real64,1.e-3_real64,-999999._real64)
    cfg%tiles(1)%base_forcing%root_extraction_sink=[.01_real64,.01_real64,.01_real64,0._real64]
    allocate(cfg%tiles(1)%base_forcing%root_potential_sink(4),cfg%tiles(1)%base_forcing%root_walsum_geometry)
    cfg%tiles(1)%base_forcing%root_potential_sink=cfg%tiles(1)%base_forcing%root_extraction_sink
    cfg%tiles(1)%base_forcing%root_potential_transpiration=.03_real64
    cfg%tiles(1)%base_forcing%root_walsum_geometry=root_walsum_geometry_t(.5_real64,5._real64,1.5_real64)
    allocate(cfg%tiles(1)%base_forcing%soil_temperature)
    cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=-4._real64
    cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%numerical%transaction%temporal_tolerance=1._real64
    cfg%numerical%transaction%mass_tolerance=hard_mass_gate
    cfg%numerical%transaction%max_retries=20
    cfg%numerical%transaction%retry_scale=.5_real64
    cfg%numerical%max_committed_substeps=100000
    do method=0,2
      cfg%tiles(1)%parameters%root_compensation%method=method
      cfg%tiles(1)%parameters%root_compensation%stressor=ROOT_COMP_FROST
      if(method==0)cfg%tiles(1)%parameters%root_compensation%stressor=0
      uptake=.01_real64
      if(method/=0)uptake=uptake/.7_real64
      do regime=1,2
        cfg%tiles(1)%initial_state=dry
        q=1.e-3_real64
        if(regime==2)then
          cfg%tiles(1)%initial_state=wet
          q=0._real64
        end if
        call app%initialize(cfg,status)
        call require(status==FMR_APP_BOOT_OK,'joint application admission')
        call app%run_standalone(0._real64,1.e-4_real64,out,status)
        call require(status==FMR_APP_BOOT_OK.and.out(1)%committed,'joint application commits')
        call require(out(1)%actual_transpiration_available,'joint application accepted root publication')
        call require(abs(out(1)%actual_transpiration_amount-uptake*1.e-4_real64)<=1.e-14_real64,'joint application uptake oracle')
        call require(abs(out(1)%mass%storage_change-(q-uptake)*1.e-4_real64)<=hard_mass_gate,'joint application net storage oracle')
        call require(abs(out(1)%mass%residual)<=hard_mass_gate,'joint application hard mass')
        call app%close(status)
      end do
    end do
    bad=cfg;bad%tiles(1)%parameters%frost_bottom%head_budget_cm=0._real64
    call rejected%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK,'missing boundary numerical budget rejected')
    bad=cfg;bad%tiles(1)%parameters%root_frost_temperature_budget_c=0._real64
    call rejected%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK,'missing root numerical budget rejected')
    bad=cfg;bad%tiles(1)%parameters%root_salinity_active=.true.
    call rejected%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK,'joint salt/frost remains rejected')
    bad=cfg;bad%tiles(1)%parameters%drainage_response_active=.true.
    call rejected%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK,'active drainage redistribution rejected')
    bad=cfg;bad%tiles(1)%parameters%frost_bottom%active=.false.
    call rejected%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK,'root-only nonzero qbot remains rejected')
    print '(A)','PPA-WU05B4_ROOT_BOTTOM_FROST_APPLICATION=PASS'
  end subroutine

  subroutine execute_case(bottom_mode, top_flux, bottom_flux, bottom_head, duration, use_certificate, hydrostatic, &
                          output, observation, frost_case, frost_temperature, final_physical_state, final_diagnostic, &
                          start_time, initial_physical_state, frost_surface_temperature, bottom_case, resumed, captured, root_case, root_method)
    integer, intent(in) :: bottom_mode
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head, duration
    logical, intent(in) :: use_certificate, hydrostatic
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_serialized_physical_observation_t), intent(out) :: observation
    logical,intent(in),optional::bottom_case,root_case
    integer,intent(in),optional::root_method
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
    if(present(bottom_case))then
      if(bottom_case)then
        parameters%frost_bottom%active=.true.
        parameters%frost_bottom%head_budget_cm=1.e-6_real64
        parameters%frost_bottom%temperature_budget_c=1.e-7_real64
        parameters%head_abs_tolerance=1.e-8_real64
        parameters%head_rel_tolerance=1.e-8_real64
      end if
    end if
    if(present(root_case))then
      if(root_case)then
        parameters%root_extraction_active=.true.
        parameters%root_frost%active=.true.
        parameters%root_frost%rooted_nodes=3
        parameters%root_frost_head_budget_cm=1.e-6_real64
        parameters%root_frost_temperature_budget_c=1.e-7_real64
        parameters%root_compensation%method=ROOT_COMP_JARVIS
        if(present(root_method))parameters%root_compensation%method=root_method
        parameters%root_compensation%stressor=ROOT_COMP_FROST
        if(parameters%root_compensation%method==0)parameters%root_compensation%stressor=0
        parameters%root_compensation%alpha_critical=.7_real64
      end if
    end if
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
    if(parameters%root_frost%active)then
      forcing%root_extraction_sink=[.01_real64,.01_real64,.01_real64,0._real64]
      allocate(forcing%root_potential_sink(4))
      forcing%root_potential_sink=forcing%root_extraction_sink
      forcing%root_potential_transpiration=.03_real64
      if(parameters%root_compensation%method==ROOT_COMP_WALSUM)then
        allocate(forcing%root_walsum_geometry)
        forcing%root_walsum_geometry=root_walsum_geometry_t(.5_real64,5._real64,1.5_real64)
      end if
    end if
    if (parameters%soil_temperature_active) then
      allocate(forcing%soil_temperature)
      forcing%soil_temperature%prescribed_surface_temperature_c = -4.0_real64
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
    if(parameters%frost_bottom%active)then
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
    parameters%node_distance = disnod(1:numnod)
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
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine determine_initial_conductivity(k)
    real(real64), intent(out) :: k
    type(fmr_b110_physical_parameters_t) :: parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    call initialize_parameters(parameters, 2)
    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, equilibrium_dt)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k = conductivity(1)
  end subroutine determine_initial_conductivity

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR44R_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_frost_composed_runtime
