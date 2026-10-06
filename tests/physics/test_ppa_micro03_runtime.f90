program test_ppa_micro03_runtime
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  implicit none
  real(real64), parameter :: H0_CM=-75.0_real64, MASS_TOL=1.0e-12_real64
  integer(int64), parameter :: COLUMN_ID=591001_int64
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: committed
  type(kernel_committed_state_t) :: heterogeneous_committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_checkpoint_t) :: heterogeneous_checkpoint
  type(kernel_result_t) :: result, replay, rejected
  type(kernel_candidate_state_t) :: candidate, replay_candidate, rejected_candidate
  type(kernel_diagnostics_t) :: diagnostics, replay_diagnostics, rejected_diagnostics
  type(fmr_serialized_reference_backend_t) :: backend, new_backend
  type(fmr_serialized_physical_observation_t) :: observation, replay_observation
  type(fmr_serialized_physical_observation_t) :: heterogeneous_observation
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(canonical_numerical_config_t) :: numerical
  type(fmr_production_application_config_t) :: app_config
  type(fmr_production_application_bootstrap_t) :: app
  type(fmr_serialized_column_result_t), allocatable :: app_results(:)
  real(real64) :: qref
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  integer :: app_status
  logical :: ok

  call initialize_parameters(parameters)
  parameters%root_extraction_active=.true.
  allocate(parameters%micro_de_willigen)
  parameters%micro_de_willigen%root_radius_cm=0.01_real64
  parameters%micro_de_willigen%root_conductance_cm_per_day=0.001_real64
  parameters%micro_de_willigen%stem_a0_per_day=0.01_real64
  parameters%micro_de_willigen%stem_a1_per_cm=0.001_real64
  parameters%micro_de_willigen%half_leaf_pressure_cm=10000.0_real64
  parameters%micro_de_willigen%campbell_exponent=2.0_real64
  call initialize_column_template(column,template)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,1.0_real64)
  call derive_equilibrium_flux(constitutive,qref)
  call initialize_committed_state(committed,constitutive)
  call initialize_forcing(forcing,qref)
  forcing%root_potential_transpiration=1.0e-4_real64
  forcing%micro_rooted_nodes=2
  allocate(forcing%micro_root_length_density(numnod))
  forcing%micro_root_length_density=[0.5_real64,0.5_real64,0.0_real64,0.0_real64]
  numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  numerical%model_temporal_indicator_budget_available=.true.
  numerical%model_temporal_indicator_budget=1.0e-4_real64
  numerical%transaction%mass_tolerance=MASS_TOL
  numerical%transaction%retry_scale=0.5_real64
  numerical%transaction%max_retries=8
  numerical%max_committed_substeps=32
  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'checkpoint capture')
  call backend%initialize(top)
  call backend%run_trial(column,template,parameters,committed,forcing,numerical,0.0_real64,1.0e-3_real64, &
       checkpoint,result,candidate,diagnostics,trace_accepted_water_flux_substeps=.true.)
  print '(a,l1,a,i0,a,es14.6,a,i0)', 'MICRO03_TRIAL completed=',result%completed, &
       ' status=',result%status,' mass=',result%mass%residual,' temporal_rejections=',diagnostics%temporal_rejections
  observation=backend%observation()
  print '(a,4(i0,1x),a,a,a,l1)', 'MICRO03_DIAG solver,temporal,cert,mass=', &
       diagnostics%solver_rejections, diagnostics%temporal_rejections, &
       diagnostics%temporal_certificate_unavailable_rejections,diagnostics%mass_rejections, &
       ' reason=',trim(observation%temporal_certificate_unavailable_reason), &
       ' solver=',observation%solver_executed
  call require(result%completed.and.candidate%ready(),'accepted MICRO trial')
  call require(result%mass%complete.and.abs(result%mass%residual)<=MASS_TOL,'accepted root mass')
  observation=backend%observation()
  call require(allocated(observation%accepted_water_flux_substeps),'accepted sink trace')
  call require(size(observation%accepted_water_flux_substeps)>0,'nonempty sink trace')
  call require(sum(observation%accepted_water_flux_substeps(1)%root_sink)>0.0_real64,'nonzero MICRO sink')
  print '(a,es14.6)', 'MICRO03_ACCEPTED_ROOT_RATE=', &
       sum(observation%accepted_water_flux_substeps(1)%root_sink)
  call require(all(observation%accepted_water_flux_substeps(1)%root_sink(3:)==0.0_real64),'root depth support')
  call require(committed%current_revision()==0_int64,'trial did not commit')
  call new_backend%initialize(top)
  call new_backend%run_trial(column,template,parameters,committed,forcing,numerical,0.0_real64,1.0e-3_real64, &
       checkpoint,replay,replay_candidate,replay_diagnostics,trace_accepted_water_flux_substeps=.true.)
  call require(replay%completed.and.replay_candidate%ready(),'restart replay completed')
  call require(result%mass%residual==replay%mass%residual,'restart replay mass identity')
  call require(result%completed_t==replay%completed_t,'restart replay time identity')
  replay_observation=new_backend%observation()
  call require(all(observation%accepted_water_flux_substeps(1)%root_sink== &
       replay_observation%accepted_water_flux_substeps(1)%root_sink),'restart replay sink identity')
  forcing%root_extraction_sink(1)=0.001_real64
  call backend%run_trial(column,template,parameters,committed,forcing,numerical,0.0_real64,1.0e-3_real64, &
       checkpoint,rejected,rejected_candidate,rejected_diagnostics)
  call require(.not.rejected%completed.and..not.rejected_candidate%ready(),'double sink rejected')
  call require(committed%current_revision()==0_int64,'rejection did not commit')
  forcing%root_extraction_sink=0.0_real64
  parameters%micro_de_willigen%root_radius_cm=-1.0_real64
  call backend%run_trial(column,template,parameters,committed,forcing,numerical,0.0_real64,1.0e-3_real64, &
       checkpoint,rejected,rejected_candidate,rejected_diagnostics)
  call require(.not.rejected%completed.and..not.rejected_candidate%ready(),'failed nonlinear trial rejected')
  call require(rejected_diagnostics%solver_rejections>0,'failed nonlinear retry exercised')
  call require(committed%current_revision()==0_int64,'failed trial did not commit')
  parameters%micro_de_willigen%root_radius_cm=0.01_real64
  app_config%initial_time=0.0_real64
  app_config%numerical=numerical
  allocate(app_config%tiles(1))
  app_config%tiles(1)%tile_id=COLUMN_ID
  app_config%tiles(1)%template=template
  app_config%tiles(1)%parameters=parameters
  app_config%tiles(1)%base_forcing=forcing
  allocate(app_config%tiles(1)%initial_right_derivative(numnod))
  app_config%tiles(1)%initial_right_derivative=0.0_real64
  heads=H0_CM
  call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
  app_config%tiles(1)%initial_state%active_nodes=numnod
  app_config%tiles(1)%initial_state%pressure_head=heads
  app_config%tiles(1)%initial_state%water_content=water
  app_config%tiles(1)%initial_state%groundwater_level=-2.0_real64
  call app%initialize(app_config,app_status)
  call require(app_status==FMR_APP_BOOT_OK,'production app accepts MICRO config')
  call app%run_standalone(0.0_real64,1.0e-3_real64,app_results,app_status)
  call require(app_status==FMR_APP_BOOT_OK,'production app commits MICRO trial')
  call require(all(app_results%committed).and.all(app_results%mass%complete),'production app accepted mass')
  call require(maxval(abs(app_results%mass%residual))<=MASS_TOL,'production app hard mass')
  call app%close(app_status)
  call require(app_status==FMR_APP_BOOT_OK,'production app close')
  ! MICRO05: an explicit two-horizon map admits varying node hydraulics while
  ! each root table still comes from the source horizon's first node.
  app_config%tiles(1)%parameters%cofgen(3,2)=5.1_real64
  app_config%tiles(1)%parameters%cofgen(3,3)=5.5_real64
  app_config%tiles(1)%parameters%cofgen(3,4)=5.9_real64
  app_config%tiles(1)%parameters%cofgen(10,:)=app_config%tiles(1)%parameters%cofgen(3,:)
  app_config%tiles(1)%parameters%cofgen(12,:)=0.99_real64*app_config%tiles(1)%parameters%cofgen(3,:)
  app_config%tiles(1)%parameters%micro_horizon_first_node=[1,1,3,3]
  app_config%tiles(1)%base_forcing%micro_rooted_nodes=numnod
  app_config%tiles(1)%base_forcing%micro_root_length_density=0.5_real64
  app_config%numerical%model_temporal_indicator_budget=1.0e-2_real64
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,app_config%tiles(1)%parameters%cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,1.0_real64)
  call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
  app_config%tiles(1)%initial_state%water_content=water
  call app%initialize(app_config,app_status)
  call require(app_status==FMR_APP_BOOT_OK,'heterogeneous horizon app initialize')
  call app%run_standalone(0.0_real64,1.0e-3_real64,app_results,app_status)
  call require(app_status==FMR_APP_BOOT_OK,'heterogeneous horizon app commit')
  call require(all(app_results%mass%complete).and.maxval(abs(app_results%mass%residual))<=MASS_TOL, &
       'heterogeneous horizon mass')
  call app%close(app_status)
  call require(app_status==FMR_APP_BOOT_OK,'heterogeneous horizon app close')
  call fmr_new_b110_temporal_indicator_committed_state(heterogeneous_committed,COLUMN_ID, &
       app_config%tiles(1)%initial_state,0.0_real64,ok,spread(0.0_real64,1,numnod))
  call require(ok,'heterogeneous horizon committed origin')
  call fmr_capture_checkpoint(heterogeneous_committed,heterogeneous_checkpoint,ok)
  call require(ok,'heterogeneous horizon checkpoint')
  call new_backend%run_trial(column,template,app_config%tiles(1)%parameters,heterogeneous_committed, &
       app_config%tiles(1)%base_forcing,app_config%numerical,0.0_real64,1.0e-3_real64, &
       heterogeneous_checkpoint,result,candidate,diagnostics,trace_accepted_water_flux_substeps=.true.)
  call require(result%completed.and.result%mass%complete.and.abs(result%mass%residual)<=MASS_TOL, &
       'heterogeneous horizon direct trial mass')
  heterogeneous_observation=new_backend%observation()
  call require(allocated(heterogeneous_observation%accepted_water_flux_substeps),'heterogeneous accepted root trace')
  call require(sum(heterogeneous_observation%accepted_water_flux_substeps(1)%root_sink(1:2))>0.0_real64.and. &
       sum(heterogeneous_observation%accepted_water_flux_substeps(1)%root_sink(3:4))>0.0_real64, &
       'both horizons contribute root water')
  call backend%run_trial(column,template,app_config%tiles(1)%parameters,heterogeneous_committed, &
       app_config%tiles(1)%base_forcing,app_config%numerical,0.0_real64,1.0e-3_real64, &
       heterogeneous_checkpoint,replay,replay_candidate,replay_diagnostics,trace_accepted_water_flux_substeps=.true.)
  call require(replay%completed.and.replay_candidate%ready(),'heterogeneous restart replay')
  call require(result%mass%residual==replay%mass%residual.and.result%completed_t==replay%completed_t, &
       'heterogeneous replay mass and time identity')
  replay_observation=backend%observation()
  call require(size(heterogeneous_observation%accepted_water_flux_substeps)== &
       size(replay_observation%accepted_water_flux_substeps),'heterogeneous replay substep count')
  call require(all(heterogeneous_observation%accepted_water_flux_substeps(1)%root_sink== &
       replay_observation%accepted_water_flux_substeps(1)%root_sink),'heterogeneous replay sink identity')
  call require(heterogeneous_committed%current_revision()==0_int64,'heterogeneous trial did not commit')
  print '(a,es14.6)', 'MICRO05_HETEROGENEOUS_RUNTIME_MASS=',result%mass%residual
  app_config%tiles(1)%parameters%micro_horizon_first_node=[1,1,2,3]
  call app%initialize(app_config,app_status)
  call require(app_status/=FMR_APP_BOOT_OK,'invalid horizon map rejected')
  print '(a)', 'MICRO05_HETEROGENEOUS_APP_TRIAL=PASS'
  print '(a)', 'MICRO03_TRIAL_MASS_RESTART_REJECTION=PASS'
