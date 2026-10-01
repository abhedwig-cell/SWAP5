program test_low05a_application
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_legacy_head_bottom_boundary_provider
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
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state
  implicit none
  real(real64), parameter :: T0=5100.1875_real64, T1=5100.6875_real64, HARD_MASS_GATE=1.0e-12_real64
  type(fmr_production_application_config_t) :: cfg, oracle, badcfg
  type(fmr_production_application_bootstrap_t) :: app, direct, badapp
  type(fmr_serialized_column_result_t), allocatable :: a(:), b(:), rejected(:)
  type(fmr_b110_physical_forcing_t) :: effective(1)
  type(fmr_hbot5_control_t) :: law
  type(fmr_hbot5_proposal_t) :: proposal
  real(real64) :: k, nan
  integer :: status, j
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  call law%initialize([1000.0_real64,1000.5_real64,1001.0_real64], &
       [-100.0_real64,-75.0_real64,-25.0_real64],T0,1000.0_real64,T0,T0+1.0_real64,status)
  call require(status==FMR_HBOT5_OK,'valid calendar table')
  call law%resolve(T0,T1,proposal,status)
  call require(status==FMR_HBOT5_OK .and. same_bits(proposal%pressure_head_cm,-75.0_real64),'endpoint knot')
  call require(same_bits(proposal%legacy_sample_t1900,1000.5_real64),'calendar offset')
  call require(proposal%covers(T0,T0+0.125_real64),'retry covered by frozen original proposal')
  call require(.not. proposal%covers(T0,T0+1.0_real64),'proposal does not escape original endpoint')
  call law%resolve(T0,T0+0.25_real64,proposal,status)
  call require(same_bits(proposal%pressure_head_cm,-87.5_real64),'linear interpolation')
  call law%resolve(T0,T0+2.0_real64,proposal,status)
  call require(status/=FMR_HBOT5_OK .and. .not. proposal%available,'outside declared simulation')
  call law%initialize([1000.25_real64,1000.75_real64],[-90.0_real64,-50.0_real64], &
       T0,1000.0_real64,T0,T0+1.0_real64,status)
  call require(status==FMR_HBOT5_OK,'legacy checkdate overlap')
  call law%resolve(T0,T0+0.125_real64,proposal,status)
  call require(same_bits(proposal%pressure_head_cm,-90.0_real64),'lower clamp')
  call law%resolve(T0,T0+1.0_real64,proposal,status)
  call require(same_bits(proposal%pressure_head_cm,-50.0_real64),'upper clamp')
  call law%initialize([1000.0_real64,1000.0_real64],[-75.0_real64,-75.0_real64], &
       T0,1000.0_real64,T0,T1,status)
  call require(status/=FMR_HBOT5_OK .and. .not. law%ready(),'duplicate dates fail closed')
  call law%initialize([1000.0_real64],[nan],T0,1000.0_real64,T0,T1,status)
  call require(status/=FMR_HBOT5_OK,'nonfinite heads fail closed')
  call law%initialize([1000.0_real64],[1001.0_real64],T0,1000.0_real64,T0,T1,status)
  call require(status/=FMR_HBOT5_OK,'legacy head bound')
  print '(a)', 'LOW05A_SOURCE_LAW_ENDPOINT_CALENDAR_DOMAIN=PASS'

  ! A nonconstant table resolves to -75 at the original proposed endpoint.
  ! All full/two-half siblings must therefore equal a direct fixed -75 route.
  ! Sampling the half-step endpoint would supply -87.5 and break this oracle.
  call initialize_application_config(cfg,-75.0_real64,k)
  cfg%tiles(1)%parameters%bottom_mode=5
  cfg%tiles(1)%ordinary_prescribed_head=.true.
  cfg%tiles(1)%ledger_id=0_int64
  cfg%tiles(1)%base_forcing%bottom_head=10.0_real64
  allocate(cfg%tiles(1)%base_forcing%legacy_swbotb5_control)
  call cfg%tiles(1)%base_forcing%legacy_swbotb5_control%initialize( &
       [1000.0_real64,1000.5_real64],[-100.0_real64,-75.0_real64],T0,1000.0_real64,T0,T1,status)
  call require(status==FMR_HBOT5_OK,'production law')
  oracle=cfg
  oracle%tiles(1)%ordinary_prescribed_head=.false.
  deallocate(oracle%tiles(1)%base_forcing%legacy_swbotb5_control)
  oracle%tiles(1)%base_forcing%bottom_head=-75.0_real64
  oracle%tiles(1)%ledger_id=760101_int64
  oracle%tiles(1)%groundwater_datum%available=.true.
  oracle%tiles(1)%groundwater_datum%datum_id=1_int64
  oracle%tiles(1)%groundwater_datum%bottom_boundary_elevation_m=-0.03_real64
  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK,'ordinary mode5 bootstrap without groundwater datum/ledger')
  call direct%initialize(oracle,status)
  call require(status==FMR_APP_BOOT_OK,'default groundwater-owned mode5 preserved')
  call app%run_standalone(T0,T1,a,status)
  call require(status==FMR_APP_BOOT_OK,'ordinary physical transaction')
  call direct%run_standalone(T0,T1,b,status)
  call require(status==FMR_APP_BOOT_OK,'direct prescribed head oracle')
  call require(results_identical(a(1),b(1)),'dynamic table full/two-half staging equals frozen endpoint head')
  call require(abs(a(1)%mass%residual)<=HARD_MASS_GATE,'ordinary mass')
  effective(1)=cfg%tiles(1)%base_forcing
  deallocate(effective(1)%legacy_swbotb5_control)
  call app%run_standalone_with_forcing(T1,T1+0.125_real64,effective,rejected,status)
  call require(status/=FMR_APP_BOOT_OK,'ordinary authority cannot be removed')
  effective(1)=cfg%tiles(1)%base_forcing
  call direct%run_standalone_with_forcing(T1,T1+0.125_real64,effective,rejected,status)
  call require(status/=FMR_APP_BOOT_OK,'groundwater ownership cannot acquire ordinary table')
  call app%close(status)
  call direct%close(status)
  print '(a)', 'LOW05A_PRODUCTION_FROZEN_ENDPOINT_MASS=PASS'
  print '(a)', 'LOW05A_DEFAULT_GROUNDWATER_MODE5_PRESERVED=PASS'
  print '(a)', 'LOW05A_EFFECTIVE_FORCING_OWNERSHIP_FAIL_CLOSED=PASS'

  do j=1,5
    badcfg=cfg
    select case(j)
    case(1)
      badcfg%tiles(1)%ledger_id=1_int64
    case(2)
      badcfg%tiles(1)%groundwater_datum=oracle%tiles(1)%groundwater_datum
    case(3)
      badcfg%tiles(1)%parameters%bottom_mode=7
    case(4)
      deallocate(badcfg%tiles(1)%base_forcing%legacy_swbotb5_control)
    case(5)
      badcfg%groundwater_parallel_workers=2
    end select
    call badapp%initialize(badcfg,status)
    call require(status/=FMR_APP_BOOT_OK .and. .not. badapp%ready(),'invalid ordinary ownership/profile')
    call badapp%close(status)
  end do
  print '(a)', 'LOW05A_BOOTSTRAP_PROFILE_FAIL_CLOSED=PASS'
  call qualify_exchange_directions(cfg)
  call qualify_transaction_restart(cfg)
  print '(a)', 'LOW05A_APPLICATION_GATE=PASS'
