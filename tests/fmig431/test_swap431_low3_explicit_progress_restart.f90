program test_swap431_low3_explicit_progress
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_legacy_cauchy_bottom_boundary_provider
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_kernel_transactions
  use mod_fmr_committed_restart
  use mod_fixed_flux_top_boundary_provider
  use mod_fmr_runtime_core, only: fmr_logical_column_t
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_groundwater_head_forcing_adapter
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_groundwater_topology_composition, only: groundwater_topology_t
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_runtime_core, only: FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_new_b110_temporal_indicator_committed_state
  use mod_canonical_contracts, only: canonical_numerical_config_t
  implicit none
  real(real64), parameter :: T0=5100.1875_real64,T1=5100.6875_real64,HARD_MASS_GATE=1.0e-12_real64
  type(fmr_production_application_config_t) :: cfg,coldcfg
  type(fmr_production_application_bootstrap_t) :: app,coldapp
  type(fmr_serialized_column_result_t), allocatable :: application(:),cold(:)
  type(fmr_serialized_reference_backend_t), target :: backend,direct,resumed
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(fmr_logical_column_t) :: columns(1)
  type(kernel_committed_state_t) :: states(1),restored(1)
  type(kernel_checkpoint_t) :: cp,cp_restored
  type(kernel_candidate_state_t) :: candidate,other
  type(kernel_result_t) :: first,oracle,failed,replay,continuation,restart
  type(kernel_diagnostics_t) :: diag,oracle_diag
  type(fmr_serialized_physical_observation_t) :: obs
  type(fmr_committed_restart_bundle_t) :: bundle
  type(fmr_b110_physical_forcing_t) :: forcing,direct_forcing
  type(canonical_numerical_config_t) :: limited
  integer(int64), allocatable :: revisions(:)
  real(real64) :: k
  logical :: ok
  integer :: status,progress_steps,progress_retries
  call initialize_application_config(cfg,-75.0_real64,k)
  cfg%tiles(1)%parameters%bottom_mode=3
  cfg%tiles(1)%ordinary_implicit_cauchy=.false.
  cfg%tiles(1)%ordinary_explicit_cauchy=.true.
  cfg%tiles(1)%parameters%swbotb3_explicit_active=.true.
  cfg%tiles(1)%parameters%profile_groundwater_projection=.true.
  cfg%tiles(1)%parameters%swbotb3_explicit_hdrain_cm=-100.0_real64
  cfg%tiles(1)%parameters%swbotb3_explicit_shape_3=1.0_real64
  block
    logical :: prepared
    call prepare_fmr_b110_default_mvg(cfg%tiles(1)%parameters,prepared)
    call require(prepared,'explicit progress prepared MvG authority')
  end block
  cfg%tiles(1)%ledger_id=0_int64
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  allocate(cfg%tiles(1)%initial_right_derivative(numnod))
  ! Exact equilibrium at the initial source time: HBOT5(T0)=-75 and
  ! top_flux=-K. This explicit prior right derivative is not fabricated by
  ! the adapter. The new original proposal applies its endpoint head -74.
  cfg%tiles(1)%initial_right_derivative=0.0_real64
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  cfg%numerical%transaction%temporal_tolerance=1.0_real64
  cfg%numerical%model_temporal_indicator_budget_available=.true.
  cfg%numerical%model_temporal_indicator_budget=1.0e6_real64
  cfg%numerical%transaction%max_retries=16
  cfg%numerical%max_committed_substeps=512
  allocate(cfg%tiles(1)%base_forcing%legacy_swbotb3_implicit_control)
  call cfg%tiles(1)%base_forcing%legacy_swbotb3_implicit_control%initialize_table( &
       T0,1000.0_real64,[1000.0_real64,1000.5_real64,1001.0_real64], &
       [-1.5_real64,-1.0_real64,-0.5_real64], &
       10.0_real64,.true.,status,[1000.0_real64,1000.5_real64,1001.0_real64], &
       [0.0_real64,2.0e-3_real64,4.0e-3_real64])
  call require(status==FMR_CAUCHY3_OK,'source-valid nonconstant progress tables')
  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK,'ordinary production history bootstrap')
  call app%run_standalone(T0,T1,application,status)
  if(status/=FMR_APP_BOOT_OK .or. .not.allocated(application) .or. .not.application(1)%committed)then
    write(*,'(a,1x,i0,1x,l1)') 'LOW03EXP_PROGRESS_APP_STATUS',status,allocated(application)
    if(allocated(application))then
      write(*,'(a,1x,l1,1x,l1,1x,i0,1x,i0,1x,i0,1x,i0,1x,i0,1x,i0,1x,a)') &
           'LOW03EXP_PROGRESS_APP_DIAG',application(1)%completed,application(1)%committed, &
           application(1)%kernel_status,application(1)%commit_status,application(1)%accepted_substeps, &
           application(1)%solver_rejections,application(1)%temporal_rejections,application(1)%mass_rejections, &
           trim(application(1)%admission_status)
    end if
  end if
  call require(status==FMR_APP_BOOT_OK .and. application(1)%committed,'whole application interval commits')
  call require(application(1)%accepted_substeps>=1,'production owner accepts explicit interval')
  call require(abs(application(1)%mass%residual)<=HARD_MASS_GATE,'application hard mass unchanged')
  call app%copy_committed_revisions(revisions,status)
  call require(status==FMR_APP_BOOT_OK .and. all(revisions==1_int64),'one external commit, not per-substep commit')
  call app%close(status)
  coldcfg=cfg
  deallocate(coldcfg%tiles(1)%initial_right_derivative)
  call coldapp%initialize(coldcfg,status)
  call require(status==FMR_APP_BOOT_OK,'cold history state can initialize without fabricating history')
  call coldapp%run_standalone(T0,T1,cold,status)
  call require(status/=FMR_APP_BOOT_OK,'missing history rejects rather than inventing confidence')
  call coldapp%copy_committed_revisions(revisions,status)
  call require(status==FMR_APP_BOOT_OK .and. all(revisions==0_int64),'cold-history rejection preserves authority')
  call coldapp%close(status)
  columns(1)%column_id=cfg%tiles(1)%tile_id
  columns(1)%template_id=cfg%tiles(1)%template%template_id
  columns(1)%parameter_ref=1_int64
  columns(1)%state_handle=1_int64
  columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call backend%initialize(top)
  call direct%initialize(top)
  call resumed%initialize(top)
  call fmr_new_b110_temporal_indicator_committed_state(states(1),columns(1)%column_id, &
       cfg%tiles(1)%initial_state,T0,ok,cfg%tiles(1)%initial_right_derivative)
  call require(ok,'seed exact initial history')
  call states(1)%capture_checkpoint(cp,ok)
  forcing=cfg%tiles(1)%base_forcing
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       forcing,cfg%numerical,T0,T1,cp,first,candidate,diag)
  call require(first%completed .and. candidate%ready(),'whole interval candidate')
  call require(diag%solver_rejections==0 .and. diag%mass_rejections==0,'no solver/mass bypass')
  call require(abs(first%mass%residual)<=HARD_MASS_GATE,'whole interval unrounded hard mass')
  progress_steps=diag%accepted_substeps
  obs=backend%observation()
  call require(obs%cauchy3_proposal_available,'explicit proposal observation')
  call require(same_bits(obs%cauchy3_proposed_t0,T0) .and. same_bits(obs%cauchy3_proposed_t1,T1), &
       'proposal covers requested interval')
  call require(same_bits(obs%cauchy3_head_sample_t1900,1000.5_real64),'proposal samples original endpoint')
  call require(same_bits(obs%cauchy3_aquifer_head_cm,-1.0_real64),'proposal aquifer head')
  call require(same_bits(first%mass%storage_end,application(1)%mass%storage_end) .and. &
       same_bits(first%mass%total_out,application(1)%mass%total_out), 'public bootstrap and observed backend identity')
  call backend%discard_trial_candidate(candidate,diag)

  ! Deliberately tighten only the temporal certificate. The model must shorten
  ! and retry, publish no candidate, and leave committed authority untouched.
  limited=cfg%numerical
  limited%model_temporal_indicator_budget=0.01_real64
  limited%transaction%max_retries=2
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       forcing,limited,T0,T1,cp,failed,candidate,diag)
  progress_retries=diag%retries
  call require(.not.failed%completed .and. .not.candidate%ready(),'tight certificate fails closed')
  call require(diag%retries>0 .and. diag%temporal_rejections>0,'shortened temporal retries exercised')
  call require(diag%solver_rejections==0 .and. diag%mass_rejections==0,'retry failure is temporal only')
  call require(states(1)%current_revision()==0_int64,'failed retries preserve external revision')

  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       forcing,cfg%numerical,T0,T1,cp,replay,candidate,diag)
  call require(replay%completed .and. candidate%ready(),'replay after failed retries completes')
  call require(same_bits(replay%mass%storage_end,first%mass%storage_end) .and. &
       same_bits(replay%mass%total_out,first%mass%total_out),'replay reproduces successful trajectory')
  call backend%commit_trial_candidate(states(1),candidate,diag,ok,status)
  call require(ok,'one externally accepted interval commit')
  call fmr_export_committed_restart(columns,[cfg%tiles(1)%template],states, &
       cfg%tiles(1)%parameters%parameter_set_id,bundle,ok,status)
  call require(ok .and. status==FMR_RESTART_OK,'dynamic accepted-history export')
  call fmr_restore_committed_restart(bundle,cfg%tiles(1)%parameters%parameter_set_id,columns, &
       [cfg%tiles(1)%template],restored,ok,status)
  call require(ok .and. status==FMR_RESTART_OK,'dynamic accepted-history restore')
  call states(1)%capture_checkpoint(cp,ok)
  call restored(1)%capture_checkpoint(cp_restored,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       forcing,cfg%numerical,T1,T1+0.125_real64,cp,continuation,candidate,diag)
  call resumed%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,restored(1), &
       forcing,cfg%numerical,T1,T1+0.125_real64,cp_restored,restart,other,oracle_diag)
  call require(continuation%completed .and. restart%completed,'changed Cauchy forcing continuation after restart')
  call require(same_bits(continuation%mass%storage_end,restart%mass%storage_end) .and. &
       same_bits(continuation%mass%total_out,restart%mass%total_out), 'nonstationary Cauchy committed restart identity')
  obs=resumed%observation()
  call require(obs%cauchy3_aquifer_head_cm > -1.0_real64, &
       'new accepted-boundary request resamples changed aquifer head')
  call require(obs%cauchy3_q4_cm_per_day > 2.0e-3_real64, &
       'new accepted-boundary request resamples changed Q4')
  print '(a)', 'LOW03EXP_SHORTENED_RETRY_ROLLBACK=PASS'
  print '(a)', 'LOW03EXP_REPLAY_IDENTITY=PASS'
  print '(a)', 'LOW03EXP_FAILED_RETRY_NO_PUBLISH=PASS'
  print '(a)', 'LOW03EXP_HISTORY_MISSING_FAIL_CLOSED=PASS'
  print '(a)', 'LOW03EXP_DYNAMIC_HISTORY_RESTART_CHANGED_HEAD=PASS'
  print '(a,i0,a,i0)', 'LOW03EXP_PROGRESS_COUNTS steps=',progress_steps,' retries=',progress_retries
  print '(a)', 'LOW03EXP_PROGRESS_GATE=PASS'
