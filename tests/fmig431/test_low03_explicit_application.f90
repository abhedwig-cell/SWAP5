program test_low03_explicit_application
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, fmr_logical_column_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_legacy_cauchy_bottom_boundary_provider
  use mod_fmr_legacy_explicit_cauchy_bottom_boundary_provider
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_kernel_transactions
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fixed_flux_top_boundary_provider
  use mod_groundwater_topology_composition, only: groundwater_topology_t
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t
  implicit none
  real(real64), parameter :: T0=5100.1875_real64,T1=5100.6875_real64,HARD_MASS_GATE=1.0e-12_real64
  real(real64), parameter :: QUALIFICATION_HEAD_BUDGET=1.0e-2_real64
  type(fmr_production_application_config_t) :: cfg,bad
  type(fmr_production_application_bootstrap_t) :: app,badapp
  type(fmr_serialized_column_result_t),allocatable :: result(:)
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(fmr_logical_column_t) :: columns(1)
  type(kernel_committed_state_t) :: states(1)
  type(kernel_checkpoint_t) :: cp
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diag
  type(kernel_result_t) :: trial
  type(fmr_serialized_physical_observation_t) :: obs
  type(groundwater_topology_t) :: topology
  type(groundwater_tile_predictor_input_t) :: predictors(0)
  type(groundwater_cell_area_input_t) :: areas(0)
  integer(int64) :: context_handle
  real(real64) :: conductivity0,haq_eq,rimlay
  integer :: status,j
  logical :: ok, app_transaction_ok

  rimlay=10.0_real64
  call initialize_application_config(cfg,-75.0_real64,conductivity0)
  cfg%tiles(1)%parameters%bottom_mode=3
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  allocate(cfg%tiles(1)%initial_right_derivative(numnod));cfg%tiles(1)%initial_right_derivative=0.0_real64
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  cfg%numerical%model_temporal_indicator_budget_available=.true.
  cfg%numerical%model_temporal_indicator_budget=1.0e6_real64
  cfg%tiles(1)%ordinary_implicit_cauchy=.false.
  cfg%tiles(1)%ordinary_explicit_cauchy=.true.
  cfg%tiles(1)%ledger_id=0_int64
  haq_eq=cfg%tiles(1)%initial_state%pressure_head(numnod)+z(numnod) + &
       (-conductivity0)*(0.5_real64*dz(numnod)/conductivity0+rimlay)
  allocate(cfg%tiles(1)%base_forcing%legacy_swbotb3_implicit_control)
  call cfg%tiles(1)%base_forcing%legacy_swbotb3_implicit_control%initialize_table( &
       T0,1000.0_real64,[1000.0_real64,1000.5_real64,1001.0_real64],[haq_eq,haq_eq,haq_eq], &
       rimlay,.true.,status,[1000.0_real64,1001.0_real64],[0.0_real64,0.0_real64])
  call require(status==FMR_CAUCHY3_OK,'production control')
  allocate(cfg%tiles(1)%base_forcing%legacy_swbotb3_explicit_control)
  ! Choose gwlmean at the profile bottom so cvalprof=0.  Set HDRain=GWL
  ! and choose DEEPGW such that the B1.11 explicit qbot equals -conductivity0,
  ! matching the uniform-profile top flux used by this qualification.
  cfg%tiles(1)%base_forcing%legacy_swbotb3_explicit_control%hdrain_cm=cfg%tiles(1)%initial_state%groundwater_level
  cfg%tiles(1)%base_forcing%legacy_swbotb3_explicit_control%shape_3=0.0_real64
  block
    real(real64)::cprof,bottom,sat,gw
    integer::node,k
    gw=cfg%tiles(1)%initial_state%groundwater_level
    node=numnod;bottom=0.0_real64
    do k=1,numnod
      bottom=bottom-cfg%tiles(1)%parameters%dz(k)
      if(gw>bottom+cfg%tiles(1)%parameters%dz(k).and.node==numnod)node=k
    end do
    bottom=-sum(cfg%tiles(1)%parameters%dz(1:node))
    sat=gw-bottom
    cprof=sat/cfg%tiles(1)%parameters%cofgen(3,node)
    do k=node+1,numnod
      cprof=cprof+cfg%tiles(1)%parameters%dz(k)/cfg%tiles(1)%parameters%cofgen(3,k)
    end do
    haq_eq=gw-conductivity0*(rimlay+cprof)
  end block
  call cfg%tiles(1)%base_forcing%legacy_swbotb3_implicit_control%initialize_table( &
       T0,1000.0_real64,[1000.0_real64,1000.5_real64,1001.0_real64],[haq_eq,haq_eq,haq_eq], &
       rimlay,.true.,status,[1000.0_real64,1001.0_real64],[0.0_real64,0.0_real64])
  call require(status==FMR_CAUCHY3_OK,'explicit equilibrium temporal control')
  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK .and. app%ready(),'ordinary Cauchy bootstrap')
  call app%materialize_groundwater_context(topology,predictors,areas,context_handle,status)
  call require(status/=FMR_APP_BOOT_OK .and. context_handle==0_int64,'ordinary Cauchy rejects groundwater context')
  call app%run_standalone(T0,T1,result,status)
  write(*,'(a,1x,i0,1x,l1,1x,l1,1x,l1,1x,i0,1x,i0,1x,a)') 'LOW03EXP_TX_DIAG',status, &
       result(1)%admitted,result(1)%completed,result(1)%committed,result(1)%kernel_status,result(1)%commit_status, &
       trim(result(1)%admission_status)
  write(*,'(a,1x,l1,1x,a,1x,i0,1x,i0,1x,i0,1x,i0,1x,i0)') 'LOW03EXP_SOLVER_DIAG', &
       result(1)%solver_executed,trim(result(1)%solver_route),result(1)%solver_iterations, &
       result(1)%solver_nonlinear_iterations,result(1)%solver_internal_retries,result(1)%solver_headcalc_calls, &
       result(1)%accepted_substeps
  write(*,'(a,1x,l1,1x,es24.16,1x,es24.16,1x,es24.16,1x,es24.16,1x,es24.16,1x,i0)') 'LOW03EXP_MASS_DIAG', &
       result(1)%mass%complete,result(1)%mass%storage_start,result(1)%mass%storage_end,result(1)%mass%total_in, &
       result(1)%mass%total_out,result(1)%mass%residual,result(1)%mass%accepted_transaction_count
  app_transaction_ok = status==FMR_APP_BOOT_OK .and. result(1)%completed .and. result(1)%committed
  call app%close(status)

  columns(1)%column_id=cfg%tiles(1)%tile_id
  columns(1)%template_id=cfg%tiles(1)%template%template_id
  columns(1)%parameter_ref=1_int64
  columns(1)%state_handle=1_int64
  columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call backend%initialize(top)
  block
    real(real64)::previous(numnod)
    previous=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(states(1),columns(1)%column_id,cfg%tiles(1)%initial_state,T0,ok,previous)
  end block
  call require(ok,'committed state')
  call states(1)%capture_checkpoint(cp,ok)
  call require(ok,'checkpoint')
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,trial,candidate,diag)
  obs=backend%observation()
  write(*,'(a,1x,i0,1x,l1,1x,i0,1x,i0,1x,i0,1x,i0,1x,i0)') 'LOW03EXP_DIRECT_DIAG', &
       trial%status,trial%completed,diag%attempts,diag%retries,diag%solver_rejections,diag%mass_rejections, &
       diag%temporal_rejections
  write(*,'(a,1x,l1,1x,es24.16,1x,es24.16,1x,es24.16,1x,es24.16)') 'LOW03EXP_OBS_DIAG', &
       obs%cauchy3_proposal_available,obs%cauchy3_proposed_t0,obs%cauchy3_proposed_t1, &
       obs%cauchy3_aquifer_head_cm,obs%cauchy3_q4_cm_per_day
  write(*,'(a,1x,l1,1x,i0,1x,a,1x,i0)') 'LOW03EXP_LAST_SOLVE',obs%solver_executed,obs%solver_status, &
       trim(obs%solver_diagnostics%route),obs%solver_diagnostics%nonlinear_iterations
  call require(app_transaction_ok,'ordinary Cauchy transaction')
  call require(abs(result(1)%mass%residual)<=HARD_MASS_GATE,'whole-profile mass closure')
  call require(result(1)%mass%complete,'mass accounting complete')
  call require(trial%completed .and. candidate%ready(),'backend trial')
  print '(a)', 'LOW03EXP_ORDINARY_APPLICATION_MASS=PASS'
  call require(obs%bottom_flux==obs%bottom_flux,'explicit qbot finite')
  print '(a)', 'LOW03EXP_GROUNDWATER_OWNER_SEPARATION=PASS'
  call require(obs%cauchy3_proposal_available,'proposal observation')
  call require(same_bits(obs%cauchy3_proposed_t0,T0) .and. same_bits(obs%cauchy3_proposed_t1,T1), &
       'proposal interval observation')
  call require(same_bits(obs%cauchy3_head_sample_t1900,1000.5_real64),'DATE3 original proposal endpoint')
  call require(same_bits(obs%cauchy3_q4_sample_t1900,1000.5_real64),'Q4 actual trial endpoint')
  call require(same_bits(obs%cauchy3_aquifer_head_cm,haq_eq) .and. same_bits(obs%cauchy3_q4_cm_per_day,0.0_real64), &
       'typed head/Q4 binding')
  call backend%discard_trial_candidate(candidate,diag)
  print '(a)', 'LOW03EXP_SERIALIZED_TYPED_BINDING=PASS'

  do j=1,8
    bad=cfg
    select case(j)
    case(1)
      bad%tiles(1)%ledger_id=1_int64
    case(2)
      bad%tiles(1)%groundwater_datum%available=.true.
      bad%tiles(1)%groundwater_datum%datum_id=1_int64
      bad%tiles(1)%groundwater_datum%bottom_boundary_elevation_m=0.0_real64
    case(3)
      bad%tiles(1)%parameters%bottom_mode=5
    case(4)
      bad%tiles(1)%parameters%swkimpl=1
    case(5)
      bad%groundwater_parallel_workers=2
    case(6)
      bad%tiles(1)%parameters%macropore_active=.true.
    case(7)
      bad%tiles(1)%ordinary_prescribed_head=.true.
    case(8)
      bad%tiles(1)%parameters%cofgen(3,2)=bad%tiles(1)%parameters%cofgen(3,2)*0.9_real64
    end select
    call badapp%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK .and. .not. badapp%ready(),'unsupported profile fail closed')
    call badapp%close(status)
  end do
  print '(a)', 'LOW03EXP_APPLICATION_FAIL_CLOSED_MATRIX=PASS'
  print '(a)', 'LOW03EXP_APPLICATION_GATE=PASS'