contains
  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 591010_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = MASS_TOL
    p%total_balance_tolerance = MASS_TOL
    p%head_abs_tolerance = MASS_TOL
    p%head_rel_tolerance = MASS_TOL
    p%ponding_tolerance = MASS_TOL
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f, flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: flux

    f%top_flux = flux
    f%top_head = H0_CM
    f%bottom_flux = flux
    f%bottom_head = H0_CM
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t

    t%template_id = 591020_int64
    t%physics_topology_id = 591021_int64
    t%vertical_layout_id = 591022_int64
    t%state_layout_id = 591023_int64
    t%solver_interface_id = 591024_int64
    t%optional_state_layout_id = 0_int64
    t%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = COLUMN_ID
    c%template_id = t%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine derive_equilibrium_flux(provider, flux)
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64), intent(out) :: flux
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = H0_CM
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    flux = -conductivity(1)
    call require(ieee_is_finite(flux), 'equilibrium flux finite')
  end subroutine derive_equilibrium_flux

  subroutine initialize_committed_state(state, provider)
    type(kernel_committed_state_t), intent(out) :: state
    type(b110_default_mvg_provider_t), intent(in) :: provider
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok

    heads = H0_CM
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = heads
    physical%water_content = water
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state, COLUMN_ID, physical, 0.0_real64, ok, &
         spread(0.0_real64,1,numnod))
    call require(ok, 'committed state initialization')
  end subroutine initialize_committed_state
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(*),intent(in)::label
    if (.not.condition) then
      print '(a,a)', 'MICRO03_FAIL ',label
      error stop 1
    end if
  end subroutine require
end program test_ppa_micro03_runtime
