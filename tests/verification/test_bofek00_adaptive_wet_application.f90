program test_bofek00_adaptive_wet_application
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: T0=0.0_real64, T1=0.02_real64
  real(real64), parameter :: H0=-3.5900902059398048_real64
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64
  real(real64), parameter :: ALPHA=0.021659_real64, NPAR=1.734737_real64
  real(real64), parameter :: KS=31.225016_real64, LAM=0.98087_real64
  real(real64), parameter :: RAIN=4.0_real64*KS
  real(real64), parameter :: PMAX=KS*(10.0_real64/86400.0_real64)

  type(fmr_production_application_config_t) :: cfg
  type(fmr_production_application_bootstrap_t) :: app
  type(fmr_b110_physical_forcing_t), allocatable :: forcing(:)
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  integer :: status

  call configure(cfg)
  allocate(forcing(1))
  forcing(1)=cfg%tiles(1)%base_forcing
  allocate(forcing(1)%black_evaporation)
  forcing(1)%black_evaporation%precipitation_rate_cm_per_day=RAIN
  forcing(1)%black_evaporation%irrigation_rate_cm_per_day=0.0_real64
  forcing(1)%black_evaporation%snowmelt_rate_cm_per_day=0.0_real64
  forcing(1)%black_evaporation%runon_rate_cm_per_day=0.0_real64
  forcing(1)%black_evaporation%potential_bare_soil_evaporation_cm_per_day=0.0_real64
  forcing(1)%black_evaporation%potential_pond_evaporation_cm_per_day=0.0_real64
  forcing(1)%black_evaporation%ponding_max_cm=PMAX
  forcing(1)%black_evaporation%runoff_resistance_day=0.001_real64
  forcing(1)%black_evaporation%runoff_exponent=1.0_real64
  forcing(1)%black_evaporation%wetting_reset_event=.false.
  forcing(1)%black_evaporation%wetting_event_time=T0
  forcing(1)%top_flux=0.0_real64

  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK .and. app%ready(),'application initialized')
  call app%run_standalone_with_forcing(T0,T1,forcing,results,status)
  call require(status==FMR_APP_BOOT_OK,'application run')
  call require(allocated(results) .and. size(results)==1,'single result')
  call require(results(1)%completed .and. results(1)%committed,'interval committed')
  call require(results(1)%mass%complete,'mass complete')

  write(*,'(*(g0))') 'BOFEK00_ADAPTIVE|ACCEPTED_SUBSTEPS=',results(1)%accepted_substeps, &
       '|SOLVER_ITERATIONS=',results(1)%solver_iterations, &
       '|NONLINEAR=',results(1)%solver_nonlinear_iterations, &
       '|INTERNAL_RETRIES=',results(1)%solver_internal_retries, &
       '|HEADCALC_CALLS=',results(1)%solver_headcalc_calls, &
       '|JACOBIAN_BUILDS=',results(1)%solver_jacobian_builds, &
       '|LINEAR_SOLVES=',results(1)%solver_linear_solves, &
       '|BACKTRACK=',results(1)%solver_backtracking_attempts, &
       '|ALT_SOLVER=',results(1)%solver_alternative_solver_calls, &
       '|MASS_RESIDUAL=',results(1)%mass%residual, &
       '|TOTAL_IN=',results(1)%mass%total_in,'|TOTAL_OUT=',results(1)%mass%total_out
  write(*,'(A)') 'F_PE_BOFEK00_ADAPTIVE_WET_APPLICATION=PASS'

  call app%close(status)
  call require(status==FMR_APP_BOOT_OK,'application close')

contains

  subroutine configure(value)
    type(fmr_production_application_config_t),intent(out)::value
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    value%initial_time=T0
    value%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    value%numerical%transaction%temporal_tolerance=1.0e-6_real64
    value%numerical%transaction%mass_tolerance=1.0e-10_real64
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=8
    value%numerical%max_committed_substeps=256
    value%numerical%progress_tolerance=0.0_real64
    value%numerical%model_temporal_indicator_budget_available=.false.

    allocate(value%tiles(1))
    value%tiles(1)%tile_id=24001_int64
    value%tiles(1)%template%template_id=24002_int64
    value%tiles(1)%template%physics_topology_id=24003_int64
    value%tiles(1)%template%vertical_layout_id=24004_int64
    value%tiles(1)%template%state_layout_id=24005_int64
    value%tiles(1)%template%solver_interface_id=24006_int64
    value%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    value%tiles(1)%initial_black_ldwet=0.0_real64

    call init_parameters(value%tiles(1)%parameters)
    call initialize_b110_default_mvg_parameters(hp,value%tiles(1)%parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,T1-T0)
    heads=H0
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)

    value%tiles(1)%initial_state%active_nodes=numnod
    allocate(value%tiles(1)%initial_state%pressure_head(numnod),value%tiles(1)%initial_state%water_content(numnod))
    value%tiles(1)%initial_state%pressure_head=heads
    value%tiles(1)%initial_state%water_content=water
    value%tiles(1)%initial_state%ponding_depth=0.0_real64
    value%tiles(1)%initial_state%groundwater_level=-160.0_real64

    value%tiles(1)%base_forcing%top_flux=0.0_real64
    value%tiles(1)%base_forcing%top_head=H0
    value%tiles(1)%base_forcing%bottom_flux=-conductivity(numnod)
    value%tiles(1)%base_forcing%bottom_head=-999999.0_real64
    allocate(value%tiles(1)%base_forcing%drainage_flux_by_level(1,numnod), &
         value%tiles(1)%base_forcing%subsurface_irrigation_source(numnod), &
         value%tiles(1)%base_forcing%root_extraction_sink(numnod))
    value%tiles(1)%base_forcing%drainage_flux_by_level=0.0_real64
    value%tiles(1)%base_forcing%subsurface_irrigation_source=0.0_real64
    value%tiles(1)%base_forcing%root_extraction_sink=0.0_real64
  end subroutine configure

  subroutine init_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer :: k
    p%parameter_set_id=24007_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=TR;p%cofgen(2,k)=TS;p%cofgen(3,k)=KS;p%cofgen(4,k)=ALPHA;p%cofgen(5,k)=LAM;p%cofgen(6,k)=NPAR
      p%cofgen(7,k)=1.0_real64-1.0_real64/NPAR;p%cofgen(8,k)=ALPHA;p%cofgen(10,k)=KS
      p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*KS;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=32
    p%max_backtracking=12
    p%min_step_duration=1.0e-12_real64
    p%compartment_balance_tolerance=1.0e-10_real64
    p%total_balance_tolerance=1.0e-10_real64
    p%head_abs_tolerance=1.0e-10_real64
    p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    p%soil_temperature_active=.false.
    p%drainage_response_active=.false.
    p%black_evaporation_active=.true.
    allocate(p%black_evaporation)
    p%black_evaporation%cofred=1.0_real64
  end subroutine init_parameters

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_BOFEK00_ADAPTIVE_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_bofek00_adaptive_wet_application