contains
  subroutine initialize_application_config(value,initial_head,k0)
    type(fmr_production_application_config_t),intent(out)::value
    real(real64),intent(in)::initial_head
    real(real64),intent(out)::k0
    value%initial_time=T0
    value%numerical%transaction%temporal_tolerance=0.0_real64
    value%numerical%transaction%mass_tolerance=HARD_MASS_GATE
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=2
    value%numerical%max_committed_substeps=8
    value%numerical%progress_tolerance=0.0_real64
    allocate(value%tiles(1))
    value%tiles(1)%tile_id=680101_int64
    value%tiles(1)%ledger_id=780101_int64
    value%tiles(1)%template%template_id=680201_int64
    value%tiles(1)%template%physics_topology_id=680210_int64
    value%tiles(1)%template%vertical_layout_id=680220_int64
    value%tiles(1)%template%state_layout_id=680230_int64
    value%tiles(1)%template%solver_interface_id=680240_int64
    value%tiles(1)%template%optional_state_layout_id=0_int64
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_parameters(value%tiles(1)%parameters,690001_int64)
    call initialize_state_forcing(value%tiles(1)%parameters,value%tiles(1)%initial_state,value%tiles(1)%base_forcing,initial_head,k0)
  end subroutine
  subroutine initialize_parameters(p,id)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer(int64),intent(in)::id
    integer::k
    p%parameter_set_id=id;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64;p%cofgen(2,k)=0.423_real64;p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64;p%cofgen(5,k)=0.365_real64;p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k);p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(10,k)=p%cofgen(3,k);p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=3;p%swkimpl=0;p%swkmean=1;p%swsophy=0;p%max_iterations=100;p%max_backtracking=100
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.;p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.;p%direct_retention_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.;p%drainage_response_active=.false.
  end subroutine
  subroutine initialize_state_forcing(p,state,forcing,initial_head,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    real(real64),intent(in)::initial_head
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=initial_head
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,T1-T0)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water;state%ponding_depth=0.0_real64;state%groundwater_level=-2.0_real64
    forcing%top_flux=-k0;forcing%top_head=initial_head;forcing%bottom_flux=0.0_real64;forcing%bottom_head=-100.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod),forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64;forcing%subsurface_irrigation_source=0.0_real64;forcing%root_extraction_sink=0.0_real64
  end subroutine
  logical function same_bits(a,b) result(same)
    real(real64),intent(in)::a,b
    same=transfer(a,0_int64)==transfer(b,0_int64)
  end function
  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)') 'LOW03EXP_FAIL',trim(message)
      error stop 1
    end if
  end subroutine
end program test_low03_explicit_application