contains
  subroutine initialize_application_config(value, initial_head, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 660101_int64
    value%tiles(1)%ledger_id = 760101_int64
    value%tiles(1)%template%template_id = 660201_int64
    value%tiles(1)%template%physics_topology_id = 660210_int64
    value%tiles(1)%template%vertical_layout_id = 660220_int64
    value%tiles(1)%template%state_layout_id = 660230_int64
    value%tiles(1)%template%solver_interface_id = 660240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters, 670001_int64)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, initial_head, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 3
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 8
    p%max_backtracking = 4
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

  subroutine initialize_state_and_forcing(p, state, forcing, initial_head, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = -1.5_real64 - p%z
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -999.0_real64

    forcing%top_flux = 0.0_real64
    forcing%top_head = initial_head
    forcing%bottom_flux = 0.0_real64
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_state_and_forcing

  logical function results_identical(a, b) result(same)
    type(fmr_serialized_column_result_t), intent(in) :: a, b

    same = a%admitted .eqv. b%admitted
    same = same .and. (a%completed .eqv. b%completed) .and. (a%committed .eqv. b%committed)
    same = same .and. a%kernel_status == b%kernel_status .and. a%commit_status == b%commit_status
    same = same .and. a%accepted_substeps == b%accepted_substeps
    same = same .and. a%solver_nonlinear_iterations == b%solver_nonlinear_iterations
    same = same .and. a%solver_internal_retries == b%solver_internal_retries
    same = same .and. same_bits(a%mass%storage_start, b%mass%storage_start)
    same = same .and. same_bits(a%mass%storage_end, b%mass%storage_end)
    same = same .and. same_bits(a%mass%storage_change, b%mass%storage_change)
    same = same .and. same_bits(a%mass%total_in, b%mass%total_in)
    same = same .and. same_bits(a%mass%total_out, b%mass%total_out)
    same = same .and. same_bits(a%mass%residual, b%mass%residual)
  end function results_identical

  logical function same_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    same = ia == ib
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'LOW03EXP_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_swap431_low3_explicit_progress
