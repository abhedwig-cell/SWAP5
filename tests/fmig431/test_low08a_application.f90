program test_low08a_application
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, fmr_logical_column_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_kernel_transactions
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use variables, only: fldtmin
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
  real(real64) :: conductivity0
  integer :: status,j
  logical :: ok, app_transaction_ok

  fldtmin=.false.
  call initialize_application_config(cfg,-75.0_real64,conductivity0)
  cfg%tiles(1)%parameters%bottom_mode=8
  cfg%tiles(1)%ordinary_lysimeter_plate=.true.
  cfg%tiles(1)%ledger_id=0_int64
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  cfg%numerical%model_temporal_indicator_budget_available=.true.
  cfg%numerical%model_temporal_indicator_budget=QUALIFICATION_HEAD_BUDGET
  cfg%tiles(1)%base_forcing%bottom_head=-100.0_real64
  cfg%tiles(1)%base_forcing%bottom_flux=0.0_real64
  print '(a)', 'LOW08A_STAGE_BEFORE_INIT'
  call app%initialize(cfg,status)
  print '(a,1x,i0)', 'LOW08A_STAGE_AFTER_INIT',status
  call require(status==FMR_APP_BOOT_OK .and. app%ready(),'ordinary lysimeter bootstrap')
  call app%materialize_groundwater_context(topology,predictors,areas,context_handle,status)
  call require(status/=FMR_APP_BOOT_OK .and. context_handle==0_int64,'reject groundwater context')
  print '(a)', 'LOW08A_STAGE_BEFORE_RUN'
  call app%run_standalone(T0,T0+0.01_real64,result,status)
  print '(a,1x,i0)', 'LOW08A_STAGE_AFTER_RUN',status
  if(allocated(result))write(*,'(a,1x,l1,1x,l1,1x,l1,1x,i0,1x,i0,1x,a)') 'LOW08A_RESULT_DIAG',result(1)%admitted,result(1)%completed,result(1)%committed,result(1)%kernel_status,result(1)%accepted_substeps,trim(result(1)%admission_status)
  call require(status==FMR_APP_BOOT_OK .and. result(1)%completed .and. result(1)%committed,'application transaction')
  call require(result(1)%mass%complete .and. abs(result(1)%mass%residual)<=HARD_MASS_GATE,'application mass')
  call app%close(status)
  columns(1)%column_id=cfg%tiles(1)%tile_id
  columns(1)%template_id=cfg%tiles(1)%template%template_id
  columns(1)%parameter_ref=1_int64;columns(1)%state_handle=1_int64;columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call backend%initialize(top)
  call fmr_new_b110_committed_state(states(1),columns(1)%column_id,cfg%tiles(1)%initial_state,T0,ok)
  call require(ok,'committed state')
  call states(1)%capture_checkpoint(cp,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,trial,candidate,diag)
  call require(trial%completed .and. candidate%ready(),'serialized trial')
  call require(abs(trial%mass%residual)<=HARD_MASS_GATE,'serialized mass')
  call backend%discard_trial_candidate(candidate,diag)
  print '(a)', 'LOW08A_APPLICATION_E2E=PASS'
  print '(a)', 'LOW08A_MASS_OWNER=PASS'
  print '(a)', 'LOW08A_GROUNDWATER_SEPARATION=PASS'
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
      bad%tiles(1)%parameters%bottom_mode=7
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
  print '(a)', 'LOW08A_APPLICATION_FAIL_CLOSED_MATRIX=PASS'
  print '(a)', 'LOW08A_APPLICATION_GATE=PASS'
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
    p%bottom_mode=8;p%swkimpl=0;p%swkmean=1;p%swsophy=0;p%max_iterations=100;p%max_backtracking=100
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
      write(*,'(a,1x,a)') 'LOW08A_FAIL',trim(message)
      error stop 1
    end if
  end subroutine
end program test_low08a_application