contains


  subroutine qualify_exchange_directions(config)
    type(fmr_production_application_config_t), intent(in) :: config
    type(fmr_production_application_config_t) :: c
    type(fmr_production_application_bootstrap_t) :: owner
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: hydraulic
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), derivative(numnod)
    real(real64) :: hb, finish
    integer :: i,s
    finish=T0+0.0009765625_real64
    do i=1,3
      c=config
      c%numerical%transaction%temporal_tolerance=1.0_real64
      c%tiles(1)%parameters%max_iterations=100
      c%tiles(1)%parameters%max_backtracking=20
      c%tiles(1)%parameters%swkimpl=0
      heads=-75.0_real64
      if(i==2) heads=[-75.0_real64,-73.0_real64,-71.0_real64,-69.0_real64]
      if(i==3) heads=[-75.0_real64,-74.0_real64,-73.0_real64,-72.0_real64]
      call initialize_b110_default_mvg_parameters(hp,c%tiles(1)%parameters%cofgen)
      call bind_b110_default_mvg_provider(hydraulic,hp,finish-T0)
      call hydraulic%evaluate(heads,water,conductivity,capacity,derivative)
      ! Scale Ksat at each node to obtain a constant conductivity. Retention
      ! is unchanged. This gives an exact discrete constant-flux oracle.
      c%tiles(1)%parameters%cofgen(3,:)=c%tiles(1)%parameters%cofgen(3,:)*conductivity(1)/conductivity
      c%tiles(1)%parameters%cofgen(10,:)=c%tiles(1)%parameters%cofgen(3,:)
      call initialize_b110_default_mvg_parameters(hp,c%tiles(1)%parameters%cofgen)
      call bind_b110_default_mvg_provider(hydraulic,hp,finish-T0)
      call hydraulic%evaluate(heads,water,conductivity,capacity,derivative)
      c%tiles(1)%initial_state%pressure_head=heads
      c%tiles(1)%initial_state%water_content=water
      hb=heads(numnod)
      c%tiles(1)%base_forcing%top_flux=-conductivity(1)
      if(i==2) then
        hb=heads(numnod)+dz(numnod)
        c%tiles(1)%base_forcing%top_flux=conductivity(1)
      end if
      if(i==3) then
        hb=heads(numnod)+0.5_real64*dz(numnod)
        c%tiles(1)%base_forcing%top_flux=0.0_real64
      end if
      call c%tiles(1)%base_forcing%legacy_swbotb5_control%initialize([1000.0_real64],[hb], &
           T0,1000.0_real64,T0,T1,s)
      call owner%initialize(c,s)
      call require(s==FMR_APP_BOOT_OK,'exchange direction initialize')
      call owner%run_standalone(T0,finish,r,s)
      call require(s==FMR_APP_BOOT_OK,'exchange direction physical run')
      call require(abs(r(1)%mass%residual)<=HARD_MASS_GATE,'exchange direction hard mass')
      if(i==1) call require(r(1)%mass%total_out>0.0_real64,'downward exchange')
      if(i==2) call require(r(1)%mass%total_in>0.0_real64,'upward exchange')
      if(i==3) call require(abs(r(1)%mass%total_out)+abs(r(1)%mass%total_in)<1.0e-12_real64,'hydrostatic zero exchange')
      call owner%close(s)
    end do
    print '(a)', 'LOW05A_UPWARD_DOWNWARD_ZERO_EXCHANGE_HARD_MASS=PASS'
  end subroutine

  subroutine qualify_transaction_restart(config)
    type(fmr_production_application_config_t), intent(in) :: config
    type(fmr_serialized_reference_backend_t), target :: backend, resumed
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(fmr_logical_column_t) :: columns(1)
    type(kernel_committed_state_t) :: states(1), restored_states(1)
    type(kernel_checkpoint_t) :: cp, cp_restored
    type(kernel_candidate_state_t) :: candidate, other_candidate
    type(kernel_result_t) :: first, again, restarted, rejected_result
    type(kernel_diagnostics_t) :: diag
    type(fmr_serialized_physical_observation_t) :: obs
    type(fmr_committed_restart_bundle_t) :: bundle
    type(fmr_b110_physical_forcing_t) :: forcing, original
    logical :: ok
    integer :: s
    columns(1)%column_id=1_int64
    columns(1)%template_id=config%tiles(1)%template%template_id
    columns(1)%parameter_ref=1_int64
    columns(1)%state_handle=1_int64
    columns(1)%forcing_handle=1_int64
    columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call backend%initialize(top)
    call resumed%initialize(top)
    call fmr_new_b110_committed_state(states(1),1_int64,config%tiles(1)%initial_state,T0,ok)
    call require(ok,'initial committed state')
    call states(1)%capture_checkpoint(cp,ok)
    call require(ok,'trial checkpoint')
    original=config%tiles(1)%base_forcing
    forcing=original
    call forcing%legacy_swbotb5_control%initialize([1000.0_real64,1001.0_real64], &
       [-75.0_real64,-75.0_real64],T0,1000.0_real64,T0,T0+1.0_real64,s)
    original=forcing
    call backend%run_trial(columns(1),config%tiles(1)%template,config%tiles(1)%parameters,states(1), &
         forcing,config%numerical,T0,T1,cp,first,candidate,diag)
    call require(first%completed .and. candidate%ready(),'initial physical trial')
    call backend%discard_trial_candidate(candidate,diag)
    ! Zero temporal tolerance makes the nonstationary head trial reject. This
    ! exercises actual transaction retry/rollback, without test-only injection.
    call forcing%legacy_swbotb5_control%initialize([1000.0_real64,1000.5_real64], &
       [-75.0_real64,-74.0_real64],T0,1000.0_real64,T0,T1,s)
    call backend%run_trial(columns(1),config%tiles(1)%template,config%tiles(1)%parameters,states(1), &
         forcing,config%numerical,T0,T1,cp,rejected_result,candidate,diag)
    obs=backend%observation()
    call require(diag%retries>0,'real transaction retries')
    call require(.not. rejected_result%completed .and. .not. candidate%ready(),'retry exhaustion rejects candidate')
    call require(states(1)%current_revision()==0_int64,'rejected trial preserves committed revision')
    call require(obs%hbot5_proposal_available .and. same_bits(obs%hbot5_proposed_t1,T1),'retry original endpoint')
    call require(same_bits(obs%hbot5_pressure_head_cm,-74.0_real64),'retry freezes original head')
    forcing=original
    call backend%run_trial(columns(1),config%tiles(1)%template,config%tiles(1)%parameters,states(1), &
         forcing,config%numerical,T0,T1,cp,again,candidate,diag)
    call require(again%completed .and. candidate%ready(),'A/B/A recovers')
    call require(same_bits(first%mass%storage_end,again%mass%storage_end) .and. &
         same_bits(first%mass%total_out,again%mass%total_out),'A/B/A replay physical identity')
    call backend%commit_trial_candidate(states(1),candidate,diag,ok,s)
    call require(ok,'accepted checkpoint commit')
    call fmr_export_committed_restart(columns,[config%tiles(1)%template],states, &
         config%tiles(1)%parameters%parameter_set_id,bundle,ok,s)
    call require(ok .and. s==FMR_RESTART_OK,'committed restart export')
    call fmr_restore_committed_restart(bundle,config%tiles(1)%parameters%parameter_set_id,columns, &
         [config%tiles(1)%template],restored_states,ok,s)
    call require(ok .and. s==FMR_RESTART_OK,'restart restore to fresh state registry')
    call states(1)%capture_checkpoint(cp,ok)
    call restored_states(1)%capture_checkpoint(cp_restored,ok)
    call backend%run_trial(columns(1),config%tiles(1)%template,config%tiles(1)%parameters,states(1), &
         forcing,config%numerical,T1,T0+1.0_real64,cp,again,candidate,diag)
    call resumed%run_trial(columns(1),config%tiles(1)%template,config%tiles(1)%parameters,restored_states(1), &
         forcing,config%numerical,T1,T0+1.0_real64,cp_restored,restarted,other_candidate,diag)
    call require(again%completed .and. restarted%completed,'restart continuation completes')
    call require(same_bits(again%mass%storage_end,restarted%mass%storage_end) .and. &
         same_bits(again%mass%total_out,restarted%mass%total_out) .and. &
         same_bits(again%terminal_bottom_outward_flux_native,restarted%terminal_bottom_outward_flux_native), &
         'fresh backend restart continuation identity')
    obs=resumed%observation()
    call require(same_bits(obs%hbot5_proposed_t0,T1) .and. same_bits(obs%hbot5_proposed_t1,T0+1.0_real64), &
         'restart creates new proposal rather than persisting trial scratch')
    print '(a)', 'LOW05A_PHYSICAL_RETRY_ROLLBACK_ABA=PASS'
    print '(a)', 'LOW05A_COMMITTED_RESTART_FRESH_BACKEND_IDENTITY=PASS'
  end subroutine

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
    p%bottom_mode = 2
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

    heads = initial_head
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = initial_head
    forcing%bottom_flux = -conductivity0
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
      write(*,'(a,1x,a)') 'LOW05A_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_low05a_application

